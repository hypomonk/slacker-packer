#!/bin/sh

# Loosely based on: ftp://ftp.arm.slackware.com/slackwarearm/slackwarearm-devtools/minirootfs/scripts/build_miniroot
# by Matt Doolin <matt@coolermonitor.com>

ISO="/dev/sr0"
SOURCE="/mnt/source"
ROOT="/mnt/root"
DISK="/dev/sda"

# create partitions
sgdisk -zog $DISK
ENDSECTOR=`sgdisk -E $DISK`
SWAPSECTOR=`expr $ENDSECTOR - 4194304`	# set swap to 2GB

# create boot/root partition and enable boot flag
sgdisk -n 1:0:$SWAPSECTOR -c 1:"Slackware64-14.1" -g $DISK
sgdisk -A 1:set:2 $DISK
mkfs.ext4 "${DISK}1"

# create swap partition and enable
sgdisk -n 2:$SWAPSECTOR:$ENDSECTOR -c 2:"Swap" -t 2:8200 -g $DISK
sgdisk -p $DISK
mkswap "${DISK}2"
swapon "${DISK}2"
mkdir $SOURCE
mkdir $ROOT

mount $ISO $SOURCE
mount "${DISK}1" $ROOT

# relatively minimum (~600MB) install here. additional but non-essential packages are after the break. (<600MB)

cd $SOURCE
PKGLIST="a/aaa_base \
a/aaa_elflibs \
a/aaa_terminfo \
a/acl \
a/attr \
a/bash \
a/bin \
a/bzip2 \
a/coreutils \
a/cxxlibs \
a/dbus \
a/dcron \
a/devs \
a/dialog \
a/e2fsprogs \
a/ed \
a/elvis \
a/etc \
a/file \
a/lilo \
a/lvm2 \
a/less \
a/findutils \
a/gawk \
a/gettext \
a/getty-ps \
a/glibc-solibs \
a/glibc-zoneinfo \
a/gptfdisk \
a/grep \
a/gzip \
a/kbd \
a/jfsutils \
a/inotify-tools \
a/kernel-huge \
a/kernel-modules \
a/kmod \
a/mtd-utils \
a/openssl-solibs \
a/pkgtools \
a/procps \
a/reiserfsprogs \
a/shadow \
a/sed \
a/sysklogd \
a/sysvinit \
a/sysvinit-scripts \
a/tar \
a/u-boot-tools \
a/udev \
a/usbutils \
a/util-linux \
a/vboot-utils \
a/which \
a/xfsprogs \
a/xz \
ap/nano \
ap/slackpkg \
n/curl \
n/dhcpcd \
n/lftp \
n/links \
n/network-scripts \
n/nfs-utils \
n/nmap \
n/ntp \
n/iputils* \
n/net-tools \
n/iproute2 \
n/openssh \
n/portmap \
n/rsync \
n/telnet \
n/traceroute \
n/wget \
n/wpa_supplicant \
n/wireless-tools \
l/lzo \
l/libnl3 \

ap/bc \
ap/diffutils \
ap/joe \
ap/lm_sensors \
ap/mariadb \
d/python \
l/dbus-glib \
l/dbus-python \
l/glib2 \
l/libffi \
l/libmcrypt \
l/libnl \
l/libxml2 \
l/mpfr \
l/ncurses \
l/pygobject \
l/urwid \
n/gnupg \
n/openvpn \
n/php \
n/net-snmp \
d/perl"

# ap/bc for cpu temp calc (/usr/local/crm-33/bin/tempstat.sh)
# ap/diffutils for slacpkg (template generation)
# ap/joe for me
# ap/lm_sensors for snmpd
# ap/mariadb for cfengine
# d/python for wicd
# l/dbus-glib for wicd
# l/dbus-python for wicd
# l/glib2 for wicd
# l/libffi for wicd
# l/libmcrypt for sql connection in read-sensor.php
# l/libnl for snmpd
# l/libxml2 for cfengine
# l/mpfr for slackpkg
# l/ncurses for slackpkg, wicd
# l/pygobject for wicd
# l/urwid for wicd
# n/gnupg for slackpkg
# n/nmap for debugging
# n/openvpn
# php for read-sensor.php
# n/net-snmp for mrtg
# d/perl for snmpd

for PKG in $PKGLIST ; do
  # This pushing & popping is done because we populate our package list outside
  # of the "slackware" directory in order to not expand "kernel_*" in the list above.
  # So now we enter into the "slackware" directory and install the given
  # package names.
  #
  # Check if there's a version in 'patches' (useful if rebuilding a stable release's mini root)
  if [ -f patches/packages/${PKG#*/}-[0-9]*.t?z ]; then
     # Found in '/patches':
     pushd patches/packages > /dev/null
     installpkg --terse -root $ROOT ${PKG#*/}-[0-9]*.t?z
   else
     # Assume it's in the '/slackware64' dir
     pushd slackware64 > /dev/null
     installpkg --terse -root $ROOT $PKG-[0-9]*.t?z
   fi
  popd > /dev/null
done

echo "localtime" > $ROOT/etc/hardwareclock

date > $ROOT/etc/vagrant_box_build_time

# create /etc/fstab
cat << EOF > $ROOT/etc/fstab
/dev/sda1       /               ext4    defaults                1       1
/dev/sda2       swap            swap    defaults                0       0
devpts          /dev/pts        devpts  gid=5,mode=620          0       0
proc            /proc           proc    defaults                0       0
tmpfs           /dev/shm        tmpfs   defaults                0       0
EOF

# configure lilo and install kernel
cat << EOF > $ROOT/etc/lilo.conf
append=" vt.default_utf8=0"
boot = /dev/sda
lba32
change-rules
reset
vga = 773
image = /boot/vmlinuz
root = /dev/sda1
label = Slackware64
read-only
EOF

$ROOT/sbin/lilo -r $ROOT -C /etc/lilo.conf

# add vagrant user
$ROOT/usr/sbin/useradd -R $ROOT -d /home/vagrant -m -G wheel -c "Vagrant User" -r vagrant
echo "vagrant ALL=(ALL) NOPASSWD: ALL" >> $ROOT/etc/sudoers

# set root and vagrant password
echo "root:vagrant" | $ROOT/usr/sbin/chpasswd -R $ROOT
echo "vagrant:vagrant" | $ROOT/usr/sbin/chpasswd -R $ROOT

# enable DHCP by default
sed -i 's/USE_DHCP\[0\]=.*/USE_DHCP\[0\]="yes"/g' $ROOT/etc/rc.d/rc.inet1.conf

# configure minimum services
chmod 755 $ROOT/etc/rc.d/rc.{snmp*,ssh*,ntp*,local,nfsd}

reboot
