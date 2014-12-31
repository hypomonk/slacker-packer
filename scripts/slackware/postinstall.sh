#!/bin/sh -x

# set the time
ntpdate -v -b in.pool.ntp.org
date > /etc/vagrant_box_build_time

# install vagrant keys
mkdir /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
cd /home/vagrant/.ssh
wget -O authorized_keys 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub'
chown -R vagrant /home/vagrant/.ssh
chmod -R go-rwsx /home/vagrant/.ssh

# As sharedfolders are not in defaults ports tree
# We will use vagrant via NFS
# Enable NFS
#echo 'rpcbind_enable="YES"' >> /etc/rc.conf
#echo 'nfs_server_enable="YES"' >> /etc/rc.conf
#echo 'mountd_flags="-r"' >> /etc/rc.conf

# Enable passwordless sudo
#echo "vagrant ALL=(ALL) NOPASSWD: ALL" >> /usr/local/etc/sudoers

# disable X11 because vagrants are (usually) headless
#cat >> /etc/make.conf << EOT
#WITHOUT_X11="YES"
#EOT

#pw groupadd vboxusers
#pw groupmod vboxusers -m vagrant
