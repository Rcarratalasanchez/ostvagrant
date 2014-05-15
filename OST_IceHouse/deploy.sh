#!/bin/bash

## Networks

# Public Network vboxnet0 (172.16.0.0/16)
VBoxManage hostonlyif create
VBoxManage hostonlyif ipconfig vboxnet0 --ip 172.16.0.254 --netmask 255.255.0.0

# Private Network vboxnet1 (10.0.0.0/8)
VBoxManage hostonlyif create
VBoxManage hostonlyif ipconfig vboxnet1 --ip 10.0.0.254 --netmask 255.0.0.0

# Create VirtualBox Machine
VboxManage createvm --name openstack1 --ostype Ubuntu_64 --register

VBoxManage modifyvm openstack1 --memory 2048 --nic1 nat \
--nic2 hostonly --hostonlyadapter2 vboxnet0 --nic3 hostonly \
--hostonlyadapter3 vboxnet1
