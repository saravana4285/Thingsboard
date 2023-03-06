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
# 25-02-2023 - Main functions are created  
# 27-02-2023 - Main functions completed
# 27-02-2023 - intial Date check function added 
# 04-03-2023 - SHC test success
# 04-03-2023 - apt - renamed to apt-get to ignore depriciated warnings 
# 04--3-2023 - Fixing the main Function from sequential to parallel execution.
# 04-03-2023 - printf command replaced date command for imprving perfrmance
# 06-03-2023 - thingsboard conf file backup has check to ensure backup works
# 06-03-2023 - thingsboard download is skipped if the file is alread present 
# version 5.0

#variable of thingsboard version and java version
#add sudo for install.sh
#printf command from sudha script




#############################################
## Variable Declaration
#############################################
argv=$#
source $1 
pd=`pwd` 
LOG=$pd/inst_tb.log 
source_list="/etc/apt/sources.list.d/addsource.list"
tb_conf="/etc/thingsboard/conf/thingsboard.conf"
dtime=`printf -v dtime '%(%d-%m-%y-%H-%M)T\n'`
#dtime=`date +%d-%m-%y-%H-%M`
argfile=$1
SUCCESS=0
FAIL=1

echo $java_ver
echo "openjdk-${java_ver}"



#Java Pre-requisties
Java_runtime="java11-runtime"
Java_inst="oracle-java11-installer

#Entries to be appended to source.list file (Function misc())
line1='deb http://deb.debian.org/debian bullseye main'
line2='deb-src http://deb.debian.org/debian bullseye main'
line3='deb http://security.debian.org/debian-security bullseye-security main'
line4='deb-src http://security.debian.org/debian-security bullseye-security main'
line5='deb http://deb.debian.org/debian bullseye-updates main'
line6='deb-src http://deb.debian.org/debian bullseye-updates main'
line7='deb http://deb.debian.org/debian bullseye-backports main'
line8='deb-src http://deb.debian.org/debian bullseye-backports main'
#NOTE: If the number of lines increased or decresed remember to update in function main()


#Entries to be appended to the thingsboard configuration file (Function conf_thingsboard()) 
conf_line1='export DATABASE_TS_TYPE=sql'
conf_line2='export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/thingsboard'
conf_line3='export SPRING_DATASOURCE_USERNAME=postgres'
conf_line4='export SPRING_DATASOURCE_PASSWORD=${DBPASSWD}'
conf_line5='export SQL_POSTGRES_TS_KV_PARTITIONING=MONTHS'
#NOTE: If the number of lines increased or decresed remember to update in function conf_thingsboard() 


## Backing-up files

if [ -f /etc/thingsboard/conf/thingsboard.conf ]
then 
    cp -p $tb_conf /etc/thingsboard/conf/thingsboard.conf-${dtime}
    if [[ $? -ne 0 ]]
    then
        echo " The thingsboard config file backup failed , please check" |/usr/bin/tee -a $LOG
        exit 1
    fi
fi

######  Main Script start here ##### 

if [ -f /etc/apt/sources.list.d/pgdg.list ]  
then
    rm -rf /etc/apt/sources.list.d/pgdg.list 
fi
if [ -f $source_list ]
then
    cp -p $source_list /etc/apt/sources.list-${dtime}
    rm -rf /etc/apt/sources.list.d/addsource.list
fi



####################################################################################################
# Start thingsboard service
####################################################################################################
function start_thingsboard(){
  /usr/sbin/service thingsboard start 
  if [[ $? -eq 0 ]]
  then
      echo "Function start_thingsboard(+): thingsboard service started Successfully" | /usr/bin/tee -a $LOG
      return $SUCCESS
  else
      echo "Error: Function start_thingsboard(-): Issue starting thingboard service, pls check" | /usr/bin/tee -a $LOG
      return $FAIL
  fi
}

####################################################################################################
# Install Thingsboard
####################################################################################################
function install_thingsboard(){
  /usr/bin/sudo /usr/share/thingsboard/bin/install/install.sh 
  if [[ $? -eq 0 ]]
  then
      echo "Function install_thingsboard(+): thingsboard installed Successfully" | /usr/bin/tee -a $LOG
      return $SUCCESS
  else
      echo "ERROR: Function install_thingsboard(-): Issue installing thingboard, pls check" |/usr/bin/tee -a $LOG
      return $FAIL
  fi
}

####################################################################################################
# Configuring thingsboard
####################################################################################################
function conf_thingsboard(){
    echo "#----this line is added from thingsboard installation script----#" >> $tb_conf
    /usr/bin/grep -qxF -- "$conf_line1" $tb_conf || echo "$conf_line1" >> $tb_conf
    /usr/bin/grep -qxF -- "$conf_line2" $tb_conf || echo "$conf_line2" >> $tb_conf
    /usr/bin/grep -qxF -- "$conf_line3" $tb_conf || echo "$conf_line3" >> $tb_conf
    /usr/bin/grep -qxF -- "$conf_line4" $tb_conf || echo "$conf_line4" >> $tb_conf
    /usr/bin/grep -qxF -- "$conf_line5" $tb_conf || echo "$conf_line5" >> $tb_conf
    echo "#-----------------------------------------------------------------#" >> $tb_conf
    #check if the line 1 present in $tb_conf 
    /usr/bin/grep -i "${conf_line1}" $tb_conf
    if [[ $? -eq 0 ]]
    then
        echo "Function conf_thingsboard(+):Configuration entried added Sucessfully to $tb_conf" | /usr/bin/tee -a $LOG
        return $SUCCESS
    else
        echo "ERROR: conf_thingsboard(-): thingsboard configuration failed, please check" | /usr/bin/tee -a $LOG
        return $FAIL
    fi
}

####################################################################################################
# Create DATABASE
####################################################################################################
function dbcreate(){
  su - postgres -c "psql -U postgres -d postgres -c \"create database ${DBNAME};\""
  if [[ $? -eq 0 ]]
  then
      echo "Function dbcreate(+):DB named ${DBNAME} created Sucessfully" | /usr/bin/tee -a $LOG
      return $SUCCESS
  else
      echo "ERROR: dbcreate(-): unable to create db $DBNAME, please check" | /usr/bin/tee -a $LOG
      return $FAIL
  fi
}

####################################################################################################
# change  postgresql user "postgres" password
####################################################################################################
function change_dbpasswd(){
    su - postgres -c "psql -U postgres -d postgres -c \"alter user postgres with password '${DBPASSWD}';\""
  if [[ $? -eq 0 ]]
  then
      echo "Function change_dbpasswd(+): Postgres passwd changed" | /usr/bin/tee -a $LOG
      return $SUCCESS
  else
      echo "ERROR: Function change_dbpasswd(-): unable to set password of  $DBNAME, please check" | /usr/bin/tee -a $LOG
      return $FAIL
  fi
}

####################################################################################################
# Install Postgresql database
####################################################################################################
function install_postgresql() {
  /usr/bin/apt-get install -y wget
  # import the repository signing key
  /usr/bin/wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
  # add repository contents to your system:
  RELEASE=$(lsb_release -cs)
  echo "deb http://apt.postgresql.org/pub/repos/apt/ ${RELEASE}"-pgdg main | /usr/bin/tee /etc/apt/sources.list.d/pgdg.list
  #install and launch the postgresql service:
  /usr/bin/apt-get update
  sleep 2
  /usr/bin/apt-get -y install postgresql-12
  if [[ $? -ne 0 ]]
  then
      echo "Function install_postgresql(-): Postgresql installation FAILED -" >> $LOG
      return $FAIL
  else
      echo "ERROR: Function install_postgresql(-): Unable to install postgresql, pls check" | /usr/bin/tee -a $LOG
      service postgresql start
      rm -rf /etc/apt/sources.list.d/pgdg.list 
      return $SUCCESS
  fi
}

 
####################################################################################################
# Check for existing postgresql installation
####################################################################################################
function chk_postgresql(){
  /usr/bin/su - postgres -c 'psql --version'
  if [[ $? -ne 0 ]]
  then
      echo "Function chk_postgresql(+): No Postgresql already found installed" |/usr/bin/tee -a $LOG
      return $SUCCESS
  else
      echo "ERROR: Function chk_postgresql(-): postgresql already exists, please check" | /usr/bin/tee -a $LOG
      return $FAIL 
  fi
}

####################################################################################################
# Install Thingsboard as a service
####################################################################################################
function install_thingsboard_service(){
  sudo /usr/bin/dpkg -i thingsboard-${tb_ver}.deb 
  if [[ $? -eq 0 ]]
  then
      echo "Function install_thingsboard_service(+):Thingsboard service installation success " |/usr/bin/tee -a $LOG
      return $SUCCESS
  else
      return $FAIL
  fi
}


####################################################################################################
# Check thingsboard already installed 
####################################################################################################
function chk_thingboard_installed(){
  /usr/bin/dpkg -s thingsboard
  if [[ $? -ne 0 ]]
  then
      echo "Function chk_thingsboard_installed(+): Existing Thingsboard service not found" |/usr/bin/tee -a $LOG
      return $SUCCESS
  else
      echo "ERROR: Function chk_thingsboard_installed(-): thingboard already exists, please check" | /usr/bin/tee -a $LOG
      return $FAIL
  fi
}
####################################################################################################
# Download Thingsboard Installables
####################################################################################################
function download_thingsboard(){
    /usr/bin/wget https://github.com/thingsboard/thingsboard/releases/download/v${tb_ver}/thingsboard-${tb_ver}.deb
    if [[ $? -eq 0 ]]
      then
          echo "Function download_thingsboard(+): Thingsboard installables downloaded" | /usr/bin/tee -a $LOG
          return $SUCCESS
      else
          echo "ERROR: Function downlaod_thingsboard(-): Failed, please check" | /usr/bin/tee -a $LOG
          return $FAIL 
      fi
}


####################################################################################################
# Check installables already downloaded
####################################################################################################
function chk_thingsboard_downloads(){
  if [[ -f "thingsboard-${tb_ver}.deb" ]]
  then
      echo "WARNING: Function chk_thingsboard_downloads(-): Thingsboard download skipped as file exists -" | /usr/bin/tee -a $LOG
      return $FAIL
  else 
      return $SUCCESS
  fi
}



####################################################################################################
# Configure Java 
####################################################################################################
function conf_java(){
    /usr/bin/update-alternatives --config java 
    if [[ $? -eq 0 ]]
    then
        echo "Function conf_java(+): Java configuration success" | /usr/bin/tee -a $LOG
        return $SUCCESS
    else
        echo "ERROR: Function conf_java(-):installables already found" | /usr/bin/tee -a $LOG
        return $FAIL 
    fi
}

####################################################################################################
# Java Installation 
####################################################################################################
function java_install(){

    /usr/bin/apt-get install -y $Java_runtime
    /usr/bin/apt-get install -y $Java_inst 
    /usr/bin/apt-get install -y openjdk-${java_ver}-* 
    if [[ $? -eq 0 ]]
    then
        echo "Function java_install(+):Java version 11 installed" | /usr/bin/tee -a $LOG
        java -version | /usr/bin/tee -a $LOG
        return $SUCCESS
    else
        echo "ERROR: Function java_install(-): Java configuration failed, please check.." | /usr/bin/tee -a $LOG
        return $FAIL 
    fi
}


####################################################################################################
# Check Java Installed ?
####################################################################################################
function check_java(){
    /usr/bin/apt-get list --installed |grep -i openjdk-${java_ver}-jdk
    if [[ $? -ne 0 ]]
    then
        echo "Function check_java(+):No Existing Java version 11 found" | /usr/bin/tee -a $LOG
        return $SUCCESS
    else
        echo "ERROR: Function check_java(-): Java 11 jdk exists, please check.." | /usr/bin/tee -a $LOG
        return $FAIL 
    fi
}


####################################################################################################
# OS Update 
# OS_update to update the Operating system
####################################################################################################
function os_update(){
  if { sudo apt-get update 2>&1  || echo E: update failed; } | grep -q '^[WE]:';then
      echo "Function OS_UPDATE(+): OS updated Successfully" |/usr/bin/tee -a $LOG;
      rm -rf /etc/apt/sources.list.d/addsource.list;
      return $SUCCESS
  else
      rm -rf /etc/apt/sources.list.d/addsource.list;
      echo "ERROR: Function os_update(-): OS Update Failed, please check.." | /usr/bin/tee -a $LOG
      return $FAIL 
  fi
}

####################################################################################################
# update source list  
# inorder to skip java installation error, new lines need to be appended in source.list
####################################################################################################
function misc(){
  sed -e '/deb cdrom/ s/^#*/#/' -i /etc/apt/sources.list
  echo '#-----------------------------------------------' >> $source_list
  /usr/bin/grep -qxF -- "$line1" $source_list || echo "$line1" >> $source_list
  /usr/bin/grep -qxF -- "$line2" $source_list || echo "$line2" >> $source_list
  /usr/bin/grep -qxF -- "$line3" $source_list || echo "$line3" >> $source_list
  /usr/bin/grep -qxF -- "$line4" $source_list || echo "$line4" >> $source_list
  /usr/bin/grep -qxF -- "$line5" $source_list || echo "$line5" >> $source_list
  /usr/bin/grep -qxF -- "$line6" $source_list || echo "$line6" >> $source_list
  /usr/bin/grep -qxF -- "$line7" $source_list || echo "$line7" >> $source_list
  /usr/bin/grep -qxF -- "$line8" $source_list || echo "$line8" >> $source_list
  echo '#-----------------------------------------------' >> $source_list
  /usr/bin/grep -i "${line1}" $source_list
  if [[ $? -eq 0 ]]
  then
      echo "Function Misc(+): line variables are updated to the /etc/apt/source.list.d/<file> +" | /usr/bin/tee -a $LOG
      return $SUCCESS
  else
      echo "ERROR: Function misc(-): unable to update source list, please check.." | /usr/bin/tee -a $LOG
      return $FAIL 
  fi
}

####################################################################################################
## Usage 
# check if the argument file is present while executing the script
# if no argument file provided then display usage error
# the argument file should have DB related environment variables
####################################################################################################
function display_usage(){
    echo "ERROR: DB Environment variable input file missing"
    echo "Function display_usage(-) : WARNING: Pass text file as as argument which contains DB-name and DB password" | /usr/bin/tee -a $LOG
    echo -e "\nUsage: $0 [arguments] -\n" | /usr/bin/tee -a $LOG
}

function chk_usage(){
  if [ $argv -eq 1 ];
  then
      echo "Function chk_usage(+): the script executed with root equiv id and file argument provided" | /usr/bin/tee -a $LOG
      return $SUCCESS
  else
      exit 1
      return $FAIL 
  fi
}
###################################################################################################
## LOG file creation & Rotation 
## Check if existing log file present ?
## If yes, move the existing log with date timestamp
## create a new log file with date + time stamp comments 
#--------------------------------------------------------------------------------------------------
function log_create(){
  if [[ -f $LOG ]]
  then
      mv $LOG inst_tb-$dtime
      /usr/bin/touch $LOG
      echo "Function log_create(+): Thingsboard installation script executed at $dtime +" >> $LOG 
      echo "###########################################################" >> $LOG  
      return $SUCCESS
  else
      echo "ERROR: Function log_create(-): There is issue rotating/creating inst_tb.log, please check.." | /usr/bin/tee -a $LOG
      return $SUCCESS
  fi
}



####################################################################################################
# Main Function Starts Here 
####################################################################################################
log_create

if chk_usage
then
   misc
fi

os_update

if check_java
then
    java_install
    conf_java
fi

if chk_thingsboard_downloads
then
   download_thingsboard
fi

if chk_thingboard_installed
then
   install_thingsboard_service
fi

if chk_postgresql
then
   install_postgresql
fi

change_dbpasswd
dbcreate
conf_thingsboard
install_thingsboard 
start_thingsboard
