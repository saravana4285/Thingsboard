#!/bin/bash

:'
Purpose: Thingsboard installation
Platform: Debian OS
Author: Saravanan M
Date: 07-Feb-2023
Tested on Debian version: 5.10.0-21-amd64'

# Variable Declaration



# Main Script Starts Here
# Install Java11(OpenJDK)
install_java11 () {
    /usr/bin/sudo apt update
    /usr/bin/sudo apt install openjdk-11-jdk
    /usr/bin/sudo update-alternatives --config java
}

#Thingsboard service Installation
install_thingsboard () {
    wget https://github.com/thingsboard/thingsboard/releases/download/v3.4.3/thingsboard-3.4.3.deb
    #installing Thingsboard as a service
    /usr/bin/sudo dpkg -i thingsboard-3.4.3.deb
}

#Postfresql Installation
install_postgresql () {
    # install **wget** if not already installed:
    /usr/bin/sudo apt install -y wget
    # import the repository signing key:
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    # add repository contents to your system:
    RELEASE=$(lsb_release -cs)
    echo "deb http://apt.postgresql.org/pub/repos/apt/ ${RELEASE}"-pgdg main | sudo tee  /etc/apt/sources.list.d/pgdg.list
}

# install and launch the postgresql service:
start_postgresql () {
    /usr/bin/sudo apt update
    /usr/bin/sudo apt -y install postgresql-12
    /usr/bin/sudo service postgresql start
}

:'
sudo su - postgres
psql
\password
\q

Then, press “Ctrl+D” to return to main user console and connect to the database to create thingsboard DB:

psql -U postgres -d postgres -h 127.0.0.1 -W
CREATE DATABASE thingsboard;
\q
'

#Thingsboard configuration
configure_thingsboard () {
    /usr/bin/sudo nano /etc/thingsboard/conf/thingsboard.conf
}

#Don’t forget to replace “PUT_YOUR_POSTGRESQL_PASSWORD_HERE” with your real postgres user password:
# DB Configuration 
configure_postgresql () {
    export DATABASE_TS_TYPE=sql
    export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/thingsboard
    export SPRING_DATASOURCE_USERNAME=postgres
    export SPRING_DATASOURCE_PASSWORD=PUT_YOUR_POSTGRESQL_PASSWORD_HERE
    # Specify partitioning size for timestamp key-value storage. Allowed values: DAYS, MONTHS, YEARS, INDEFINITE.
    export SQL_POSTGRES_TS_KV_PARTITIONING=MONTHS
}

#Run installation script
install_script () {
# --loadDemo option will load demo data: users, devices, assets, rules, widgets.
    /usr/bin/sudo /usr/share/thingsboard/bin/install/install.sh 
    #Start Thingsboard service
    /usr/bin/sudo service thingsboard start
}

#curl http://localhost:8080/