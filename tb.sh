#!/usr/bin/bash

#Global Variables
source $1
dtime=`date +%d-%m-%y-%H-%M`
echo $dtime
pd=`pwd`
argc=`echo $#`
input_file=$1


# General Purpose Function
#-------------------------

function clear_screen(){
    clear
}

function package_install(){
    echo "Function package_install(+): Package $1 is getting installed" | /usr/bin/tee -a $LOG
    yes Y | apt-get install $1
    if [[ $? -ne 0 ]]
    then
        echo "Function package_install(-): Package $1 failed to install" | /usr/bin/tee -a $LOG
        exit 1 
    fi
}

function service_start(){
    echo "Function service_start(+): $1 getting started" | /usr/bin/tee -a $LOG
    /usr/sbin/service $1 start
    if [[ $? -ne 0 ]]
    then
         echo "Function service_start(+): $1 started"  | /usr/bin/tee -a $LOG 
    fi 
}


function systemctl_start(){
    echo "Function systemctl_start(+): $1 getting started" | /usr/bin/tee -a $LOG
    /usr/bin/systemctl start $1
    if [[ $? -ne 0 ]]
    then
         echo "Function systemctl_start(-): $1 NOT started"  | /usr/bin/tee -a $LOG 
    fi 
}

function enable_service(){
   echo "Function enable_service(+): $1 service is getting enabled" | /usr/bin/tee -a $LOG 
   /usr/bin/systemctl enable $1
    if [[ $? -ne 0 ]]
    then
         echo "Function enable_service(-): $1 NOT enabled"  | /usr/bin/tee -a $LOG 
    fi 
}
   
function get_file(){
    download_file=`/usr/bin/basename $1`
    if [[ ! -f $download_file ]] 
    then
        echo "Function wget(+): Package $download_file is getting downloaded" | /usr/bin/tee -a $LOG
        wget $1
        if [[ $? -ne 0 ]]
        then
            echo "Function wget(-): Package $download_file download failed" | /usr/bin/tee -a $LOG
        fi
    else
        echo "Function wget(+): Package $download_file already found, skipping download" | /usr/bin/tee -a $LOG
    fi
}


function log_create(){
    LOG=$pd/logs/inst_tb.log 
    if [[ -f $LOG ]]
    then
            mv $LOG $pd/logs/inst_tb-${dtime}
            /usr/bin/touch $LOG
            echo "Function log_create(+): Thingsboard installation script executed at $dtime" | /usr/bin/tee -a $LOG
    else
            echo "ERROR: Function log_create(-): There is issue rotating/creating inst_tb.log, please check.." | /usr/bin/tee -a $LOG
    fi
}


function check_usage(){
    if [[ $argc -ne "1" ]];
    then
        echo "Error: Function check_usage(-): Ensure Input file is provided" | /usr/bin/tee -a $LOG
        exit 1
    elif [[ "$UID" -ne 0 ]];
    then
        echo "Error: Function check_usage(-): Ensure you logged-in as root or root equiv ID " | /usr/bin/tee -a $LOG
    else
        source $input_file
    fi
}


function display_exists_sw(){
    IS_TB=`dpkg -s thingsboard | grep -i ^Version |awk '{print $2}'`
    IS_JAVA=`apt list --installed |grep -i openjdk|head -1|awk '{print $1}'`
    IS_KAFKA=`/usr/local/kafka/bin/kafka-topics.sh --version |awk '{print $1}'`
    IS_DB=`apt list --installed | grep -i postgresql|head -1| cut -d'/' -f1`
   
    /usr/bin/echo $IS_JAVA | grep -i $JAVA
    JAVA_STATUS=$?
    /usr/bin/echo $IS_TB| grep -i $TB_VER 
    TB_STATUS=$?
    /usr/bin/echo $IS_DB| grep -i $DB
    DB_STATUS=$?
    /usr/bin/echo $IS_KAFKA | grep -i $KAFKA_VER
    KAFKA_STATUS=$?
    echo $JAVA_STATUS 
    echo $TB_STATUS
    echo $DB_STATUS
    echo $KAFKA_STATUS

    
  
}

function check_all_exists(){
    java -version
    IS_JAVA=`echo $?` 
    dpkg -s thingsboard
    IS_TB=`echo $?`
    ls -ld /usr/local/kafka
    IS_KAFKA=`echo $?`
    ls -ld /etc/systemd/system/zookeeper.service
    IS_ZOOKEEPER=`echo $?` 
    if [[ "$IS_JAVA" -eq 0 ]] | [[ "$IS_TB" -eq 0 ]] | [[ "$IS_ZOOKEEPER" -eq 0 ]] | [[ "$IS_KAFKA" -eq 0 ]] 
    then
       echo "Function check_all_exists(-): Existing version of s/w(JAVA,TB,KAFKA,ZOOKEEPER) found" | /usr/bin/tee -a $LOG
    else
       echo "Function check_all_exists(+) No Existing s/w (JAVA,TB,KAFKA,ZOOKEEPER) installation found" | /usr/bin/tee -a $LOG
    fi 
}



function os_pre-requisities(){
    echo "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> /root/.bashrc
    . /root/.bashrc
    
    source_list="/etc/apt/sources.list.d/addsource.list"

    #Entries to be appended to source.list file 
    line1='deb http://deb.debian.org/debian bullseye main'
    line2='deb-src http://deb.debian.org/debian bullseye main'
    line3='deb http://security.debian.org/debian-security bullseye-security main'
    line4='deb-src http://security.debian.org/debian-security bullseye-security main'
    line5='deb http://deb.debian.org/debian bullseye-updates main'
    line6='deb-src http://deb.debian.org/debian bullseye-updates main'
    line7='deb http://deb.debian.org/debian bullseye-backports main'
    line8='deb-src http://deb.debian.org/debian bullseye-backports main'
    #NOTE: If the number of lines increased or decresed remember to update above 
  
    #Entries to be removed from sources.list 
    sed -e '/deb cdrom/ s/^#*/#/' -i /etc/apt/sources.list

    #Check if the line is already present, if not append the file 
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

    #Check the first file existence and confirm the activity is success 
    /usr/bin/grep -i "${line1}" $source_list
    if [[ $? -eq 0 ]]
    then
        echo "Function os_pre-requisities(+): line variables are updated to the /etc/apt/source.list.d/<file> +" | /usr/bin/tee -a $LOG
    else
        echo "ERROR: Function os_pre-requisities(-): unable to update source list, please check.." | /usr/bin/tee -a $LOG
        exit 1
    fi
}

function os_update(){
    if { apt update 2>&1 || echo E: update failed; } | grep -q '^[WE]:';then
        echo "Function os_update(+): OS updated Successfully" |/usr/bin/tee -a $LOG;
        rm -rf /etc/apt/sources.list.d/addsource.list;
    else
        rm -rf /etc/apt/sources.list.d/addsource.list;
        echo "ERROR: Function os_update(-): OS Update Failed, please check.." | /usr/bin/tee -a $LOG
        exit 1
    fi
}

function configure_java(){
    /usr/bin/update-alternatives --config java 
    if [[ $? -eq 0 ]]
    then
        echo "Function confgure_java(+): Java configuration success" | /usr/bin/tee -a $LOG
    else
        echo "ERROR: Function confgure_java(-):installables already found" | /usr/bin/tee -a $LOG
        exit 1
    fi
}


#THINGSBOARD INSTALLATION

function install_thingsboard(){
    echo "Function install_thingsboard(+):Thingsboard installation begins" | /usr/bin/tee -a $LOG
    /usr/bin/dpkg -i ${TB}
    if [[ $? -ne 0 ]]
    then
        echo "Function install_thingsboard(-):Thingsboard installation Failed " |/usr/bin/tee -a $LOG
        exit 1
    fi
}

#POSTGRESQL INSTALLATION

function postgresql_pre-requisities(){
    #Import the repository signing key

    /usr/bin/wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

    #Add repository contents to your system:
    RELEASE=$(lsb_release -cs)
  
    echo "deb http://apt.postgresql.org/pub/repos/apt/ ${RELEASE}"-pgdg main | /usr/bin/tee /etc/apt/sources.list.d/pgdg.list
 
    #updating LOGS
    echo "Function postgresql_pre-requisties(+): Pre-req files are downloaded and repo added:" | tee -a $LOG 
}  


function change_dbpasswd(){
    echo "Function change_dbpasswd(+): Postgres passwd change in progress" | /usr/bin/tee -a $LOG
    su - postgres -c "psql -U postgres -d postgres -c \"alter user postgres with password '${DBPASSWD}';\""
  if [[ $? -ne 0 ]]
  then
      echo "ERROR: Function change_dbpasswd(-): unable to set password of  $DBNAME, please check" | /usr/bin/tee -a $LOG
      exit 1
  fi
}

function dbcreate(){
    echo "Function dbcreate(+):DB named ${DBNAME} creation in progress" | /usr/bin/tee -a $LOG
    su - postgres -c "psql -U postgres -d postgres -c \"create database ${DBNAME};\""
    if [[ $? -ne 0 ]]
    then
        echo "ERROR: dbcreate(-): unable to create db $DBNAME, please check" | /usr/bin/tee -a $LOG
        exit 1
    fi
}

function edit_tb_conf(){
    tb_conf="/etc/thingsboard/conf/thingsboard.conf"

    echo "Function conf_thingsboard(+):Configuration entried are getting added to $tb_conf" | /usr/bin/tee -a $LOG
    #Entries to be appended to the thingsboard configuration file
    conf_line1='export DATABASE_TS_TYPE=sql'
    conf_line2='export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/${DBNAME}'
    conf_line3='export SPRING_DATASOURCE_USERNAME=postgres'
    conf_line4="export SPRING_DATASOURCE_PASSWORD=${DBPASSWD}"
    conf_line5='export SQL_POSTGRES_TS_KV_PARTITIONING=MONTHS'
    #NOTE: If the number of lines increased or decresed remember to update 

    echo "#----this line is added from thingsboard installation script----#" >> $tb_conf
    /usr/bin/grep -qxF -- "$conf_line1" $tb_conf || echo "$conf_line1" >> $tb_conf
    /usr/bin/grep -qxF -- "$conf_line2" $tb_conf || echo "$conf_line2" >> $tb_conf
    /usr/bin/grep -qxF -- "$conf_line3" $tb_conf || echo "$conf_line3" >> $tb_conf
    /usr/bin/grep -qxF -- "$conf_line4" $tb_conf || echo "$conf_line4" >> $tb_conf
    /usr/bin/grep -qxF -- "$conf_line5" $tb_conf || echo "$conf_line5" >> $tb_conf
    echo "#-----------------------------------------------------------------#" >> $tb_conf

    #check if the 1st line present in $tb_conf 
    /usr/bin/grep -i "${conf_line1}" $tb_conf
    if [[ $? -ne 0 ]]
    then
        echo "ERROR: edit_tb_conf(-): thingsboard configuration failed, please check" | /usr/bin/tee -a $LOG
        exit 1
    fi
}

#KAFKA INSTALLATION
 
function install_kafka(){
    echo "Function install_kafka(+): Kafka installation begins" | /usr/bin/tee -a $LOG
    if [[ -f ${KAFKA}.tgz ]]
    then
         tar -xvf ${KAFKA}.tgz
         if [[ $? -eq 0 ]]
         then
            /usr/bin/mv ${KAFKA} /usr/local/kafka 
            echo "Function install_kafka(+): Kafka installation completed" | /usr/bin/tee -a $LOG
         else 
           echo "Function install_kafka(-): Kafka installation failed" | /usr/bin/tee -a $LOG
           exit 1
         fi
    else 
         echo "Function install_kafka(-): Kafka installables not found" | /usr/bin/tee -a $LOG
    fi
}

function append_conf_files(){
    echo "Function append_conf_files(+): content $1 is getting copied to file $2" | /usr/bin/tee -a $LOG
    IFS=$'\n' 
    /usr/bin/cat $1 | while read line;
    do
        /usr/bin/grep -qxF -- "$line" $2 || echo "$line" >> $2
    done 
    if [[ $? -ne 0 ]]
    then
        echo "Function append_conf_files(-): content $1 NOT copied to file $2" | /usr/bin/tee -a $LOG
    fi
}

function house_keeping(){
    rm -rf /etc/apt/sources.list.d/addsource.list
    rm -rf /etc/apt/sources.list.d/pgdg.list
    rm -rf $pd/${KAFKA}
    rm -rf $pd/${KAFKA}.tgz
    rm -rf $TB
}


function less_mem_system(){
    TOTAL_MEM=`free -m |grep -i mem|awk '{print $2}'`
    if [[ TOTAL_MEM < 1000 ]]
    then
        echo 'export JAVA_OPTS="$JAVA_OPTS -Xms256M -Xmx256M"' >> $THINGSBOARD_CONF  
        echo "Function less_mem_system(+):Total Memory less than 1 GB, performance tuned" | /usr/bin/tee -a $LOG
    fi
}

function run_tb_install(){
        echo "Function run_tb_install(+):Thingsboard Install script begins" | /usr/bin/tee -a $LOG
        cd /usr/share/thingsboard/bin/install/ && ./install.sh 
        if [[ $? -ne 0 ]]
        then
            echo "Function run_tb_install(-): Thingsboard Install script not working" | /usr/bin/tee -a $LOG
            exit 1
        fi
}
    


#Downloadables
THINGSBOARD_INSTALLABLES="https://github.com/thingsboard/thingsboard/releases/download/v${TB_VER}/${TB}"
KAFKA_INSTALLABLES="https://archive.apache.org/dist/kafka/${KAFKA_VER}/${KAFKA}.tgz"


#config files & content files
ZOOKEEPER_CONF="/etc/systemd/system/zookeeper.service"
KAFKA_CONF="/etc/systemd/system/kafka.service"
THINGSBOARD_CONF="/etc/thingsboard/conf/thingsboard.conf"

ZOOKEEPER_CONTENT="$pd/conf/zookeeper.content"
KAFKA_CONTENT="$pd/conf/kafka.content"
THINGSBOARD_CONTENT="$pd/conf/thingsboard.content"

#Main function starts here

log_create
check_usage
check_all_exists
clear_screen
display_exists_sw
#house_keeping
os_pre-requisities
os_update
package_install $JAVA
configure_java

package_install wget
get_file $THINGSBOARD_INSTALLABLES
install_thingsboard

postgresql_pre-requisities
os_pre-requisities
os_update
package_install $DB
service_start postgresql
change_dbpasswd
dbcreate $DBNAME
edit_tb_conf

install $ZOOKEEPER
get_file $KAFKA_INSTALLABLES
install_kafka
append_conf_files $ZOOKEEPER_CONTENT $ZOOKEEPER_CONF
append_conf_files $KAFKA_CONTENT $KAFKA_CONF
enable_service zookeeper
enable_service kafka
systemctl_start zookeeper
systemctl_Start kafka
house_keeping
append_conf_files $THINGSBOARD_CONTENT $THINGSBOARD_CONF

less_mem_system
run_tb_install
service_start thingsboard

