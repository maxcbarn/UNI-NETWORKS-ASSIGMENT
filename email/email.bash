
echo "postfix postfix/mailname string mail.cardeal.local" | sudo debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | sudo debconf-set-selections

sudo apt install -y postfix dovecot-imapd mailutils

sudo postconf -e "myhostname = mail.cardeal.local"
sudo postconf -e "mydomain = cardeal.local"
sudo postconf -e "myorigin = \$mydomain"
sudo postconf -e "mydestination = \$myhostname, \$mydomain, localhost"
sudo postconf -e "mynetworks = 127.0.0.0/8, 192.168.10.0/24"
sudo postconf -e "inet_interfaces = all"
sudo postconf -e "inet_protocols = ipv4"
sudo postconf -e "home_mailbox = Maildir/"

sudo rm -f /etc/dovecot/conf.d/99-cardeal.conf

echo "mail_driver = maildir
mail_path = ~/Maildir
mail_inbox_path = ~/Maildir
auth_allow_cleartext = yes
auth_mechanisms = plain login
ssl = no" | sudo tee /etc/dovecot/conf.d/99-cardeal.conf

for u in ana bruno; do
  id "$u" >/dev/null 2>&1 || sudo useradd -m -s /usr/sbin/nologin "$u"
  echo "$u:${u}123" | sudo chpasswd
done

sudo doveconf -n >/dev/null && sudo systemctl restart dovecot
sudo ss -tlnp | grep -E ':(25|143)\b'

sudo systemctl restart postfix dovecot
sudo systemctl enable postfix dovecot

sudo ufw allow 25/tcp
sudo ufw allow 143/tcp

sudo postfix check
sudo systemctl status postfix dovecot --no-pager
sudo ss -tlnp | grep -E ':(25|143)\b'

