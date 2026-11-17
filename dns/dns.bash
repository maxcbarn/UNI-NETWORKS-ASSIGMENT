sudo ufw allow Bind9

rm -f /etc/bind/named.conf.options

echo "options {
    directory \"/var/cache/bind\";

    recursion yes;
    allow-recursion { localhost; 192.168.10.0/24; };
    listen-on { any; }; 
    allow-query { localhost; 192.168.10.0/24; };
    allow-transfer { none; };

    forwarders {
        8.8.8.8;
        1.1.1.1;
    };

    dnssec-validation auto;
};" >> /etc/bind/named.conf.options


rm -f /etc/bind/named.conf.local

echo "zone \"cardeal.local\" {
    type master;
    file \"/etc/bind/zones/db.cardeal.local\";
};

zone \"10.168.192.in-addr.arpa\" {
    type master;
    file \"/etc/bind/zones/db.192.168.10\";
};" >> /etc/bind/named.conf.local



sudo rm -r /etc/bind/zones

sudo mkdir -p /etc/bind/zones

sudo bash -c 'echo "\$TTL    604800
@       IN      SOA     ns1.cardeal.local. admin.cardeal.local. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.cardeal.local.
@       IN      MX  10  mail.cardeal.local.

ns1     IN      A       192.168.10.10
mail    IN      A       192.168.10.20
@       IN      A       192.168.10.10
www     IN      A       192.168.10.10" > /etc/bind/zones/db.cardeal.local'

sudo bash -c 'echo "\$TTL    604800
@       IN      SOA     ns1.cardeal.local. admin.cardeal.local. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.cardeal.local.

10      IN      PTR     ns1.cardeal.local.
20      IN      PTR     mail.cardeal.local.
10      IN      PTR     www.cardeal.local." > /etc/bind/zones/db.192.168.10'


sudo named-checkconf

sudo named-checkzone cardeal.local /etc/bind/zones/db.cardeal.local

sudo named-checkzone 10.168.192.in-addr.arpa /etc/bind/zones/db.192.168.10

sudo systemctl stop bind9

sudo systemctl restart bind9

sudo systemctl stop named

sudo systemctl restart named

sudo systemctl status named

sudo ss -tulnp | grep :53
