rm -f /etc/netplan/00-installer-config.yaml


echo "network:
    ethernets:
        enp0s3:
            dhcp4: true
            dhcp6: true
            nameservers:
                addresses:
                    - 192.168.10.10
        enp0s8:
            dhcp4: false
            addresses:
                - 192.168.10.1/24
            nameservers:
                addresses:
                    - 192.168.10.10
                search: [cardeal.local]
    version: 2" >> /etc/netplan/00-installer-config.yaml


sudo netplan apply
ip a

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

sudo sysctl -w net.ipv4.ip_forward=1


sudo iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -o enp0s3 -j MASQUERADE
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -j ACCEPT
sudo iptables -A FORWARD -i enp0s3 -o enp0s8 -m state --state RELATED,ESTABLISHED -j ACCEPT

sudo apt update && sudo apt install -y iptables-persistent


