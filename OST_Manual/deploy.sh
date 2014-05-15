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
