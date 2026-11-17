sudo apt install apache2 -y

sudo ufw allow 'Apache Full

rm -r /var/www/cardeal.local

sudo mkdir -p /var/www/cardeal.local

cp index.html /var/www/cardeal.local
cp hazel_dance.jpg /var/www/cardeal.local

sudo chmod -R 755 /var/www/cardeal.local

rm -f /etc/apache2/sites-available/cardeal.local.conf

echo "<VirtualHost *:80>
    ServerAdmin webmaster@cardeal.local
    ServerName cardeal.local
    ServerAlias www.cardeal.local
    DocumentRoot /var/www/cardeal.local

    <Directory /var/www/cardeal.local>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/cardeal.local_error.log
    CustomLog ${APACHE_LOG_DIR}/cardeal.local_access.log combined
</VirtualHost>" >> /etc/apache2/sites-available/cardeal.local.conf

sudo a2ensite cardeal.local.conf

sudo apache2ctl configtest

sudo systemctl reload apache2