sudo dnf install -y mutt bind-utils

cat > ~/.muttrc <<'EOF'
set imap_user = "ana"
set imap_pass = "ana123"
set folder    = "imap://mail.cardeal.local/"
set spoolfile = "+INBOX"
set ssl_starttls = no
set ssl_force_tls = no

set from      = "ana@cardeal.local"
set realname  = "Ana"
set smtp_url  = "smtp://mail.cardeal.local:25"
set editor    = "nano"
EOF

nslookup mail.cardeal.local     # should return 192.168.10.20
mutt