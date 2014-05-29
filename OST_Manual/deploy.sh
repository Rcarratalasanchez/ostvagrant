#!/bin/bash

############ Networking ############

#
# eth0      Link encap:Ethernet  HWaddr 08:00:27:88:0c:a6  
#           inet addr:10.0.2.15  Bcast:10.0.2.255  Mask:255.255.255.0


# eth1      Link encap:Ethernet  HWaddr 08:00:27:a6:9c:ac  
#           inet addr:172.16.0.200  Bcast:172.16.255.255  Mask:255.255.0.0


# eth2      Link encap:Ethernet  HWaddr 08:00:27:5c:36:17  
#           inet addr:10.10.0.200  Bcast:10.10.255.255  Mask:255.255.0.0


# eth3      Link encap:Ethernet  HWaddr 08:00:27:9c:53:f0  
#           inet addr:192.168.100.200  Bcast:192.168.100.255  Mask:255.255.255.0

############ Pre-requisites ############

sudo apt-get update
sudo apt-get install vim
sudo apt-get install lsof

############ Network Time Protocol ############

sudo apt-get install ntp


############ MySQL database ############

# install the MySQL client and server packages, and the Python library.

sudo apt-get install -y python-mysqldb mysql-server

# Edit /etc/mysql/my.cnf and set the bind-address to the internal IP address of the
# controller, to enable access from outside the controller node
MYSQL_HOST=172.16.0.200
sudo sed -i "s/^bind\-address.*/bind-address = ${MYSQL_HOST}/g" /etc/mysql/my.cnf

# Restart the MySQL service to apply the changes
service mysql restart

# You must delete the anonymous users that are created when the database is first started.
mysql_install_db

# This command presents a number of options for you to secure your database installation
mysql_secure_installation

# NODE SETUP
sudo apt-get install python-mysqldb

############ OpenStack packages ############

# The Ubuntu Cloud Archive is a special repository that allows you to 
# install newer releases of OpenStack on the stable supported version of Ubuntu

# Install the Ubuntu Cloud Archive for Havana
sudo apt-get install -y python-software-properties
sudo add-apt-repository cloud-archive:havana

# Update the package database, upgrade your system, and reboot for all changes to take effect
sudo apt-get update && sudo apt-get dist-upgrade
sudo reboot

############ Messaging server ############

# On the controller node, install the messaging queue server
sudo apt-get install -y rabbitmq-server

############ Install the Identity Service ############

# Install the OpenStack Identity Service on the controller node
sudo apt-get install -y keystone

# The Identity Service uses a database to store information
#  Specify the location of the database in the configuration file
KEYSTONE_DBPASS = openstack

# Edit /etc/keystone/keystone.conf and change the [sql] section
sudo sed -i "s#^connection.*#connection = \
	mysql://keystone:openstack@172.16.0.200/keystone#" \
	/etc/keystone/keystone.conf

# Delete the keystone.db file created in the /var/lib/keystone/ 
# directory so that it does not get used by mistake.
rm /var/lib/keystone/keystone.db

# Create a keystone database user
mysql -uroot -popenstack << EOF
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' \
IDENTIFIED BY 'openstack';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' \
IDENTIFIED BY 'openstack';
EOF

# Create the database tables for the Identity Service
keystone-manage db_sync

# Define an authorization token to use as a shared secret 
# between the Identity Service and other OpenStack services
ADMIN="`openssl rand -hex 10`"
echo $ADMIN
# 2f37a223379e7a8c24b8

# Edit /etc/keystone/keystone.conf and change the [DEFAULT] section,
# replacing ADMIN_TOKEN with the results of the command.
sudo sed -i "s/^# admin_token.*/admin_token = $ADMIN/" \
	/etc/keystone/keystone.conf

# Restart the Identity Service:
sudo service keystone restart

############ Define users, tenants, and roles ############ 

# We'll set OS_SERVICE_TOKEN, as well as OS_SERVICE_ENDPOINT to specify where the Identity
# Service is running. Replace ADMIN_TOKEN with your authorization token

export OS_SERVICE_TOKEN=${ADMIN}
export OS_SERVICE_ENDPOINT=http://172.16.0.200:35357/v2.0

# create a tenant for an administrative user and a tenant for other OpenStack services to use
keystone tenant-create --name=admin --description="Admin Tenant"

# +-------------+----------------------------------+
# |   Property  |              Value               |
# +-------------+----------------------------------+
# | description |           Admin Tenant           |
# |   enabled   |               True               |
# |      id     | a6ce8bbe18684702a3564e8b987057c8 |
# |     name    |              admin               |
# +-------------+----------------------------------+

keystone tenant-create --name=service --description="Service Tenant"

# +-------------+----------------------------------+
# |   Property  |              Value               |
# +-------------+----------------------------------+
# | description |          Service Tenant          |
# |   enabled   |               True               |
# |      id     | eb3e17818f02454db7dd6f35ae382705 |
# |     name    |             service              |
# +-------------+----------------------------------+

# create an administrative user called admin. Choose a password for the admin user 
# and specify an email address for the account

keystone user-create --name=admin --pass=ADMIN_PASS \
--email=admin@example.com

# +----------+----------------------------------+
# | Property |              Value               |
# +----------+----------------------------------+
# |  email   |        admin@example.com         |
# | enabled  |               True               |
# |    id    | c3109135d6dc4233b8e40a0ba3dfc5c6 |
# |   name   |              admin               |
# +----------+----------------------------------+


# Create a role for administrative tasks called admin. Any roles you create should map to
# roles specified in the policy.json files of the various OpenStack services. The default
# policy files use the admin role to allow access to most services

keystone role-create --name=admin

# +----------+----------------------------------+
# | Property |              Value               |
# +----------+----------------------------------+
# |    id    | ad81b40f619d4242abf505f1dae8e5c3 |
# |   name   |              admin               |
# +----------+----------------------------------+

# you have to add roles to users. Users always log in with a tenant, and roles are
# assigned to users within tenants. Add the admin role to the admin user when logging in
# with the admin tenant
keystone user-role-add --user=admin --tenant=admin --role=admin

############ Define services and API endpoints ############

# • keystone service-create. Describes the service.
# • keystone endpoint-create. Associates API endpoints with the service.

# You must also register the Identity Service itself.
keystone service-create --name=keystone --type=identity \
--description="Keystone Identity Service"

# +-------------+----------------------------------+
# |   Property  |              Value               |
# +-------------+----------------------------------+
# | description |    Keystone Identity Service     |
# |      id     | 5c5bd21c93224303a471f789441033c3 |
# |     name    |             keystone             |
# |     type    |             identity             |
# +-------------+----------------------------------+


# Specify an API endpoint for the Identity Service by using the returned service ID. When
# you specify an endpoint, you provide URLs for the public API, internal API, and admin
# API. In this guide, the controller host name is used. Note that the Identity Service
# uses a different port for the admin API

keystone endpoint-create \
--service-id=5c5bd21c93224303a471f789441033c3 \
--publicurl=http://172.16.0.200:5000/v2.0 \
--internalurl=http://172.16.0.200:5000/v2.0 \
--adminurl=http://172.16.0.200:35357/v2.0

# +-------------+----------------------------------+
# |   Property  |              Value               |
# +-------------+----------------------------------+
# |   adminurl  |  http://172.16.0.200:35357/v2.0  |
# |      id     | 56aef101a1674447a6652882bffd8184 |
# | internalurl |  http://172.16.0.200:5000/v2.0   |
# |  publicurl  |  http://172.16.0.200:5000/v2.0   |
# |    region   |            regionOne             |
# |  service_id | 5c5bd21c93224303a471f789441033c3 |
# +-------------+----------------------------------+

############ Verify the Identity Service installation ############

# To verify the Identity Service is installed and configured correctly, first unset the
# OS_SERVICE_TOKEN and OS_SERVICE_ENDPOINT environment variables.
unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT

# You can now use regular username-based authentication. Request an authentication token
# using the admin user and the password you chose during the earlier administrative user-
# creation step.
keystone --os-username=admin --os-password=ADMIN_PASS \
--os-auth-url=http://172.16.0.200:35357/v2.0 token-get

# You should receive a token in response, paired with your user ID. This verifies that keystone
# is running on the expected endpoint, and that your user account is established with the
# expected credentials

## OK!

#  verify that authorization is behaving as expected by requesting authorization on a tenant
keystone --os-username=admin --os-password=ADMIN_PASS \
--os-tenant-name=admin --os-auth-url=http://172.16.0.200:35357/v2.0 token-get

# You should receive a new token in response, this time including the ID of the tenant you
# specified. This verifies that your user account has an explicitly defined role on the specified
# tenant, and that the tenant exists as expected

## OK!

# You can also set your --os-* variables in your environment to simplify command-line
# usage. Set up a openrc.sh file with the admin credentials and admin endpoint
touch openrc.sh
cat >openrc.sh <<EOF
export OS_USERNAME=admin 
export OS_PASSWORD=ADMIN_PASS 
export OS_TENANT_NAME=admin 
export OS_AUTH_URL=http://172.16.0.200:35357/v2.0
EOF
source openrc.sh

# The command returns a token and the ID of the specified tenant
keystone token-get

# Finally, verify that your admin account has authorization to perform administrative commands
keystone user-list

# +----------------------------------+-------+---------+-------------------+
# |                id                |  name | enabled |       email       |
# +----------------------------------+-------+---------+-------------------+
# | c3109135d6dc4233b8e40a0ba3dfc5c6 | admin |   True  | admin@example.com |
# +----------------------------------+-------+---------+-------------------+

############ Configure the Image Service ############ 

# The OpenStack Image Service enables users to discover, register, and retrieve virtual machine images
# the Image Service offers a REST API that  enables you to query virtual 
# machine image metadata and retrieve an actual image

# • glance-api. Accepts Image API calls for image discovery, retrieval, and storage.
# • glance-registry. Stores, processes, and retrieves metadata about images. Metadata
# includes size, type, and so on.
# • Database. Stores image metadata. 

# The OpenStack Image Service acts as a registry for virtual disk images

# Install the Image Service on the controller node
sudo apt-get install -y glance python-glanceclient

# The Image Service stores information about images in a database
# Configure the location of the database
sudo sed -i "s,^sql_connection.*,sql_connection = \
mysql://glance:GLANCE_DBPASS@172.16.0.200/glance," \
/etc/glance/glance-{registry,api}.conf

# Delete the glance.sqlite file created in the /var/lib/glance/ directory 
# so that it does not get used by mistake
rm /var/lib/glance/glance.sqlite

# root and create a glance database user
mysql -u root -popenstack <<EOF
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' \
IDENTIFIED BY 'GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' \
IDENTIFIED BY 'GLANCE_DBPASS';
EOF

# Create the database tables for the Image Service:
glance-manage db_sync

# Create a glance user that the Image Service can use to authenticate with the Identity
# Service. Choose a password and specify an email address for the glance user. Use the
# service tenant and give the user the admin role.
source openrc.sh 
keystone user-create --name=glance --pass=GLANCE_PASS --email=glance@example.com
# +----------+----------------------------------+
# | Property |              Value               |
# +----------+----------------------------------+
# |  email   |        glance@example.com        |
# | enabled  |               True               |
# |    id    | a5000c45da5c4d87ab038bfb8daac046 |
# |   name   |              glance              |
# +----------+----------------------------------+

keystone user-role-add --user=glance --tenant=service --role=admin

# Configure the Image Service to use the Identity Service for authentication
vim +/keystone_authtoken /etc/glance/glance-api.conf
vim +/keystone_authtoken /etc/glance/glance-registry.conf

# Add the following keys under the [keystone_authtoken] section:

# [keystone_authtoken]
# ...
# auth_uri = http://172.16.0.200:5000
# auth_host = 172.16.0.200
# auth_port = 35357
# auth_protocol = http
# admin_tenant_name = service
# admin_user = glance
# admin_password = GLANCE_PASS

# Add the following key under the [paste_deploy] section:

# [paste_deploy]
# ...
# flavor = keystone

vim +/filter:authtoken /etc/glance/glance-api-paste.ini 
vim +/filter:authtoken /etc/glance/glance-registry-paste.ini

# [filter:authtoken]
# paste.filter_factory=keystoneclient.middleware.auth_token:filter_factory
# auth_host=172.16.0.200
# admin_user=glance
# admin_tenant_name=service
# admin_password=GLANCE_PASS

# Register the Image Service with the Identity Service so that other OpenStack services
# can locate it. Register the service and create the endpoint:
keystone service-create --name=glance --type=image \
--description="Glance Image Service"
# +-------------+----------------------------------+
# |   Property  |              Value               |
# +-------------+----------------------------------+
# | description |       Glance Image Service       |
# |      id     | 231903a6cdc14aaf9f6197282e6fede3 |
# |     name    |              glance              |
# |     type    |              image               |
# +-------------+----------------------------------+

# Use the id property returned for the service to create the endpoint:
keystone endpoint-create \
--service-id=231903a6cdc14aaf9f6197282e6fede3 \
--publicurl=http://172.16.0.200:9292 \
--internalurl=http://172.16.0.200:9292 \
--adminurl=http://172.16.0.200:9292
# +-------------+----------------------------------+
# |   Property  |              Value               |
# +-------------+----------------------------------+
# |   adminurl  |     http://172.16.0.200:9292     |
# |      id     | f68d1a8299574604860fabe73cb7c754 |
# | internalurl |     http://172.16.0.200:9292     |
# |  publicurl  |     http://172.16.0.200:9292     |
# |    region   |            regionOne             |
# |  service_id | 231903a6cdc14aaf9f6197282e6fede3 |
# +-------------+----------------------------------+

# Restart the glance service with its new settings.
service glance-registry restart
# glance-registry stop/waiting
# glance-registry start/running, process 5212
service glance-api restart
# glance-api stop/waiting
# glance-api start/running, process 5222

############ Configure the Image Service ############

# To test the Image Service installation, download at least one virtual machine image that is
# known to work with OpenStack

# Download the image into a dedicated directory using wget or curl:
# This walk through uses the 64-bit CirrOS QCOW2 image

mkdir images
cd images/
wget http://cdn.download.cirros-cloud.net/0.3.1/cirros-0.3.1-x86_64-disk.img

# glance image-create --name=imageLabel --disk-format=fileFormat \
# --container-format=containerFormat --is-public=accessValue < imageFile

glance image-create --name="CirrOS 0.3.1" --disk-format=qcow2 \
--container-format=bare --is-public=true < cirros-0.3.1-x86_64-disk.img
# +------------------+--------------------------------------+
# | Property         | Value                                |
# +------------------+--------------------------------------+
# | checksum         | d972013792949d0d3ba628fbe8685bce     |
# | container_format | bare                                 |
# | created_at       | 2014-05-29T20:04:54                  |
# | deleted          | False                                |
# | deleted_at       | None                                 |
# | disk_format      | qcow2                                |
# | id               | 6ff74e38-ff5b-46cd-b906-5e4e5f6b609a |
# | is_public        | True                                 |
# | min_disk         | 0                                    |
# | min_ram          | 0                                    |
# | name             | CirrOS 0.3.1                         |
# | owner            | a6ce8bbe18684702a3564e8b987057c8     |
# | protected        | False                                |
# | size             | 13147648                             |
# | status           | active                               |
# | updated_at       | 2014-05-29T20:04:54                  |
# +------------------+--------------------------------------+


# Confirm that the image was uploaded and display its attributes:
glance image-list
# +--------------------------------------+--------------+-------------+------------------+----------+--------+
# | ID                                   | Name         | Disk Format | Container Format | Size     | Status |
# +--------------------------------------+--------------+-------------+------------------+----------+--------+
# | 6ff74e38-ff5b-46cd-b906-5e4e5f6b609a | CirrOS 0.3.1 | qcow2       | bare             | 13147648 | active |
# +--------------------------------------+--------------+-------------+------------------+----------+--------+

############ Configure Compute services ############

# The Compute service is a cloud computing fabric controller, 
# which is the main part of an IaaS system

# Compute interacts with the Identity Service for authentication, Image Service for images,
# and the Dashboard for the user and administrative interface

# API
# • nova-api service. Accepts and responds to end user compute API calls
# • nova-api-metadata service. Accepts metadata requests from instances. 
#   Only used when you run in multi-host mode with nova-network installations

# Compute core

# • nova-compute process. A worker daemon that creates and terminates virtual machine
# instances through hypervisor APIs

# •nova-scheduler process. Takes a virtual machine instance request from the 
# queue and determines on which compute server host it should run

# • nova-conductor module. Mediates interactions between nova-compute and the
# database.

# Networks

# • nova-network worker daemon. Similar to nova-compute, it accepts networking
# tasks from the queue and performs tasks to manipulate the network, such as setting
# up bridging interfaces or changing iptables rules

# •nova-dhcpbridge script. Tracks IP address leases and records them in the database
# by using the dnsmasq dhcp-script facility.

# Console interface

# • nova-consoleauth daemon. Authorizes tokens for users that console proxies provide.

# • nova-novncproxy daemon. Provides a proxy for accessing running instances through a
# VNC connection.

# • nova-console daemon. Deprecated for use with Grizzly. Instead, the nova-
# xvpnvncproxy is used.

# • nova-xvpnvncproxy daemon. A proxy for accessing running instances through a VNC
# connection. 

# • nova-cert daemon. Manages x509 certificates.

# Command-line clients and other interfaces
# • nova client. Enables users to submit commands as a tenant administrator or end user.
# • nova-manage client. Enables cloud administrators to submit commands.

############ Install Compute controller services ############

# Install these Compute packages, which provide the Compute services that run on the
# controller node.
sudo apt-get install -y nova-novncproxy novnc nova-api \
nova-ajax-console-proxy nova-cert nova-conductor \
nova-consoleauth nova-doc nova-scheduler \
python-novaclient

# Compute stores information in a database. The examples in this guide use the MySQL
# database that is used by other OpenStack services.

vim /etc/nova/nova.conf
# The SQLAlchemy connection string used to connect to the database
# [database]
# connection = mysql://nova:NOVA_DBPASS@172.16.0.200/nova
# [keystone_authtoken]
# auth_host = 172.16.0.200
# auth_port = 35357
# auth_protocol = http
# admin_tenant_name = service
# admin_user = nova
# admin_password = NOVA_PASS


# Configure the Compute Service to use the RabbitMQ message broker by setting these
# configuration keys in the [DEFAULT] configuration group of the /etc/nova/
# nova.conf file:

vim /etc/nova/nova.conf
# rpc_backend = nova.rpc.impl_kombu
# rabbit_host = 172.16.0.200
# rabbit_password = RABBIT_PASS

# Delete the nova.sqlite file created in the /var/lib/nova/ directory 
# so that it does not get used by mistake
rm /var/lib/nova/nova.sqlite

# Create a nova database use
mysql -u root -popenstack <<EOF
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' \
IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' \
IDENTIFIED BY 'NOVA_DBPASS';
EOF

# Create the Compute service tables:
nova-manage db sync

# Set the my_ip, vncserver_listen, and vncserver_proxyclient_address
# configuration options to the internal IP address of the controller node

vim /etc/nova/nova.conf

# my_ip=172.16.0.200
# vncserver_listen=172.16.0.200
# vncserver_proxyclient_address=172.16.0.200

# Example of /etc/nova/nova.conf
# ------------------------------------------
# [DEFAULT]
# dhcpbridge_flagfile=/etc/nova/nova.conf
# dhcpbridge=/usr/bin/nova-dhcpbridge
# logdir=/var/log/nova
# state_path=/var/lib/nova
# lock_path=/var/lock/nova
# force_dhcp_release=True
# iscsi_helper=tgtadm
# libvirt_use_virtio_for_bridges=True
# connection_type=libvirt
# root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
# verbose=True
# ec2_private_dns_show_ip=True
# api_paste_config=/etc/nova/api-paste.ini
# volumes_path=/var/lib/nova/volumes
# enabled_apis=ec2,osapi_compute,metadata

# rpc_backend = nova.rpc.impl_kombu
# rabbit_host = 172.16.0.200
# rabbit_password = RABBIT_PASS

# my_ip=172.16.0.200
# vncserver_listen=172.16.0.200
# vncserver_proxyclient_address=172.16.0.200

# auth_strategy=keystone

# [database]
# # The SQLAlchemy connection string used to connect to the database
# connection = mysql://nova:NOVA_DBPASS@172.16.0.200/nova

# [keystone_authtoken]
# auth_host = 172.16.0.200
# auth_port = 35357
# auth_protocol = http
# admin_tenant_name = service
# admin_user = nova
# admin_password = NOVA_PASS
# ----------------------------

# Create a nova user that Compute uses to authenticate with the Identity Service. Use
# the service tenant and give the user the admin role:

keystone user-create --name=nova --pass=NOVA_PASS --email=nova@example.com
# +----------+----------------------------------+
# | Property |              Value               |
# +----------+----------------------------------+
# |  email   |         nova@example.com         |
# | enabled  |               True               |
# |    id    | 64c59a47b18e432cb91feffb0acb30d6 |
# |   name   |               nova               |
# +----------+----------------------------------+

keystone user-role-add --user=nova --tenant=service --role=admin

# Configure Compute to use these credentials with the Identity Service running on the
# controller. Replace NOVA_PASS with your Compute password.

vim /etc/nova/nova.conf
# [DEFAULT]
# ...
# auth_strategy=keystone

# Add the credentials to the /etc/nova/api-paste.ini file. Add these options to
# the [filter:authtoken] section:
vim /etc/nova/api-paste.ini

# [filter:authtoken]
# paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
# auth_host = 172.16.0.200
# auth_port = 35357
# auth_protocol = http
# auth_uri = http://172.16.0.200:5000/v2.0
# admin_tenant_name = service
# admin_user = nova
# admin_password = NOVA_PASS

# Ensure that the api_paste_config=/etc/nova/api-paste.ini
# option is set in the /etc/nova/nova.conf file

# You must register Compute with the Identity Service so that other OpenStack services
# can locate it. Register the service and specify the endpoint:
keystone service-create --name=nova --type=compute \
--description="Nova Compute service"
# +-------------+----------------------------------+
# |   Property  |              Value               |
# +-------------+----------------------------------+
# | description |       Nova Compute service       |
# |      id     | e0b6916e15b746bfacfdfddce42facf0 |
# |     name    |               nova               |
# |     type    |             compute              |
# +-------------+----------------------------------+

# Use the id property that is returned to create the endpoint.
keystone endpoint-create \
--service-id=e0b6916e15b746bfacfdfddce42facf0 \
--publicurl=http://172.16.0.200:8774/v2/%\(tenant_id\)s \
--internalurl=http://172.16.0.200:8774/v2/%\(tenant_id\)s \
--adminurl=http://172.16.0.200:8774/v2/%\(tenant_id\)s

# +-------------+-------------------------------------------+
# |   Property  |                   Value                   |
# +-------------+-------------------------------------------+
# |   adminurl  | http://172.16.0.200:8774/v2/%(tenant_id)s |
# |      id     |      5c9b56fe78c3491197a7473b2078e1a0     |
# | internalurl | http://172.16.0.200:8774/v2/%(tenant_id)s |
# |  publicurl  | http://172.16.0.200:8774/v2/%(tenant_id)s |
# |    region   |                 regionOne                 |
# |  service_id |      e0b6916e15b746bfacfdfddce42facf0     |
# +-------------+-------------------------------------------+

# Restart Compute services
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

# To verify your configuration, list available images:
nova image-list

# +--------------------------------------+--------------+--------+--------+
# | ID                                   | Name         | Status | Server |
# +--------------------------------------+--------------+--------+--------+
# | 6ff74e38-ff5b-46cd-b906-5e4e5f6b609a | CirrOS 0.3.1 | ACTIVE |        |
# +--------------------------------------+--------------+--------+--------+

# ---------------------------------------------------------------------------

#################### AFTER CONFIGURED THE COMPUTE NODE

# Create a network that virtual machines can use. Do this once for the entire installation and
# not on each compute node. Run the nova network-create command on the controller:

# nova network-create vmnet --fixed-range-v4=10.0.0.0/24 \
# --bridge=br100 --multi-host=T

# FAIL!!!!!!!!!!!!!!!!!!!!!!!!!

# Generate a keypair that consists of a private and public key to be able to launch
# instances on OpenStack

ssh-keygen
cd /root/.ssh
nova keypair-add --pub_key id_rsa.pub mykey

# which you can use to connect to an instance launched by using mykey as the
# keypair. To view available keypairs
nova keypair-list

# +-------+-------------------------------------------------+
# | Name  | Fingerprint                                     |
# +-------+-------------------------------------------------+
# | mykey | a5:b0:01:bc:96:84:6c:0f:82:61:d8:b4:b8:a7:7f:48 |
# +-------+-------------------------------------------------+

# To launch an instance, you must specify the ID for the flavor you want to use for the
# instance. A flavor is a resource allocation profile
nova flavor-list

# +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+
# | ID | Name      | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public |
# +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+
# | 1  | m1.tiny   | 512       | 1    | 0         |      | 1     | 1.0         | True      |
# | 2  | m1.small  | 2048      | 20   | 0         |      | 1     | 1.0         | True      |
# | 3  | m1.medium | 4096      | 40   | 0         |      | 2     | 1.0         | True      |
# | 4  | m1.large  | 8192      | 80   | 0         |      | 4     | 1.0         | True      |
# | 5  | m1.xlarge | 16384     | 160  | 0         |      | 8     | 1.0         | True      |
# +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+

# Get the ID of the image to use for the instance
nova image-list

# +--------------------------------------+--------------+--------+--------+
# | ID                                   | Name         | Status | Server |
# +--------------------------------------+--------------+--------+--------+
# | 6ff74e38-ff5b-46cd-b906-5e4e5f6b609a | CirrOS 0.3.1 | ACTIVE |        |
# +--------------------------------------+--------------+--------+--------+

# To use SSH and ping, you must configure security group rules
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
# +-------------+-----------+---------+-----------+--------------+
# | IP Protocol | From Port | To Port | IP Range  | Source Group |
# +-------------+-----------+---------+-----------+--------------+
# | tcp         | 22        | 22      | 0.0.0.0/0 |              |
# +-------------+-----------+---------+-----------+--------------+

nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
# +-------------+-----------+---------+-----------+--------------+
# | IP Protocol | From Port | To Port | IP Range  | Source Group |
# +-------------+-----------+---------+-----------+--------------+
# | icmp        | -1        | -1      | 0.0.0.0/0 |              |
# +-------------+-----------+---------+-----------+--------------+

# Launch the instance:
# $ nova boot --flavor flavorType --key_name keypairName --
# image ID newInstanceName

nova boot --flavor 1 --key_name mykey --image 6ff74e38-ff5b-46cd-b906-5e4e5f6b609a --security_group default cirrOS

# FAIL!!!!!!!!!!!!!!!!!! (networking FAILED)

# After the instance launches, use the nova list to view its status. The status changes
# from BUILD to ACTIVE
nova list

# +--------------------------------------+--------+--------+------------+-------------+----------+
# | ID                                   | Name   | Status | Task State | Power State | Networks |
# +--------------------------------------+--------+--------+------------+-------------+----------+
# | 4baf6423-d24f-4226-93e1-54c6e25d9f13 | cirrOS | BUILD  | scheduling | NOSTATE     |          |
# +--------------------------------------+--------+--------+------------+-------------+----------+

# To show details for a specified instance:
nova show 4baf6423-d24f-4226-93e1-54c6e25d9f13

# To connect into the VM created
ssh cirros@10.0.0.3

############ Install the dashboard ############

# Install the dashboard on the node that can contact the Identity Service as root:
sudo apt-get install -y memcached libapache2-mod-wsgi openstack-dashboard

# Remove the openstack-dashboard-ubuntu-theme package
sudo apt-get remove --purge openstack-dashboard-ubuntu-theme

# Modify the value of CACHES['default']['LOCATION'] in /etc/
# openstack-dashboard/local_settings.py to match the ones set in /etc/
# memcached.conf.

# Open /etc/openstack-dashboard/local_settings.py and look for this line:
vim /etc/openstack-dashboard/local_settings.py
# CACHES = {
# 'default': {
# 'BACKEND' : 'django.core.cache.backends.memcached.MemcachedCache',
# 'LOCATION' : '127.0.0.1:11211'
# }
# }

# • The address and port must match the ones set in /etc/
# memcached.conf.
# If you change the memcached settings, you must restart the Apache web
# server for the changes to take effect

# • You can use options other than memcached option for session storage.
# Set the session back-end through the SESSION_ENGINE option.

# • To change the timezone, use the dashboard or edit the /etc/
# openstack-dashboard/local_settings.py file.

# Change the following parameter: TIME_ZONE = "UTC"

# Update the ALLOWED_HOSTS in local_settings.py to include the addresses you
# wish to access the dashboard from.
# Edit /etc/openstack-dashboard/local_settings.py:
# ALLOWED_HOSTS = ['localhost', '192.168.1.130', '192.168.1.131']

# You can easily run the dashboard on a separate server, by changing the appropriate
# settings in local_settings.py.

# Edit /etc/openstack-dashboard/local_settings.py and change
# OPENSTACK_HOST to the hostname of your Identity Service:
# OPENSTACK_HOST = "172.16.0.200"

# Workaround for memcached
locale-gen es_ES.UTF-8
dpkg-reconfigure locales

# Start the Apache web server and memcached:
service apache2 restart
service memcached restart

You can now access the dashboard at http://controller/horizon .
Login with credentials for any user that you created with the OpenStack Identity
Service
