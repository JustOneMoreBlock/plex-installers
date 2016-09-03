# Update Resolve Servers
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# Variables
SUDO="sudo"
# Get Public IP
IP="$(curl icanhazip.com)"

# Install Prerequisites
mkdir -p /opt/
yum -y update
yum -y install wget git epel-release curl

# Disable SELinux
sed -i /etc/selinux/config -r -e 's/^SELINUX=.*/SELINUX=disabled/g'

# Add User: Plex Generate and Set Password
PLEXUSR="plex"
export PLEXPWD=`cat /dev/urandom | tr -dc A-Za-z0-9 | dd bs=10 count=1 2>/dev/null`
adduser -c "Plex Media Server User" -d /home/${PLEXUSR} -s /bin/bash ${PLEXUSR}
echo "${PLEXUSR}:${PLEXPWD}" | /usr/sbin/chpasswd
echo "New User: ${PLEXUSR}"
echo "New Password: ${PLEXPWD}"
# unset ${PLEXPWD}

# Install PlexMediaServer
su ${PLEXUSR}
mkdir -p ~/Downloads/
cd ~/Downloads/
# Add Latest Version Checker
yum -y install https://downloads.plex.tv/plex-media-server/1.1.3.2700-6f64a8d/plexmediaserver-1.1.3.2700-6f64a8d.x86_64.rpm

# Install SickRage
yum -y install python-cheetah unrar
git clone https://github.com/SickRage/SickRage.git sickrage
cp /opt/sickrage/runscripts/init.systemd /etc/systemd/system/sickrage.service
sed -i "s/User=\(.*\)/\EUser=${PLEXUSR}/g" /etc/systemd/system/sickrage.service
sed -i "s/Group=\(.*\)/\EGroup=${PLEXUSR}/g" /etc/systemd/system/sickrage.service

# Install CouchPotatoServer
yum -y install http://mirror.centos.org/centos/7/cloud/x86_64/openstack-liberty/common/pyOpenSSL-0.15.1-1.el7.noarch.rpm
yum -y install libxslt-devel python-devel
easy_install lxml
git clone https://github.com/CouchPotato/CouchPotatoServer.git
cp /opt/CouchPotatoServer/init/couchpotato.service /etc/systemd/system/couchpotato.service
sed -i "s/ExecStart=\(.*\)/\EExecStart=\/opt\/CouchPotatoServer\/CouchPotato.py/g" /etc/systemd/system/couchpotato.service
sed -i "s/User=\(.*\)/\EUser=${PLEXUSR}/g" /etc/systemd/system/couchpotato.service
sed -i "s/Group=\(.*\)/\EGroup=${PLEXUSR}/g" /etc/systemd/system/couchpotato.service

# Install Transmission
yum -y gcc gcc-c++ m4 make automake libtool gettext openssl-devel libcurl-devel libevent-devel intltool gtk3-devel
cd ~/Downloads/
wget https://transmission.cachefly.net/transmission-2.84.tar.xz
tar -xf transmission-2.84.tar.xz
cd transmission-2.84
./configure --prefix=/opt/transmission
make
make install
cp /opt/transmission/daemon/transmission-daemon.service /etc/systemd/system/transmission-daemon.service

# Install Nginx Proxy
yum -y install nginx

# File Configuration

# Firewalld Configuration
${SUDO} firewall-cmd --permanent --zone=public --add-service=http 
${SUDO} firewall-cmd --permanent --zone=public --add-service=https
${SUDO} firewall-cmd --reload

#Configure Permissions
chown -Rf ${PLEXUSR} /opt/
chgrp -Rf ${PLEXUSR} /opt/

# Add and Start Services
${SUDO} systemctl enable plexmediaserver.service
${SUDO} systemctl start plexmediaserver.service
${SUDO} systemctl enable sickrage.service
${SUDO} systemctl start sickrage.service
${SUDO} systemctl enable couchpotato
${SUDO} systemctl start couchpotato
${SUDO} systemctl enable transmission-daemon
${SUDO} systemctl start transmission-daemon
${SUDO} systemctl enable nginx
${SUDO} systemctl start nginx
