##!/bin/bash

sudo ifconfig eth1 172.16.0.201 netmask 255.255.0.0
sudo ifconfig eth2 10.10.0.201 netmask 255.255.0.0
sudo ifconfig eth3 192.168.100.201 netmask 255.255.255.0

############ Networking ############

# eth0      Link encap:Ethernet  HWaddr 08:00:27:88:0c:a6  
#           inet addr:10.0.2.15  Bcast:10.0.2.255  Mask:255.255.255.0

# eth1      Link encap:Ethernet  HWaddr 08:00:27:28:a5:bf  
#           inet addr:172.16.0.201  Bcast:172.16.255.255  Mask:255.255.0.0

# eth2      Link encap:Ethernet  HWaddr 08:00:27:4b:b0:4f  
#           inet addr:10.10.0.201  Bcast:10.10.255.255  Mask:255.255.0.0

# eth3      Link encap:Ethernet  HWaddr 08:00:27:b9:2b:c4  
#           inet addr:192.168.100.201  Bcast:192.168.255.255  Mask:255.255.0.0

############ Configure Compute Node ############

sudo apt-get update
sudo apt-get install -y vim
sudo apt-get install -y lsof

# Synchronize from the controller node
sudo apt-get install -y ntp

# Install the MySQL client libraries
sudo apt-get install -y python-mysqldb mysql-client

# Enable the OpenStack packages for the distribution that you are using
sudo apt-get install -y python-software-properties
sudo add-apt-repository cloud-archive:havana
sudo apt-get update && sudo  apt-get dist-upgrade
sudo reboot

# Install the appropriate packages for the Compute service
sudo apt-get install -y nova-compute-kvm python-guestfs

# NOTE: When prompted to create a supermin appliance, respond yes

# Due to this bug. To make the current kernel readable, run
dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-$(uname -r)

# To also enable this override for all future kernel updates, create the file /etc/
# kernel/postinst.d/statoverride containing

vi /etc/kernel/postinst.d/statoverride
# #!/bin/sh
# version="$1"
# # passing the kernel version is required
# [ -z "${version}" ] && exit 0
# dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-${version}

# Remember to make the file executable:
chmod +x /etc/kernel/postinst.d/statoverride

# Edit the /etc/nova/nova.conf configuration file and add these lines to the
# appropriate sections:
vim /etc/nova/nova.conf
# ...
# [DEFAULT]
# ...
# auth_strategy=keystone
# ...
[database]
# The SQLAlchemy connection string used to connect to the database
connection = mysql://nova:NOVA_DBPASS@172.16.0.200/nova

# Configure the Compute Service to use the RabbitMQ message broker by setting these
# configuration keys in the [DEFAULT] configuration group of the /etc/nova/nova.conf file:
vim /etc/nova/nova.conf
# rpc_backend = nova.rpc.impl_kombu
# rabbit_host = 172.16.0.200
# rabbit_password = RABBIT_PASS

# Configure Compute to provide remote console access to instances
# Edit /etc/nova/nova.conf and add the following keys under the [DEFAULT]
# section:
vim /etc/nova/nova.conf
# [DEFAULT]
# ...
# my_ip=172.16.0.201
# vnc_enabled=True
# vncserver_listen=0.0.0.0
# vncserver_proxyclient_address=172.16.0.201
# novncproxy_base_url=http://172.16.0.200:6080/vnc_auto.html

# Specify the host that runs the Image Service. Edit /etc/nova/nova.conf file and
# add these lines to the [DEFAULT] section:
vim /etc/nova/nova.conf
# [DEFAULT]
# ...
# glance_host=172.16.0.200

# Edit the /etc/nova/api-paste.ini file to add the credentials to the
# [filter:authtoken] section:

vim +/filter:authtoken /etc/nova/api-paste.ini
# [filter:authtoken]
# paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
# auth_host = 172.16.0.200
# auth_port = 35357
# auth_protocol = http
# admin_tenant_name = service
# admin_user = nova
# admin_password = NOVA_PASS

# Restart the Compute service.
service nova-compute restart

# Remove the SQLite database created by the packages:
rm /var/lib/nova/nova.sqlite

############ Enable Networking ############

# The legacy networking in OpenStack Compute, with a flat network, that takes care of DHCP

# Install the appropriate packages for compute networking on the compute node only.
# These packages are not required on the controller node.

# So that the nova-network service can forward metadata requests on each compute
# node, each compute node must install the nova-api-metadata service, as follows
sudo apt-get install -y nova-network nova-api-metadata


# Edit the nova.conf file to define the networking mode:
# Edit the /etc/nova/nova.conf file and add these lines to the [DEFAULT] section:

vim /etc/nova/nova.conf
# network_manager=nova.network.manager.FlatDHCPManager
# firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver
# network_size=254
# allow_same_net_traffic=False
# multi_host=True
# send_arp_for_ha=True
# share_dhcp_address=True
# force_dhcp_release=True
# flat_network_bridge=br100
# flat_interface=eth2
# public_interface=eth2

# NOTE: we adjust the eth2 with dhcp for the network compute, but be careful,
# with vagrant up or rebooting the networking files restart!!!!!!!!

# Restart the network service:
service nova-network restart

touch openrc.sh
cat >openrc.sh <<EOF
export OS_USERNAME=admin 
export OS_PASSWORD=ADMIN_PASS 
export OS_TENANT_NAME=admin 
export OS_AUTH_URL=http://172.16.0.200:35357/v2.0
EOF
source openrc.sh

sudo apt-get install python-novaclient



############ Enable Networking ############