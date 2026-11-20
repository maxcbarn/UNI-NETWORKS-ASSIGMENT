sudo dnf install -y mutt bind-utils

cat > ~/.muttrc <<'EOF'
set imap_user = "bruno"
set imap_pass = "bruno123"
set folder    = "imap://mail.cardeal.local/"
set spoolfile = "+INBOX"
set ssl_starttls = no
set ssl_force_tls = no

set from      = "bruno@cardeal.local"
set realname  = "Bruno"
set smtp_url  = "smtp://mail.cardeal.local:25"
set editor    = "nano"
EOF

nslookup mail.cardeal.local     # should return 192.168.10.20
mutt