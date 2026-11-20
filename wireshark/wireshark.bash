#!/usr/bin/env bash
# Run on the client VM (VM4). Generates dhcp/dns/http/email .pcapng with tshark,
# runs the traffic itself, validates each capture and writes analise.txt.
#
# Usage:  sudo ./capturas.bash [dhcp] [dns] [http] [email]     (no args = all)
# Overrides (env): IFACE OUTDIR DNS_SERVER WEB_HOST MAIL_HOST SENDER RCPT IMAP_USER IMAP_PASS
set -uo pipefail

[[ $EUID -eq 0 ]] || exec sudo -E "$0" "$@"

IFACE="${IFACE:-}"
OUTDIR="${OUTDIR:-$PWD/results}"
DNS_SERVER="${DNS_SERVER:-192.168.10.10}"
WEB_HOST="${WEB_HOST:-www.cardeal.local}"
MAIL_HOST="${MAIL_HOST:-mail.cardeal.local}"
SENDER="${SENDER:-ana@cardeal.local}"
RCPT="${RCPT:-bruno@cardeal.local}"
IMAP_USER="${IMAP_USER:-bruno}"
IMAP_PASS="${IMAP_PASS:-bruno123}"
OWNER="${SUDO_USER:-root}"

declare -A RESULT
ANALISE="$OUTDIR/analise.txt"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }

# ---------- setup ----------
install_deps() {
    local miss=0
    for c in tshark dig curl; do command -v "$c" >/dev/null || miss=1; done
    [[ $miss -eq 0 ]] && return 0
    log "Installing dependencies"
    if command -v dnf >/dev/null; then
        dnf install -y wireshark-cli bind-utils curl
    elif command -v apt >/dev/null; then
        DEBIAN_FRONTEND=noninteractive apt install -y tshark dnsutils curl
    else
        warn "No dnf/apt found; install tshark, dig and curl manually"; exit 1
    fi
}

detect_iface() {
    [[ -n "$IFACE" ]] && return 0
    IFACE=$(ip -4 route show default 2>/dev/null | awk '/default/{print $5; exit}')
    [[ -z "$IFACE" ]] && IFACE=$(ip -br link | awk '$1!="lo" && $2=="UP"{print $1; exit}')
    [[ -z "$IFACE" ]] && { warn "Could not detect interface; set IFACE=..."; exit 1; }
}

wait_for_ip() {
    for _ in $(seq 30); do
        ip -4 addr show dev "$IFACE" | grep -q 'inet ' && return 0
        sleep 1
    done
    return 1
}

# ---------- capture engine ----------
# run_capture <name> <capture filter> <action function> <display filter that must match> <min packets>
run_capture() {
    local name=$1 bpf=$2 action=$3 check=$4 min=$5
    local file="$OUTDIR/$name.pcapng" tlog; tlog=$(mktemp)
    rm -f "$file"
    log "Capture: $name  (filter: $bpf)"

    tshark -i "$IFACE" -n -f "$bpf" -w "$file" >"$tlog" 2>&1 &
    local pid=$!
    for _ in $(seq 20); do
        grep -q "Capturing on" "$tlog" && break
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.5
    done
    if ! kill -0 "$pid" 2>/dev/null; then
        warn "tshark failed to start:"; cat "$tlog"; RESULT[$name]="FAIL (tshark did not start)"; rm -f "$tlog"; return
    fi
    sleep 1

    "$action"
    local rc=$?
    sleep 2
    kill -INT "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
    rm -f "$tlog"
    chown "$OWNER":"$OWNER" "$file" 2>/dev/null

    local n; n=$(tshark -r "$file" -Y "$check" 2>/dev/null | wc -l)
    if [[ $rc -ne 0 ]]; then
        RESULT[$name]="WARN (action exited $rc, $n matching packets)"
    elif [[ $n -ge $min ]]; then
        RESULT[$name]="OK ($n matching packets)"
    else
        RESULT[$name]="FAIL (only $n matching packets, expected >= $min)"
    fi
    echo "${RESULT[$name]}"
}

# ---------- actions (generate the traffic) ----------
act_dhcp() {
    local con=""
    command -v nmcli >/dev/null && con=$(nmcli -g GENERAL.CONNECTION device show "$IFACE" 2>/dev/null)
    if [[ -n "$con" && "$con" != "--" ]]; then
        warn "Cycling connection '$con' to force a new DHCP lease"
        nmcli connection down "$con" >/dev/null 2>&1; sleep 3
        nmcli connection up "$con" >/dev/null 2>&1
    elif command -v dhclient >/dev/null; then
        dhclient -r "$IFACE" 2>/dev/null; sleep 2; dhclient "$IFACE"
    else
        warn "No nmcli/dhclient: renew the lease manually now"; return 1
    fi
    wait_for_ip || { warn "No IPv4 address after renewal"; return 1; }
    ip -4 -br addr show dev "$IFACE"
}

act_dns() {
    local ok=0
    for q in "$WEB_HOST" "$MAIL_HOST"; do
        dig +tries=1 +time=3 @"$DNS_SERVER" "$q" A | grep -A2 'ANSWER SECTION' || ok=1
    done
    dig +tries=1 +time=3 @"$DNS_SERVER" cardeal.local MX +short || ok=1
    return $ok
}

act_http() {
    curl -sv -o /dev/null --max-time 10 "http://$WEB_HOST/" 2>&1 | grep -E '^(\*   Trying|> GET|< HTTP)'
    return "${PIPESTATUS[0]}"
}

act_email() {
    local tag="captura-$(date +%s)"
    printf 'From: %s\nTo: %s\nSubject: %s\n\nTeste de captura.\n' "$SENDER" "$RCPT" "$tag" \
        | curl -s --max-time 15 --url "smtp://$MAIL_HOST:25" --mail-from "$SENDER" --mail-rcpt "$RCPT" -T - \
        || { warn "SMTP send failed"; return 1; }
    echo "sent: $tag"
    sleep 2
    curl -s --max-time 15 -u "$IMAP_USER:$IMAP_PASS" "imap://$MAIL_HOST/INBOX" -X 'SEARCH SUBJECT "'"$tag"'"' \
        | grep -q SEARCH || { warn "IMAP read failed"; return 1; }
    local uid
    uid=$(curl -s --max-time 15 -u "$IMAP_USER:$IMAP_PASS" "imap://$MAIL_HOST/INBOX" -X 'SEARCH SUBJECT "'"$tag"'"' \
        | tr -d '\r' | awk '/SEARCH/{print $NF}')
    [[ -n "$uid" ]] || { warn "message not found in INBOX"; return 1; }
    curl -s --max-time 15 -u "$IMAP_USER:$IMAP_PASS" "imap://$MAIL_HOST/INBOX;MAILINDEX=$uid" | grep -E '^(From|To|Subject):'
}

# ---------- analysis (answers the assignment's questions) ----------
analyse() {
    local d="$OUTDIR"
    {
    echo "Gerado em $(date) a partir de $(hostname) (iface $IFACE)"
    echo
    echo "=== DHCP (2.a) - IP de origem/destino de cada mensagem ==="
    echo "(tipo: 1=Discover 2=Offer 3=Request 5=Ack)"
    tshark -r "$d/dhcp.pcapng" -Y dhcp -T fields -e frame.number -e ip.src -e ip.dst -e dhcp.option.dhcp 2>/dev/null \
        | awk -F'\t' 'BEGIN{m["1"]="Discover";m["2"]="Offer";m["3"]="Request";m["5"]="Ack";m["6"]="NAK";m["7"]="Release";m["8"]="Inform"}
                      {printf "frame %-4s %-16s -> %-16s %s\n",$1,$2,$3,(m[$4]?m[$4]:$4)}'
    echo
    echo "=== DNS (2.b) - nome consultado e servidor que respondeu ==="
    tshark -r "$d/dns.pcapng" -Y dns -T fields -e frame.number -e ip.src -e ip.dst -e dns.flags.response -e dns.qry.name -e dns.a 2>/dev/null \
        | awk -F'\t' '{printf "frame %-4s %-16s -> %-16s %-9s %-22s %s\n",$1,$2,$3,($4=="1"?"RESPOSTA":"CONSULTA"),$5,$6}'
    echo
    echo "=== HTTP (2.c) - handshake TCP e GET ==="
    tshark -r "$d/http.pcapng" -Y "tcp.port==80" -c 3 2>/dev/null
    tshark -r "$d/http.pcapng" -Y "http.request" -T fields -e frame.number -e http.request.method -e http.host -e http.request.uri -e http.request.full_uri 2>/dev/null \
        | awk -F'\t' '{printf "frame %-4s %s Host:%s URI:%s  => URL: %s\n",$1,$2,$3,$4,$5}'
    echo
    echo "=== E-MAIL (2.d) - quem iniciou cada conexao e o dialogo ==="
    echo "-- SYN iniciais (origem -> destino:porta)"
    tshark -r "$d/email.pcapng" -Y "tcp.flags.syn==1 && tcp.flags.ack==0" -T fields -e frame.number -e ip.src -e ip.dst -e tcp.dstport 2>/dev/null \
        | awk -F'\t' '{printf "frame %-4s %-16s -> %s:%s  (%s)\n",$1,$2,$3,$4,($4==25?"SMTP":($4==143?"IMAP":"?"))}'
    echo "-- Mensagens SMTP/IMAP"
    tshark -r "$d/email.pcapng" -Y "smtp || imap" 2>/dev/null | head -40
    } 2>&1 | tee "$ANALISE"
    chown "$OWNER":"$OWNER" "$ANALISE" 2>/dev/null
}

# ---------- main ----------
install_deps
detect_iface
mkdir -p "$OUTDIR"; chown "$OWNER":"$OWNER" "$OUTDIR" 2>/dev/null

targets=("$@"); [[ ${#targets[@]} -eq 0 ]] && targets=(dhcp dns http email)
log "Interface: $IFACE | Output: $OUTDIR | Targets: ${targets[*]}"

for t in "${targets[@]}"; do
    case "$t" in
        dhcp)  run_capture dhcp  "udp port 67 or udp port 68" act_dhcp  "dhcp" 4 ;;
        dns)   run_capture dns   "udp port 53 or tcp port 53" act_dns   "dns"  2 ;;
        http)  run_capture http  "tcp port 80"                act_http  "http.request" 1 ;;
        email) run_capture email "tcp port 25 or tcp port 143" act_email "smtp || imap" 6 ;;
        *) warn "Unknown target '$t' (use: dhcp dns http email)" ;;
    esac
done

log "Analysis"
for f in dhcp dns http email; do [[ -f "$OUTDIR/$f.pcapng" ]] || { warn "$f.pcapng missing - skipping analysis"; continue; }; done
analyse

log "Summary"
for t in "${targets[@]}"; do printf '%-6s %s\n' "$t" "${RESULT[$t]:-not run}"; done
echo
ls -l "$OUTDIR"
echo "Open the .pcapng files in Wireshark on the host and take screenshots with these filters: dhcp | dns | http | smtp || imap"
