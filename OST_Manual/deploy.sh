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

sudo apt-get update

hostname controller

############ Network Time Protocol ############

sudo apt-get install ntp


############ MySQL database ############

apt-get install python-mysqldb mysql-server

vim /etc/mysql/my.cnf

# [mysqld]
# ...
# bind-address
# = 172.16.0.200

service mysql restart

mysql_install_db

mysql_secure_installation

# Node setup

apt-get install python-mysqldb

############ OpenStack packages ############

apt-get install python-software-properties

add-apt-repository cloud-archive:havana

apt-get update && apt-get dist-upgrade

reboot

############ Messaging server ############

apt-get install rabbitmq-server

############ Install the Identity Service ############

# Install the OpenStack Identity Service on the controller node
apt-get install keystone

# The Identity Service uses a database to store information
#  Specify the location of the database in the configuration file
KEYSTONE_DBPASS = openstack

vim /etc/keystone/keystone.conf
# ...
# [sql]
# # The SQLAlchemy connection string used to connect to the database
# connection = mysql://keystone:openstack@172.16.0.200/keystone
# ...

# Delete the keystone.db file created in the /var/lib/keystone/ directory so that it does not get used by mistake.
rm /var/lib/keystone/keystone.db

# Create a keystone database user

mysql -u root -p

CREATE DATABASE keystone;

GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' \
IDENTIFIED BY 'openstack';

GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' \
IDENTIFIED BY 'openstack';

# Create the database tables for the Identity Service
keystone-manage db_sync

# Define an authorization token to use as a shared secret between the Identity Service and other OpenStack services
openssl rand -hex 10
# 8f06ed24ec1ac08f82bf

vim /etc/keystone/keystone.conf
# Edit /etc/keystone/keystone.conf and change the [DEFAULT] section,
# replacing ADMIN_TOKEN with the results of the command.
# [DEFAULT]
# # A "shared secret" between keystone and other openstack services
# admin_token = 8f06ed24ec1ac08f82bf
# ...

service keystone restart

############ Define users, tenants, and roles ############ 

# We'll set OS_SERVICE_TOKEN, as well as OS_SERVICE_ENDPOINT to specify where the Identity
# Service is running. Replace ADMIN_TOKEN with your authorization token

export OS_SERVICE_TOKEN=8f06ed24ec1ac08f82bf
export OS_SERVICE_ENDPOINT=http://172.16.0.200:35357/v2.0

# create a tenant for an administrative user and a tenant for other OpenStack services to use
keystone tenant-create --name=admin --description="Admin Tenant"

# +-------------+----------------------------------+
# |   Property  |              Value               |
# +-------------+----------------------------------+
# | description |           Admin Tenant           |
# |   enabled   |               True               |
# |      id     | 3aeabc57be3e4ddf953d2fab8105328c |
# |     name    |              admin               |
# +-------------+----------------------------------+

keystone tenant-create --name=service --description="Service Tenant"

# +-------------+----------------------------------+
# |   Property  |              Value               |
# +-------------+----------------------------------+
# | description |          Service Tenant          |
# |   enabled   |               True               |
# |      id     | 7eb0a5cfe558403fae43718b9fc6efed |
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
# |    id    | 5f2d1f76f7ca4b31ab78d5539b452c43 |
# |   name   |              admin               |
# +----------+----------------------------------+

# Create a role for administrative tasks called admin. Any roles you create should map to
# roles specified in the policy.json files of the various OpenStack services. The default
# policy files use the admin role to allow access to most services

keystone role-create --name=admin

# +----------+----------------------------------+
# | Property |              Value               |
# +----------+----------------------------------+
# |    id    | ab2e17f919ea4ad8940db5a212b74c59 |
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

# > --description="Keystone Identity Service"
# +-------------+----------------------------------+
# |   Property  |              Value               |
# +-------------+----------------------------------+
# | description |    Keystone Identity Service     |
# |      id     | a6d5d129a125400389a165ea2f329f7f |
# |     name    |             keystone             |
# |     type    |             identity             |
# +-------------+----------------------------------+

# Specify an API endpoint for the Identity Service by using the returned service ID. When
# you specify an endpoint, you provide URLs for the public API, internal API, and admin
# API. In this guide, the controller host name is used. Note that the Identity Service
# uses a different port for the admin API

keystone endpoint-create \
--service-id=a6d5d129a125400389a165ea2f329f7f \
--publicurl=http://172.16.0.200:5000/v2.0 \
--internalurl=http://172.16.0.200:5000/v2.0 \
--adminurl=http://172.16.0.200:35357/v2.0

# +-------------+----------------------------------+
# |   Property  |              Value               |
# +-------------+----------------------------------+
# |   adminurl  |  http://172.16.0.200:35357/v2.0  |
# |      id     | 89e006155038446796548d14100b9957 |
# | internalurl |  http://172.16.0.200:5000/v2.0   |
# |  publicurl  |  http://172.16.0.200:5000/v2.0   |
# |    region   |            regionOne             |
# |  service_id | a6d5d129a125400389a165ea2f329f7f |
# +-------------+----------------------------------+

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

vi openrc.sh
# export OS_USERNAME=admin \
# export OS_PASSWORD=ADMIN_PASS \
# export OS_TENANT_NAME=admin \
# export OS_AUTH_URL=http://controller:35357/v2.0 

source openrc.sh

# The command returns a token and the ID of the specified tenant
keystone token-get

# Finally, verify that your admin account has authorization to perform administrative commands

keystone user-list

# +----------------------------------+-------+---------+-------------------+
# |                id                |  name | enabled |       email       |
# +----------------------------------+-------+---------+-------------------+
# | 5f2d1f76f7ca4b31ab78d5539b452c43 | admin |   True  | admin@example.com |
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
apt-get install glance python-glanceclient

# The Image Service stores information about images in a database
# Configure the location of the database
vim /etc/glance/glance-api.conf 

# sql_connection = mysql://glance:GLANCE_DBPASS@172.16.0.200/glance

vim /etc/glance/glance-registry.conf

# sql_connection = mysql://glance:GLANCE_DBPASS@172.16.0.200/glance

# Delete the glance.sqlite file created in the /var/lib/glance/ directory 
# so that it does not get used by mistake
rm /var/lib/glance/glance.sqlite

# root and create a glance database user
mysql -u root -p
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' \
IDENTIFIED BY 'GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' \
IDENTIFIED BY 'GLANCE_DBPASS';

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
# |    id    | b1552308c5af4e79b53c7370eea97dd7 |
# |   name   |              glance              |
# +----------+----------------------------------+

keystone user-role-add --user=glance --tenant=service --role=admin

# Configure the Image Service to use the Identity Service for authentication
vim /etc/glance/glance-api.conf
vim /etc/glance/glance-registry.conf

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

vim /etc/glance/glance-api-paste.ini 
vim /etc/glance/glance-registry-paste.ini

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
# |      id     | 6a940315d7eb41979c0c66dd0e9dd800 |
# |     name    |              glance              |
# |     type    |              image               |
# +-------------+----------------------------------+

