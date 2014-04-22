#!/bin/bash

### Add the grizzly repositories to the apt sources
echo \
"deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-proposed/grizzly main" \
| sudo tee /etc/apt/sources.list.d/folsom.list

sudo apt-get update
# Return this warning  
# W: GPG error: http://ubuntu-cloud.archive.canonical.com precise-proposed/grizzly Release: 
# The following signatures couldn't be verified because the public key is not available: 
# NO_PUBKEY 5EDB1B62EC4926EA
sudo apt-get -y install ubuntu-cloud-keyring

### Installing OpenStack Identity Service

## Install and configure MySQL
MYSQL_ROOT_PASS=openstack
MYSQL_HOST=172.16.0.200
# To enable non-interactive installations of MySQL, set the following
echo "mysql-server-5.5 mysql-server/root_password password \
	$MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again password \
	$MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password seen true" \
	| sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again seen true" \
	| sudo debconf-set-selections

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
# Update without errors
sudo apt-get -q -y install mysql-server

# bin address: On a computer having multiple network interfaces, this
# option can be used to select which interface is employed
# when connecting to the MySQL server.
sudo sed -i "s/^bind\-address.*/bind-address = ${MYSQL_HOST}/g" \
	/etc/mysql/my.cnf

sudo service mysql restart
mysqladmin -u root password ${MYSQL_ROOT_PASS}

mysql -u root --password=${MYSQL_ROOT_PASS} -h localhost \
	-e "GRANT ALL ON *.* to root@\"localhost\" IDENTIFIED BY \"${MYSQL_ROOT_PASS}\" WITH GRANT OPTION;"

mysql -u root --password=${MYSQL_ROOT_PASS} -h localhost \
	-e "GRANT ALL ON *.* to root@\"${MYSQL_HOST}\" IDENTIFIED BY\"${MYSQL_ROOT_PASS}\" WITH GRANT OPTION;"

mysql -u root --password=${MYSQL_ROOT_PASS} -h localhost \
	-e "GRANT ALL ON *.* to root@\"%\" IDENTIFIED BY \"${MYSQL_ROOT_PASS}\" WITH GRANT OPTION;"

mysqladmin -uroot -p${MYSQL_ROOT_PASS} flush-privileges

## Install OpenStack Identity service:

# Install the OpenStack Identity service (keystone)
sudo apt-get update
sudo apt-get -y install keystone python-keyring

# we need to configure the backend database store
# Create the keystone database in MySQL
MYSQL_ROOT_PASS=openstack
mysql -uroot -p$MYSQL_ROOT_PASS -e "CREATE DATABASE keystone;"

# create a user that is specific to our OpenStack Identity service
MYSQL_KEYSTONE_PASS=openstack
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%';"
mysql -uroot -p$MYSQL_ROOT_PASS -e "SET PASSWORD FOR 'keystone'@'%' = PASSWORD('$MYSQL_KEYSTONE_PASS');"

# configure OpenStack Identity service to use this database by editing
# the /etc/keystone/keystone.conf file, and then change the sql_connection
# line to match the database credentials

