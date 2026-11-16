rm -f /etc/netplan/00-installer-config.yaml


echo "network:
    ethernets:
        enp0s3:
            dhcp4: true
            dhcp6: true
        enp0s8:
            dhcp4: false
            addresses:
                - 192.168.10.1/24
    version: 2" >> /etc/netplan/00-installer-config.yaml




sudo netplan apply
ip a
