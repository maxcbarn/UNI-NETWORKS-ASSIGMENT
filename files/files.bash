sudo apt install samba -y

sudo systemctl status smbd

sudo rm -r /srv/samba/share

sudo mkdir -p /srv/samba/share
sudo groupadd sambausers

sudo chown -R root:sambausers /srv/samba/share
sudo chmod -R 2770 /srv/samba/share

FILE="/etc/samba/smb.conf.bak"

if [[ ! -f "$FILE" ]]; then
    sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
fi

sudo rm -f /etc/samba/smb.conf

sudo cp  /etc/samba/smb.conf.bak /etc/samba/smb.conf

echo "[LANShare]
   comment = LAN File Share
   path = /srv/samba/share
   browsable = yes
   read only = no
   guest ok = no
   valid users = @sambausers
   force group = sambausers
   create mask = 0660
   directory mask = 2770" >> /etc/samba/smb.conf

testparm

sudo systemctl stop smbd nmbd

sudo systemctl restart smbd nmbd

sudo systemctl status smbd nmbd

sudo ufw allow samba

cp image.webp /srv/samba/share/image.webp

cp max_bunny_ingot.png /srv/samba/share/max_bunny_ingot.png

cp maxico.png /srv/samba/share/maxico.png

cp tmmxd8d.png /srv/samba/share/tmmd8d.png

cp zbvbj97.png /srv/samba/share/zbvbj97.png

sudo adduser --no-create-home --disabled-password --shell /usr/sbin/nologin worker
sudo usermod -aG sambausers worker
sudo smbpasswd -a worker