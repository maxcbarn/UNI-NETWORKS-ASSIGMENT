sudo ufw allow Bind9

rm -f /etc/bind/named.conf.options

echo "options {
    directory \"/var/cache/bind\";

    recursion yes;
    allow-recursion { localhost; 192.168.10.0/24; };
    listen-on { 127.0.0.1; 192.168.10.1; }; 
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

sudo mkdir -p /etc/bind/zones

sudo named-checkconf

sudo named-checkzone cardeal.local

sudo named-checkzone 10.168.192.in-addr.arpa

sudo systemctl restart bind9