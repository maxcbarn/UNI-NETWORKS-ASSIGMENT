sudo apt install isc-dhcp-server -y


rm -f /etc/default/isc-dhcp-server

echo "INTERFACESv4=\"enp0s8\"" >> /etc/default/isc-dhcp-server

rm -f /etc/dhcp/dhcpd.conf

echo "subnet 192.168.10.0 netmask 255.255.255.0 {
  range 192.168.10.100 192.168.10.200;
  option routers 192.168.10.1;
  option domain-name-servers 192.168.10.10;
  default-lease-time 600;
  max-lease-time 7200;
}" >> /etc/dhcp/dhcpd.conf

sudo systemctl restart isc-dhcp-server

sudo systemctl enable isc-dhcp-server

sudo systemctl status isc-dhcp-server



