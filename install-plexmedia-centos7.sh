# UNTESTED
# PLEASE COPY AND PASTE EACH AREA FOR FURTHER TESTING AND SUBMIT ISSUES!

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
yum -y install wget git epel-release curl mlocate

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
# https://forums.plex.tv/discussion/158526/nginx-reverse-proxy
yum -y install nginx
cd  /etc/nginx/

cat > nginx.conf << eof
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;

        location / {
        proxy_pass http://localhost:32400/web/;
        }

        location /web {
        proxy_pass http://localhost:32400;
        }

        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
    }

}
eof

# File Configuration
MEDIA="/home/media"
mkdir -p ${MEDIA}
mkdir -p ${MEDIA}/TV/
mkdir -p ${MEDIA}/Movies/

# Samba/NAS Configuration
yum -y install cifs-utils
${SUDO} useradd -u 5000 usr_smb_core
${SUDO} groupadd -g 6000 share_smb_core
${SUDO} usermod -G share_smb_core -a ${PLEXUSR}
mkdir /mnt/nas
mkdir /mnt/nas/media
cd /root/
cat > creds_smb_library_core << eof
username=NasUserName
password=NasUserPassword
eof
${SUDO} chmod 0600 /root/creds_smb_library_core
${SUDO} mount.cifs \\\\127.0.0.1\\shareName /mnt/nas/media -o credentials=/root/creds_smb_library_core,uid=5000,gid=6000
echo "\\\\127.0.0.1\\shareName /mnt/nas/media -o credentials=/root/creds_smb_library_core,uid=5000,gid=6000" >> /etc/fstab

# Firewalld Configuration
# Note: Look into making those private only connections.
cd  /etc/firewalld/services/
${SUDO} systemctl stop firewalld.service

## PlexMediaServer
cat > plexmediaserver.xml << eof
<?xml version="1.0" encoding="utf-8"?>
<service version="1.0">
  <short>plexmediaserver</short>
  <description>Plex TV Media Server</description>
  <port port="1900" protocol="udp"/>
  <port port="5353" protocol="udp"/>
  <port port="32400" protocol="tcp"/>
  <port port="32410" protocol="udp"/>
  <port port="32412" protocol="udp"/>
  <port port="32413" protocol="udp"/>
  <port port="32414" protocol="udp"/>
  <port port="32469" protocol="tcp"/>
</service>
eof
${SUDO} firewall-cmd --permanent --add-service=plexmediaserver
${SUDO} firewall-cmd --permanent --zone=public --add-service=plexmediaserver

## SickRage
cat > sickrage.xml << eof
<?xml version="1.0" encoding="utf-8"?>
<service version="1.0">
  <short>sickrage</short>
  <description>SickRage TV Automation</description>
  <port port="8081" protocol="tcp"/>
</service>
eof
${SUDO} firewall-cmd --permanent --add-service=sickrage
${SUDO} firewall-cmd --permanent --zone=public --add-service=sickrage

## Transmission
cat > transmission.xml << eof
<?xml version="1.0" encoding="utf-8"?>
<service version="1.0">
  <short>transmission</short>
  <description>Torrent Client</description>
  <port port="9091" protocol="tcp"/>
</service>
eof
${SUDO} firewall-cmd --permanent --add-service=transmission
${SUDO} firewall-cmd --permanent --zone=public --add-service=transmission

## CouchPotatoServer
cat > couchpotatoserver.xml << eof
<?xml version="1.0" encoding="utf-8"?>
<service version="1.0">
  <short>couchpotatoserver</short>
  <description>Movie Automation</description>
  <port port="5050" protocol="tcp"/>
</service>
eof
${SUDO} firewall-cmd --permanent --add-service=couchpotatoserver
${SUDO} firewall-cmd --permanent --zone=public --add-service=couchpotatoserver

## Nginx
${SUDO} firewall-cmd --permanent --zone=public --add-service=http 
${SUDO} firewall-cmd --permanent --zone=public --add-service=https

## Samba
${SUDO} firewall-cmd --permanent --zone=public --add-service=samba

${SUDO} firewall-cmd --reload
${SUDO} restart firewalld.service

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
