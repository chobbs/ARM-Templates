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
      log "hostname already exists : $(grep $HOSTNAME $ETC_HOSTS)"
    else
        log "Adding metanode-vm's to /etc/hosts"
        for i in $(seq 0 2); do 
          echo "10.0.0.1${i} metanode-vm${i}" >> /etc/hosts
        done        
  fi
}

setup_datanodes()
{
  # TEMP-SOLUTION: Hard coded privateIP's
  # Append metanode vm hostname  to the hsots file
  END=`expr ${COUNT} - 1`

  if [ -n "$(grep ${HOSTNAME} /etc/hosts)" ]
    then
      log "hostname already exists : $(grep $HOSTNAME $ETC_HOSTS)"
    else
        log "adding datanode-vm's to /etc/hosts"
        for i in $(seq 0 "${END}"); do 
          echo "10.0.1.1${i} datanode-vm${i}" >> /etc/hosts
        done        
  fi
}

join_cluster()
{
  #joining meatanodes . .
  log "[influxd-ctl add-meta] joing (3) metanodes to cluster"
  #for i in $(seq 0 2); do 
  #  influxd-ctl add-meta  "metanode-vm${i}:8091"
  #done   
}


configure_metanodes()
{
  #Generate and stage new configuration file
  log "[influxd-meta ] generating new metanode configuration file at ${META_GEN_FILE}"
  influxd-meta config > "${META_GEN_FILE}"

  if [ -f "${META_GEN_FILE}" ]; then
    log "successfully generating configuration file at ${META_GEN_FILE}"

    cp -p  "${META_GEN_FILE}" "${META_CONFIG_FILE}"
    if [ $? != 0 ]; then
       log "err: could not copy new "${META_CONFIG_FILE}" file to /etc/influxdb."
       exit 1
    fi
    
    # need to update the influxdb-meta.conf default values
    log  "[sed] updated ${META_CONFIG_FILE} default file values"

    chown influxdb:influxdb "${META_CONFIG_FILE}"
    sed -i "s/\(hostname *= *\).*/\1\"$HOSTNAME\"/" "${META_CONFIG_FILE}"
    sed -i "s/\(license-key *= *\).*/\1\"$TEMP_LICENSE\"/" "${META_CONFIG_FILE}"
    sed -i "s/\(dir *= *\).*/\1\"\/influxdb\/meta\"/" "${META_CONFIG_FILE}"


    # create working dir for meatanode service
    log "[mkdir] creating metanode directory structure"

    mkdir -p "/influxdb/meta"
    chown -R influxdb:influxdb "/influxdb/"

  else
     log  "err: creating file ${META_GEN_FILE}. you will need to manually configure the metanode."
     exit 1
  fi
}

configure_datanodes()
{
  #Generate and stage new configuration file
  log "[influxd] generating new datanode configuration file at ${DATA_GEN_FILE}"
  influxd config > "${DATA_GEN_FILE}"

  if [ -f "${DATA_GEN_FILE}" ]; then
    log "successfully generating configuration file at ${DATA_GEN_FILE}"

    cp -p  "${DATA_GEN_FILE}" "${DATA_CONFIG_FILE}"
    if [ $? != 0 ]; then
       log "err: could not copy new "${DATA_GEN_FILE}" file to file to /etc/influxdb."
       exit 1
    fi

    # need to update the influxdb.conf default values
    log  "[sed] updated ${META_CONFIG_FILE} default file values"

    chown influxdb:influxdb "${DATA_CONFIG_FILE}"
    sed -i "s/\(hostname *= *\).*/\1\"$HOSTNAME\"/" "${DATA_CONFIG_FILE}"
    sed -i "s/\(license-key *= *\).*/\1\"$TEMP_LICENSE\"/" "${DATA_CONFIG_FILE}"
    sed -i "s/\(auth-enabled *= *\).*/\1\"false\"/" "${DATA_CONFIG_FILE}"

    # create working dirs and file for datanode service
    log "[mkdir] creating datanode directory structure"

    mkdir -p "/influxdb/meta"
    mkdir -p "/influxdb/data"
    mkdir -p "/influxdb/wal"
    mkdir -p "/influxdb/hh"
    chown -R influxdb:influxdb "/influxdb/"

  else
     log  "err: creating file ${DATA_GEN_FILE}. you will need to manually configure the metanode."
     exit 1
  fi
}


start_systemd()
{
  if [ "${METANODE}" == 1 ]
  then
    log "[start_systemd] starting metanode"
    systemctl start influxdb-meta
  else
    log "[start_systemd] starting datanode"
    systemctl start influxdb
  fi
}


#Script Parameters
META_GEN_FILE="/etc/influxdb/influxdb-meta-generated.conf"
DATA_GEN_FILE="/etc/influxdb/influxdb-generated.conf"
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
log "[autopart] running auto partitioning & mounting"

bash autopart.sh


if [ "${JOIN}" == 1 ];
  then
    log "[join_funcs] executing cluster join commands on master metanode"

    join_cluster

    exit 0
fi

if [ "${METANODE}" == 1 ];
  then
    log "[metanode_funcs] executing metanode configuration functions"

    setup_metanodes

    configure_metanodes

  else
    log "[datanode_funcs] executing datanode configuration functions"
    
    setup_datanodes

    configure_datanodes
fi


#Start service process
#------------------------
start_systemd

PROC_CHECK=`ps aux | grep -v grep | grep influxdb`
if [ $? == 0 ]
  then
    log "[ps_aux] service process check, started successfully"
  else
    log "err: service process did not start, try running manually"
    exit 1
fi
