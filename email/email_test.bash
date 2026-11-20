
printf "From: ana@cardeal.local\nTo: bruno@cardeal.local\nSubject: Teste\n\nOla Bruno, teste de e-mail.\n" \
  | curl -s --url smtp://mail.cardeal.local:25 \
      --mail-from ana@cardeal.local \
      --mail-rcpt bruno@cardeal.local \
      -T -

sleep 1


curl -u bruno:bruno123 imap://mail.cardeal.local/INBOX
curl -u bruno:bruno123 "imap://mail.cardeal.local/INBOX;UID=1"

sudo tail /var/log/mail.log
sudo ls /home/bruno/Maildir/new
