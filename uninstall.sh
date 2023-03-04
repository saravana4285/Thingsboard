service stop thingsboard
rm -rf thingsboard-3.4.4.deb
apt remove openjdk-*
apt remove postgresql-*
dpkg --remove thingsboard
dpkg --purge thingsboard
