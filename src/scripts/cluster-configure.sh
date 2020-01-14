#!/bin/bash

# License: https://github.com/influxdata/azure-resource-manager-influxdb-enterprise/blob/master/LICENSE
#
# Configure InfluxEnterprise from deployed ARM templates
# Initial Version
#

help()
{
    echo "This script finishes the InfluxEnterpise configuration for the ARM template image"
    echo "Parameters:"
    echo "-m  Metanode configuration"
    echo "-d  Datanode configuration"
    echo "-c  Cluster datanode count"
    echo "-h  view this help content"
}

#########################
# Logging func
#########################

# Custom logging with time so we can easily relate running times, also log to separate file so order is guaranteed.
# The Script extension output the stdout/err buffer in intervals with duplicates.

log()
{
     echo \[$(date +%d%m%Y-%H:%M:%S)\] "$1"
     echo \[$(date +%d%m%Y-%H:%M:%S)\] "$1" >> /var/log/cluster-configuration.log
}


log "Begin execution of Cluster Configuration script extension on ${HOSTNAME}"

if [ "${UID}" -ne 0 ];
then
    log "Script executed without root permissions"
    echo "You must be root to run this program." >&2
    exit 3
fi

#########################
# Configuration functions
#########################

setup_metanodes()
{

  # TEMP-SOLUTION: Hard coded privateIP's
  # Append metanode vm hostname  to the hsots file

  if [ -n "$(grep ${HOSTNAME} /etc/hosts)" ]
    then
      log "$HOSTNAME already exists : $(grep $HOSTNAME $ETC_HOSTS)"
    else
      log "Adding metanode-vm's to /etc/hosts"
      echo "10.0.0.10 metanode-vm0" >> /etc/hosts
      echo "10.0.0.11 metanode-vm1" >> /etc/hosts
      echo "10.0.0.12 metanode-vm2" >> /etc/hosts
      log "Metadata hostnames added to $ETC_HOSTS"
  fi
}

setup_datanodes()
{

  # TEMP-SOLUTION: Hard coded privateIP's
  # Append metanode vm hostname  to the hsots file

  if [ -n "$(grep ${HOSTNAME} /etc/hosts)" ]
    then
      log "$HOSTNAME already exists : $(grep $HOSTNAME $ETC_HOSTS)"
    else
      log "Adding metanode-vm's to /etc/hosts"
      echo "10.0.1.10 datanode-vm0" >> /etc/hosts
      echo "10.0.0.11 datanode-vm1" >> /etc/hosts
      echo "10.0.0.12 datanode-vm2" >> /etc/hosts
      log "Metadata hostnames added to $ETC_HOSTS"
  fi
}

setup_datanodes()
{

    # TEMP-SOLUTION: Hard coded privateIP's
    # Append metanode vm hostname  to the hsots file

    for i in $(seq 1 $DATANODE_COUNT); do 
      echo "10.0.1.${i} datanode-vm${i}" >> /etc/hosts
    done
}


configure_metanodes()
{

  #Generate and stage new configuration file
  log "Generating configuration file at ${CONFIG_FILE}"
  influxd-meta config > "${CONFIG_FILE}"

  if [ -f "${CONFIG_FILE}" ]; then
    log  "${CONFIG_FILE} file successfully generated"
    sed -i "s/\(hostname *= *\).*/\1\"$HOSTNAME\"/" "${CONFIG_FILE}"
    sed -i "s/\(license-key *= *\).*/\1\"$TEMP_LICENSE\"/" "${CONFIG_FILE}"
    sudo sed -i "s/\(dir *= *\).*/\1\"\/influxdb\/meta\"/" "${CONFIG_FILE}"


    # create working dirs for meatanode service
    mkdir -p "/influxdb/meta"
    chown -R influxdb:influxdb "/influxdb/"
    log "Metanode configuration file completed"

  else
     log  "Error creating file ${CONFIG_FILE} . You will need to manually configure the metanode."
     exit 1
  fi
}


start_systemd()
{
  if [ "${METANODE}" == 1 ]
  then
    log "[start_systemd] starting Metanode"
    sudo systemctl start influxdb-meta
    log "[start_systemd] started Metanode"
  else
    log "[start_systemd] starting Datanode"
    sudo systemctl start influxdb
    log "[start_systemd] started Datanode"
  fi
}


#Script Parameters
CONFIG_FILE=/etc/influxdb/influxdb-meta.conf
TEMP_LICENSE="d2951f76-a329-4bd9-b9bc-12984b897031"
ETC_HOSTS="/etc/hosts"
NODE_TYPE=`echo $HOSTNAME | awk '{print substr($0,0,8)}'`


#Loop through options passed
while getopts :m:d:h optname; do
  log "Option $optname set"
  case $optname in
    m)  #influxenterpise metanode configuration
      echo "set metanode..."
      METANODE="${OPTARG}"
      ;;
    d) #influxenterpise datanoe configuration
      DATANODE="${OPTARG}"
      ;;
    c) #influxenterpise datanode count
      COUNT="${OPTARG}"
      ;;
    h) #show help
      help
      exit 2
      ;;
    \?) #unrecognized option - show help
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      help
      exit 2
      ;;
  esac
done

# Install Oracle Java
install_java()
{
    log "Installing Java"
    add-apt-repository -y ppa:webupd8team/java
    apt-get -y update  > /dev/null
    echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
    echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
    apt-get -y install oracle-java8-installer

    log "Installed Java"
}

# Install Elasticsearch
install_es()
{
    # Elasticsearch 2.0.0 uses a different download path
    if [[ "${ES_VERSION}" == \2* ]]; then
        DOWNLOAD_URL="https://download.elasticsearch.org/elasticsearch/release/org/elasticsearch/distribution/deb/elasticsearch/$ES_VERSION/elasticsearch-$ES_VERSION.deb"
    else
        DOWNLOAD_URL="https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.deb"
    fi

    log "Installing Elaticsearch Version - $ES_VERSION"
    log "Download location - $DOWNLOAD_URL"
    sudo wget -q "$DOWNLOAD_URL" -O elasticsearch.deb
    sudo dpkg -i elasticsearch.deb
}

install_ntp()
{
    log "installing ntp deamon"
    apt-get -y install ntp
    #ntpdate pool.ntp.org
    log "installed ntp deamon and ntpdate"
}

# Primary Install Tasks
#########################

#install_ntp

#Format data disk (Find data disks then partition, format, and mount it
# as seperate drive under /influxdb/* )_
#------------------------
bash autopart.sh

if [ "${METANODE}" == 1 ];
then
    log "Script executing Metanode configuration"
    echo "Script executing Metanode configuration"
    configure_metanodes
else
    echo "Script executing Datanode configuration"

fi

#configure /etc/hosts file
#------------------------
setup_metanodes


#Start service process
#------------------------
start_systemd

PROC_CHECK=`ps aux | grep -v grep | grep influxdb`
if [ $? == 0 ]
then
    log "Service process started successfully"
else
    log "The Service process did not start, try running manually"
    exit 1
fi



#Install Oracle Java
#------------------------
#setup_hostnames

#Install Oracle Java
#------------------------
#install_java