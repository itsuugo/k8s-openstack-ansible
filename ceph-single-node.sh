#!/bin/bash

set -e
set -x

# grab ceph packages
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
echo deb https://download.ceph.com/debian/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list

sudo apt-get update
sudo apt-get -y install ceph-deploy

# setup ssh keys
HOSTNAME=$(hostname)
ipaddr=$(ifconfig ens3 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')
echo "$ipaddr $HOSTNAME" >>/etc/hosts

cat /etc/ssh/ssh_host_rsa_key.pub >> ~/.ssh/authorized_keys 
ssh-keyscan -H $HOSTNAME >> ~/.ssh/known_hosts
cd ~

# setup ceph
mkdir cluster
cd cluster/
ceph-deploy new $HOSTNAME
echo "osd crush chooseleaf type = 0" >> ceph.conf
echo "osd pool default size = 1" >> ceph.conf
ceph-deploy install $HOSTNAME
ceph-deploy mon create-initial 
umount -f /dev/vdb
ceph-deploy osd prepare ceph1:vdb
ceph-deploy osd activate ceph1:/dev/vdb1

ceph-deploy admin ceph1
sudo chmod a+r /etc/ceph/ceph.client.admin.keyring 
# Install object storage
ceph-deploy rgw create ceph1
# Install cephs
ceph-deploy mds create ceph1
# Create pool for k8s
ceph osd pool create ose 128
			
