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
    echo "-j  Join cluster nodes"
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
        for i in $(seq 0 2); do 
          echo "10.0.0.1${i} metanode-vm${i}" >> /etc/hosts
        done        
      log "Datanodes hostnames added to ${ETC_HOSTS}"
  fi
}

setup_datanodes()
{
  # TEMP-SOLUTION: Hard coded privateIP's
  # Append metanode vm hostname  to the hsots file
  END=`expr ${COUNT} - 1`

  if [ -n "$(grep ${HOSTNAME} /etc/hosts)" ]
    then
      log "$HOSTNAME already exists : $(grep $HOSTNAME $ETC_HOSTS)"
    else
        log "Adding datanode-vm's to /etc/hosts"
        for i in $(seq 0 "${END}"); do 
          echo "10.0.1.1${i} datanode-vm${i}" >> /etc/hosts
        done        
      log "Datanodes hostnames added to ${ETC_HOSTS}"
  fi
}


configure_metanodes()
{
  #Generate and stage new configuration file
  log "Generating metanode configuration file at ${META_CONFIG_FILE}"
  influxd-meta config > "${META_CONFIG_FILE}"

  if [ -f "${META_CONFIG_FILE}" ]; then
    log  "${META_CONFIG_FILE} file successfully generated"
    sed -i "s/\(hostname *= *\).*/\1\"$HOSTNAME\"/" "${META_CONFIG_FILE}"
    sed -i "s/\(license-key *= *\).*/\1\"$TEMP_LICENSE\"/" "${META_CONFIG_FILE}"
    sudo sed -i "s/\(dir *= *\).*/\1\"\/influxdb\/meta\"/" "${META_CONFIG_FILE}"


    # create working dir for meatanode service
    mkdir -p "/influxdb/meta"
    chown -R influxdb:influxdb "/influxdb/"
    log "Metanode directory structure configured"

  else
     log  "Error creating file ${META_CONFIG_FILE} . You will need to manually configure the metanode."
     exit 1
  fi
}

configure_datanodes()
{
  #Generate and stage new configuration file
  log "Generating datanode configuration file at ${DATA_CONFIG_FILE}"
  influxd config > "${DATA_CONFIG_FILE}"

  if [ -f "${DATA_CONFIG_FILE}" ]; then
    log  "${DATA_CONFIG_FILE} file successfully generated"
    chown -R influxdb:influxdb "${DATA_CONFIG_FILE}"

    sed -i "s/\(hostname *= *\).*/\1\"$HOSTNAME\"/" "${DATA_CONFIG_FILE}"
    sed -i "s/\(license-key *= *\).*/\1\"$TEMP_LICENSE\"/" "${DATA_CONFIG_FILE}"
    #sudo sed -i "s/\(dir *= *\).*/\1\"\/influxdb\/meta\"/" "${DATA_CONFIG_FILE}"

    # create working dirs for datanode service
    mkdir -p "/influxdb/meta"
    mkdir -p "/influxdb/data"
    mkdir -p "/influxdb/wal"
    mkdir -p "/influxdb/hh"
    chown -R influxdb:influxdb "/influxdb/"
    log "Datanode directory structure configured"

  else
     log  "Error creating file ${DATA_CONFIG_FILE} . You will need to manually configure the metanode."
     exit 1
  fi
}


start_systemd()
{
  if [ "${METANODE}" == 1 ]
  then
    log "[start_systemd] starting Metanode"
    systemctl start influxdb-meta
  else
    log "[start_systemd] starting Datanode"
    systemctl start influxdb
  fi
}


#Script Parameters
META_CONFIG_FILE="/etc/influxdb/influxdb-meta.conf"
DATA_CONFIG_FILE="/etc/influxdb/influxdb.conf"
TEMP_LICENSE="d2951f76-a329-4bd9-b9bc-12984b897031"
ETC_HOSTS="/etc/hosts"


#Loop through options passed
while getopts :m:d:c:j:h optname; do
  log "Option $optname set"
  case $optname in
    m)  #configure metanode 
      METANODE="${OPTARG}"
      ;;
    d) #configure datanoe 
      DATANODE="${OPTARG}"
      ;;
    c) # datanode count
      COUNT="${OPTARG}"
      ;;
    j) # join cluster
      JOIN="${OPTARG}"
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
log "Running autopat.sh script"

bash autopart.sh


if [ "${METANODE}" == 1 ];
  then
    log "Executing Metanode configuration functions"

    setup_metanodes

    configure_metanodes

  else
    log "Executing Datanode configuration functions"
    
    setup_datanodes

    configure_datanodes
fi


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
