rm -f /etc/netplan/00-installer-config.yaml


echo "network:
    ethernets:
        enp0s3:
            dhcp4: false
            addresses:
                - 192.168.10.10/24
            routes:
                - to: default
                  via: 192.168.10.1
            nameservers:
                addresses:
                    - 192.168.10.10
    version: 2" >> /etc/netplan/00-installer-config.yaml

sudo netplan apply
ip a
