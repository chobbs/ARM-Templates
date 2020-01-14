#!/bin/bash

# License: https://github.com/influxdata/azure-resource-manager-influxdb-enterprise/blob/master/LICENSE
#
# Configure InfluxEnterprise from deployed ARM templates 
# Initial Version
#

help()
{
    echo "This script finishes the datanode configuration for the  InfluxEnterprise cluster on Ubuntu"
    echo "Parameters:"
    echo "-n influxenterprise cluster name"
    echo "-v influxenterprise version 1.5.0"

    echo "-d cluster uses dedicated metanodes"
    echo "-Z <number of nodes> hint to the install script how many data nodes we are provisioning"

    echo "-A admin password"
    echo "-R read password"
    echo "-K chronograf user password"
    echo "-S chronograf server password"

    echo "-x configure as a dedicated master node"
    echo "-y configure as client only node (no metanode, no data)"
    echo "-z configure as data node (no master)"
    echo "-l install plugins"

    echo "-m marvel host , used for agent config"

    echo "-h view this help content"
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

  grep -q "${HOSTNAME}" /etc/hosts
  if [ $? == 0 ]
  then
    echo "${HOSTNAME} found in /etc/hosts skip adding"
  else
    echo "Adding metanode-vm host in /etc/hosts"

    # TEMP-FIX: Hard coded privateIP's 
    # Append metanode vm hostname  to the hsots file
    echo "10.0.0.10 metanode-vm0" >> /etc/hosts
    echo "10.0.0.11 metanode-vm1" >> /etc/hosts
    echo "10.0.0.12 metanode-vm2" >> /etc/hosts

    log "hostnames added to /etc/hosts"
  fi
}


config_file()
{

  echo $HOSTNAME | awk '{print substr($0,0,8)}'
  if [ $? == datanode ]
  then
   #Generate new confige fiel
    influxd config > "${CONFIG_FILE}"
    sed -i "s/\(hostname *= *\).*/\1\"$HOSTNAME\"/" "${CONFIG_FILE}"
    sed -i "s/\(license-key *= *\).*/\1\"$TEMP_LICENSE\"/" "${CONFIG_FILE}"

    mkdir -p "/influxdb/data"
    mkdir -p "/influxdb/meta"
    mkdir -p "/influxdb/wal"
    chown -R influxdb:influxdb "/influxdb/"
    log "Configuration completed"
  fi
}


start_systemd()
{
    log "[start_systemd] starting Metanode"
    sudo systemctl start influxdb-meta
    log "[start_systemd] started Metanode"
}


#Script Parameters
CONFIG_FILE=/etc/influxdb/influxdb.generated.conf
TEMP_LICENSE="d2951f76-a329-4bd9-b9bc-12984b897031"

ES_VERSION="2.0.0"
INSTALL_PLUGINS=0
CLIENT_ONLY_NODE=0
DATA_NODE=0
MASTER_ONLY_NODE=0


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

install_ntp

#Format data disks (Find data disks then partition, format, and mount them as seperate drives)
# using the -s paramater causing disks under /datadisks/* to be raid0'ed
#------------------------
# bash vm-disk-utils-0.1.sh -s


#Install Oracle Java
#------------------------
setup_hostnames


#Install Oracle Java
#------------------------
#install_java

#
#Install Elasticsearch
#-----------------------
#install_es

# Prepare configuration information
# Configure permissions on data disks for elasticsearch user:group
#--------------------------
RAIDDISK="/datadisks/disk1"
DATAPATH_CONFIG="/datadisks/disk1/elasticsearch/data"

#setup_data_disk ${RAIDDISK}
