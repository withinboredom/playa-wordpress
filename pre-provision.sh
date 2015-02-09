#!/bin/bash

source config.sh

zk=false

if [ $1 == "master" ]
then
    master=true
elif [ $1 == "slave" ]
then
    master=false
elif [ $1 == "zookeeper" ]
then
    master=true
    zk=true
else
    echo "Usage: ./pre-configure [master|slave] [ip-address] [node-number]"
    exit 1
fi

ip=$2
node_num=$3

echo "${yellow}Provisioning node ${node_num}${reset}"

function apt_ () {
    as_root env DEBIAN_FRONTEND=noninteractive apt-get "$@"
}

function as_root () {
    if [[ $(id -u) = 0 ]]
        then "$@"
    else sudo "$@"
    fi
}
function install_sources {
    #as_root apt-get install python-software-properties
    as_root add-apt-repository ppa:webupd8team/java -y
    echo debconf shared/accepted-oracle-license-v1-1 select true |
    as_root debconf-set-selections
    echo debconf shared/accepted-oracle-license-v1-1 seen true |
    as_root debconf-set-selections

    echo "deb http://repos.mesosphere.io/ubuntu/ trusty main" |
    as_root tee /etc/apt/sources.list.d/mesosphere.list
    as_root apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

    curl -sSL https://get.docker.com/ubuntu/ | as_root sh

    as_root apt-get install -y python oracle-java7-installer curl unzip
}

function install_common_deps () {
    apt_ update
    apt_ upgrade -y
    install_sources
}

function install_slave_deps () {
    apt_ install -y mesos
}

function install_master_deps () {
    apt_ install -y mesosphere
}

function configure_zk () {
    zk_string
    echo $zk_string |
    as_root tee /etc/mesos/zk

    if [ "$master" = true ]
    then
        echo $node_num |
        as_root tee /etc/zookeeper/conf/myid

        counter=1
        for node in "${masters[@]}"
        do
            if [ -f /etc/zookeeper/conf/zoo.cfg.orig ]
            then
                as_root cp /etc/zookeeper/conf/zoo.cfg.orig /etc/zookeeper/conf/zoo.cfg
            else
                as_root cp /etc/zookeeper/conf/zoo.cfg /etc/zookeeper/conf/zoo.cfg.orig
            fi

            echo "server.${counter}=${node}:2888:3888" |
            as_root tee -a /etc/zookeeper/conf/zoo.cfg

            counter=$((counter+1))
        done

        as_root restart zookeeper
        sleep 2
    fi
}

function configure_cluster () {
    #todo: calculate correct quorum

    echo "2" |
    as_root tee /etc/mesos-master/quorum

    echo "SPHERE Cluster" |
    as_root tee /etc/mesos-master/cluster

    echo "$ip" |
    as_root tee /etc/mesos-master/ip

    as_root cp /etc/mesos-master/ip /etc/mesos-master/hostname
}

function configure_marathon () {
    as_root mkdir -p /etc/marathon/conf
    as_root cp /etc/mesos-master/hostname /etc/marathon/conf
    as_root cp /etc/mesos/zk /etc/marathon/conf/master
    zk_string "/marathon"
    echo $zk_string |
    as_root tee /etc/marathon/conf/zk
}

function start_services () {
    as_root stop mesos-slave
    sleep 1
    as_root start mesos-master
    sleep 2
    as_root start marathon
}

function configure_slave_services () {
    as_root stop zookeeper
    echo manual |
    as_root tee /etc/init/zookeeper.override

    echo manual |
    as_root tee /etc/init/mesos-master.override
    as_root stop mesos-master
}

function configure_slave_ip () {
    echo "${ip}" |
    as_root tee /etc/mesos-slave/ip
    as_root cp /etc/mesos-slave/ip /etc/mesos-slave/hostname
}

function start_slave () {
    as_root start mesos-slave
    sleep 2
}

function configure_docker () {
    echo "docker,mesos" |
    as_root tee /etc/mesos-slave/containerizers

    echo "5mins" |
    as_root tee /etc/mesos-slave/executor_registration_timeout
}

function add_attribute () {
    key=$1
    value=$2

    if [ ! -d /etc/mesos-slave/attributes ]
    then
        as_root mkdir /etc/mesos-slave/attributes
    fi

    echo "${value}" |
    as_root tee /etc/mesos-slave/attributes/${key}
}

echo "${lightblue}Installing common dependencies for ${1} node${reset}"

if [ "$zk" = true ]
then
    install_common_deps
fi

if [ "$master" = true ]
then
    if [ "$zk" = true ]
    then
        echo "${lightblue}Installing dependencies for ${1} node${reset}"
        install_master_deps
        echo "${lightblue}Configuring ${reset}${red}zookeeper${reset}${lightblue} for ${1} node${reset}"
        configure_zk
        exit 0
    fi
    echo "${lightblue}Configuring ${reset}${red}cluster${reset}${lightblue} for ${1} node${reset}"
    configure_cluster
    echo "${lightblue}Configuring ${reset}${red}marathon${reset}${lightblue} for ${1} node${reset}"
    configure_marathon
    configure_docker
    echo "${red}Starting master services for ${1} node${reset}"
    start_services
    echo "${lightblue}Configuring ${reset}${red}slave ip${reset}${lightblue} for ${1} node${reset}"
    configure_slave_ip
    echo "${lightblue}Setting slave type for ${1} node${reset}"
    add_attribute "slave-type" "master"
    echo "${lightblue}Starting ${reset}${red}slave${reset}${lightblue} for ${1} node${reset}"
    start_slave
else
    install_common_deps
    install_slave_deps
    echo "${lightblue}Configuring ${reset}${red}zookeeper${reset}${lightblue} for ${1} node${reset}"
    configure_zk
    echo "${lightblue}Configuring ${reset}${red}slave services${reset}${lightblue} for ${1} node${reset}"
    configure_slave_services
    echo "${lightblue}Configuring ${reset}${red}slave ip${reset}${lightblue} for ${1} node${reset}"
    configure_slave_ip
    configure_docker
    echo "${lightblue}Setting slave type for ${1} node${reset}"
    add_attribute "slave-type" "slave"
    echo "${lightblue}Starting ${reset}${red}slave${reset}${lightblue} for ${1} node${reset}"
    start_slave
fi