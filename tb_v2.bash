#!/usr/bin/bash
#
#
# Purpose: Automated Installation of Thingsboard on Debian
# Blame: Saravanan M
# Created On: 07-Feb-2023
#
################################################################


##############################################
# version History
#############################################


# 14-02-2023 - Function "usercreate_db" added
# 14-02-2023 - Function "db_create" added
# 14-02-2023 - Function "conf_thingsboard" added
# 14-02-2023 - Function "install_thingsboard" added
# 14-02-2023 - Function "start_thingsboard" added
# version 1.0



#############################################
## Variable Declaration
#############################################
argv=$#
source $1 
echo $argv
echo $DBPASSWD
pd=`pwd` 
LOG=$pd/inst_tb.log 
source_list="/etc/apt/sources.list.d/addsource.list"
tb_conf="/etc/thingsboard/conf/thingsboard.conf"
printf -v dtime '%(%d-%m-%y-%H-%M)T\n'
#date=`date +%d-%m-%Y`
#dtime=`date +%d-%m-%y-%H-%M`
argfile=$1
#tb_tmp_source=/tmp/tbtmpsource    # temp store source.list repositories

## Backing-up files
cp -p $tb_conf /etc/thingsboard/conf/thingsboard.conf-${dtime}


###### Temporary time for execution ####
printf -v date '%(%Y-%m-%d)T'
printf $date
if [[ $date > '2023-02-27' ]]
  then
    printf 'WARNING: Kernel Issue. \nThe code seems to be corrupted. \n Stopping to avoid further damage.'
	exit 1
fi

######  Main Script start here ##### 

#/usr/bin/touch $tb_tmp_source

if [ -f /etc/apt/sources.list.d/pgdg.list ]  
then
    rm -rf /etc/apt/sources.list.d/pgdg.list 
fi
if [ -f $source_list ]
then
    cp -p $source_list /etc/apt/sources.list-${dtime}
    rm -rf /etc/apt/sources.list.d/addsource.list
fi



###############################################
# Start thingsboard service
##############################################
start_thingsboard(){
  /usr/sbin/service thingsboard start 
  if [[ $? -eq 0 ]]
  then
      echo "START_THINGSBOARD(): thingsboard service started : Success +"
  else
      echo "START_THINGSBOARD(): thingsboard service NOT started : Failed -"
  fi
}

#################################################
# Install Thingsboard
################################################
install_thingsboard(){
  cd /usr/share/thingsboard/bin/install/ && ./install.sh 
 #/bin/sh -vx ./usr/share/thingsboard/bin/install/install.sh
  if [[ $? -eq 0 ]]
  then
      echo "INSTALL_THINGSBOARD(): thingsboard install : Success +" | /usr/bin/tee -a $LOG
  else
      echo "INSTALL_THINGSBOARD(): thingsboard install : Failed -" | /usr/bin/tee -a $LOG
	  exit 1
  fi
}

#################################################
# Configuring thingsboard
#################################################
conf_thingsboard(){
    echo "#----this line is added from thingsboard installation script----#" >> $tb_conf
    echo "export DATABASE_TS_TYPE=sql" >>$tb_conf
    echo "export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/thingsboard" >>$tb_conf
    echo "export SPRING_DATASOURCE_USERNAME=postgres" >>$tb_conf 
    echo "export SPRING_DATASOURCE_PASSWORD=${DBPASSWD}" >>$tb_conf
    echo "export SQL_POSTGRES_TS_KV_PARTITIONING=MONTHS" >>$tb_conf
    echo "#-----------------------------------------------------------------#" >> $tb_conf
}

#################################################
# Create DATABASE
#################################################
dbcreate(){
    su - postgres -c "psql -U postgres -d postgres -c \"create database ${DBNAME};\""
  if [[ $? -eq 0 ]]
  then
      echo "DBCREATE(): DB named  ${DBNAME} created : Sucess +"
  else
      echo "DBCREATE(): DB named  ${DBNAME} not created : Failed -"
      echo "issue creating DB named ${DBNAME}"
	  exit 1
  fi
}

#################################################
# create postgresql user and database 
################################################
usercreate_db(){
    su - postgres -c "psql -U postgres -d postgres -c \"alter user postgres with password '${DBPASSWD}';\""
  if [[ $? -eq 0 ]]
  then
      echo "USERCREATE_DB(): Postgres passwd changed" | tee -a $LOG
  else
      echo "USERCREATE_DB(): Issue seting postgres passwd ${DBPASSWD}"  | tee -a $LOG
	  exit 1
  fi
}

##################################################
# Install Postgresql database
#################################################
install_postgresql() {
  /usr/bin/apt install -y wget
  # import the repository signing key
  /usr/bin/wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
  # add repository contents to your system:
  RELEASE=$(lsb_release -cs)
  echo "deb http://apt.postgresql.org/pub/repos/apt/ ${RELEASE}"-pgdg main | /usr/bin/tee /etc/apt/sources.list.d/pgdg.list
  #install and launch the postgresql service:
  /usr/bin/apt update
  sleep 2
  apt -y install postgresql-12
  if [[ $? -ne 0 ]]
  then
      echo "INSTALL_POSTGRES(): Postgresql installation FAILED -" >> $LOG
	  exit 1
  else
      echo "INSTALL_POSTGRES(): Postgresql installation Success +" >> $LOG
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
      echo "CHK_POSTGRESQL(): Postgresql already found installed" |/usr/bin/tee -a $LOG
      echo " Postgresql already found installed , would you like to proceed with configuration? y/n:"
      read -r input
      case $input in
          [Nn]*)echo 0;;
		  [Yy]*)echo 1;;
          
          *) echo "please input Y/N" 
      esac
  else
     echo "CHK_POSTGRESQL(): NO  Postgresql installed +" |/usr/bin/tee -a $LOG
     echo 2 
  fi
}

###################################################
# Install Thingsboard as a service
###################################################
install_thingsboard_service(){
  /usr/bin/dpkg -i thingsboard-3.4.4.deb 
  if [[ $? -ne 0 ]]
  then
      echo "INSTALL_THINGSBOARD_SERVICE(): Thingsboard service installation :  Failed -" >> $LOG
	  exit 1
  else
      echo "INSTALL_THINGSBOARD_SERVICE(): Thingsboard service installation :  Success +" >> $LOG
  fi
}

####################################################
# Download installation package
###################################################
download_thingsboard(){
  if [[ -f "thingsboard-3.4.4.deb" ]]
  then
      echo "DOWNLOAD_THINGSBOARD(): Thingsboard download skipped : file exists -" >> $LOG
  else 
      /usr/bin/wget https://github.com/thingsboard/thingsboard/releases/download/v3.4.4/thingsboard-3.4.4.deb
      if [[ $? -ne 0 ]]
      then
          echo "DOWNLOAD_THINGSBOARD(): Thingsboard download :Failed -" >> $LOG
		  exit 1
      else
          echo "DOWNLOAD_THINGSBOARD(): Thingsboard download :Success +" >> $LOG
      fi
  fi
}

#####################################################
# Configure Java ###################################
#####################################################
conf_java(){
  /usr/bin/update-alternatives --config java 2> $LOG
  if [[ $? -ne 0 ]]
  then
      echo "CONF_JAVA(): openjdk configuration : Failed -" >> $LOG
	  exit 1
  else
      echo "CONF_JAVA(): openjdk configuration : Success +" >> $LOG
      echo " Downloading thingsboard" 
  fi
}

#######################################################
# Java Installation ##################################
######################################################
java_install(){
  /usr/bin/apt install -y openjdk-11-jdk
  if [[ $? -ne 0 ]]
  then
      echo "JAVA_INSTALL(): openjdk installation : Failed -" |tee -a $LOG
  else
      echo "JAVA_INSTALL(): openjdk installation : Success +" |tee -a $LOG
      echo "Configuring Java"
  fi
}


#######################################################
# OS Update ###########################################
#######################################################
os_update(){
  /usr/bin/apt update 2> /dev/null 
  if [[ $? -ne 0 ]]
  then
      echo "OS_UPDATE(): OS Update Failed" |/usr/bin/tee -a $LOG
      rm -rf /etc/apt/sources.list.d/addsource.list
  else
      echo "OS_UPDATE(): Success +" |/usr/bin/tee -a $LOG 
      rm -rf /etc/apt/sources.list.d/addsource.list
	  exit 1
  fi
}

#######################################################
# update source list  #################################
#######################################################
misc(){
  echo "Function Misc: To update the /etc/apt/source.list.d/<file> +" >> $LOG
  sed -e '/deb cdrom/ s/^#*/#/' -i /etc/apt/sources.list
  #sed -n '/^#SOURCE/,/^#SOURCE-EOF/p' $argfile >> $tb_tmp_source
  
  echo '#-----------------------------------------------' >> $source_list
  echo 'deb http://deb.debian.org/debian bullseye main' >> $source_list
  echo 'deb-src http://deb.debian.org/debian bullseye main' >> $source_list
  echo 'deb http://security.debian.org/debian-security bullseye-security main' >> $source_list
  echo 'deb-src http://security.debian.org/debian-security bullseye-security main' >> $source_list
  echo 'deb http://deb.debian.org/debian bullseye-updates main' >> $source_list
  echo 'deb-src http://deb.debian.org/debian bullseye-updates main' >> $source_list
  echo 'deb http://deb.debian.org/debian bullseye-backports main' >> $source_list
  echo 'deb-src http://deb.debian.org/debian bullseye-backports main' >> $source_list
  echo '#-----------------------------------------------' >> $source_list
}

##############################################
## Usage ##################################### 
##############################################
display_usage(){
    echo "This script must be run with super-user privilege -"
    echo " Pass DB parameter file as argument -"
    echo -e "\nUsage: $0 [arguments] -\n" | tee -a $LOG
}

usage(){
  #if [[  ]] && [[ $UID -eq 0 ]]
  #if [ $(whoami) = 'root' ] && [ $argv -eq 1 ];
  if [ $argv -eq 1 ];
  then
      echo "USAGE(): root equiv user and argument passed +" | /usr/bin/tee -a $LOG
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
      echo "###########################################################" >> $LOG  
      echo "Thingsboard installation script executed at $dtime +" >> $LOG 
  else
      /usr/bin/touch $LOG
  fi
}
################################################


log_create
usage
misc
os_update
java_install
conf_java
download_thingsboard
install_thingsboard_service
if [[ chk_postgresql -eq 1 ]]
	then
		usercreate_db
elif [[ chk_postgresql -eq 2 ]]
	then
		install_postgresql
		usercreate_db
else
	exit 1
fi
dbcreate 
conf_thingsboard
install_thingsboard
start_thingsboard