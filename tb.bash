#!/usr/bin/bash
#
#
# Purpose: Automated Installation of Thingsboard on Debian
# Blame: Saravanan M
# Created On: 07-Feb-2023
#
################################################################




## Variable Declaration
argv=$#
echo $argv
pd=`pwd` 
LOG=$pd/inst_tb.log 
source=/etc/apt/sources.list.d/addsource.list
date=`date +%d-%m-%Y`
dtime=`date +%d-%m-%y-%H-%M`
argfile=$1
tb_tmp_source=/tmp/tbtmpsource    # temp store source.list repositories

## Backing-up files
cp -p $source /etc/apt/sources.list-${dtime}

######  Main Script start here ##### 

/usr/bin/touch $tb_tmp_source
rm -rf /etc/apt/sources.list.d/pgdg.list 
rm -rf /etc/apt/sources.list.d/addsource.list



#################################################
# create postgresql user and database 
################################################
 






##################################################
# Install Postgresql database
#################################################
install_postgresql() {
  /usr/bin/apt install -y wget
  # import the repository signing key
  /usr/bin/wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
  # add repository contents to your system:
  RELEASE=$(lsb_release -cs)
  echo "deb http://apt.postgresql.org/pub/repos/apt/ ${RELEASE}"-pgdg main | tee /etc/apt/sources.list.d/pgdg.list
  #install and launch the postgresql service:
  /usr/bin/apt update
  sleep 2
  apt -y install postgresql-12
  if [[ $? -ne 0 ]]
  then
      echo "step 3: Postgresql installation FAILED" >> $LOG
  else
      echo "All success"
      service postgresql start
      rm -rf /etc/apt/sources.list.d/pgdg.list 
  fi
}

 
####################################################
# Check for existing postgresql installation
###################################################
chk_postgresql(){
  /usr/bin/su - postgres -c 'psql --version'
  if [[ $? -eq 0 ]]
  then
      echo "step 3: Postgresql already found installated" >> $LOG
  else
     install_postgresql 
  fi
}

###################################################
# Install Thingsboard as a service
###################################################
install_thingsboard(){
  /usr/bin/dpkg -i thingsboard-3.4.4.deb 
  if [[ $? -ne 0 ]]
  then
      echo "step 3: Thingsboard download failed" >> $LOG
  else
     chk_postgresql 
  fi
}

####################################################
# Download installation package
###################################################
download_thingsboard(){
    /usr/bin/wget https://github.com/thingsboard/thingsboard/releases/download/v3.4.4/thingsboard-3.4.4.deb
  if [[ $? -ne 0 ]]
  then
      echo "step 3: Thingsboard download failed" >> $LOG
  else
      install_thingsboard
  fi
}

#####################################################
# Configure Java ###################################
#####################################################
conf_java(){
  /usr/bin/update-alternatives --config java
  if [[ $? -ne 0 ]]
  then
      echo "step 3: openjdk configuration Failed" >> $LOG
  else
      echo " Downloading thingsboard" 
      download_thingsboard
  fi
}

#######################################################
# Java Installation ##################################
######################################################
java_install(){
  /usr/bin/apt install openjdk-11-jdk
  if [[ $? -ne 0 ]]
  then
      echo "step 2: openjdk installation Failed" >> $LOG
  else
      echo "Configuring Java"
      conf_java 
  fi
}


#######################################################
# OS Update ###########################################
#######################################################
os_update(){
  /usr/bin/apt update
  if [[ $? -ne 0 ]]
  then
      echo "step 1: OS Update Failed" >> $LOG
      rm -rf /etc/apt/sources.list.d/addsource.list
  else
      echo "Calling Function Java_ install"
      rm -rf /etc/apt/sources.list.d/addsource.list
      java_install 
  fi
}

#######################################################
# update source list  #################################
#######################################################
misc(){
  echo $date >> $LOG
  sed -e '/deb cdrom/ s/^#*/#/' -i /etc/apt/sources.list
  sed -n '/^#SOURCE/,/^#SOURCE-EOF/p' $argfile >> $tb_tmp_source
  
  echo '#-----------------------------------------------' >> $source
  echo 'deb http://deb.debian.org/debian bullseye main' >> $source
  echo 'deb-src http://deb.debian.org/debian bullseye main' >> $source
  echo 'deb http://security.debian.org/debian-security bullseye-security main' >> $source
  echo 'deb-src http://security.debian.org/debian-security bullseye-security main' >> $source
  echo 'deb http://deb.debian.org/debian bullseye-updates main' >> $source
  echo 'deb-src http://deb.debian.org/debian bullseye-updates main' >> $source
  echo 'deb http://deb.debian.org/debian bullseye-backports main' >> $source
  echo 'deb-src http://deb.debian.org/debian bullseye-backports main' >> $source
  echo '#-----------------------------------------------' >> $source
  os_update
}

##############################################
## Usage ##################################### 
##############################################
display_usage(){
    echo "This script must be run with super-user privilege"
    echo -e "\nUsage: $0 [arguments] \n"
}

usage(){
  #if [[  ]] && [[ $UID -eq 0 ]]
  if [ $(whoami) = 'root' ] && [ ${UID} -eq 0 ];
  then
      echo "calling Function Misc"
      misc
  else
      display_usage
      exit 1
  fi
}
################################################
## LOG file creation & Rotation ###############
###############################################
log_create(){
  if [[ -f $LOG ]]
  then
      mv $LOG inst_tb-$dtime
      /usr/bin/touch $LOG
      usage
  else
      /usr/bin/touch $LOG
      usage
  fi
}
################################################


log_create
