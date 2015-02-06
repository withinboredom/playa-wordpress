#!/bin/bash

source config.sh

if [ ! -z $INSTALL_CHRONOS ] && [ $INSTALL_CHRONOS = "y" ]
then
    echo "installing chronos on master"
    cronos="chronos-2.1.0_mesos-0.14.0-rc4"
    for node in "${masters[@]}"
    do
        rem $SSH_USER $node "sudo apt-get install -y at"
        rem $SSH_USER $node "if [ ! -f chronos-2.1.0_mesos-0.14.0-rc4.tgz ]; then wget http://downloads.mesosphere.io/chronos/${cronos}.tgz;  tar xzf ${cronos}.tgz; fi"
        rem $SSH_USER $node "echo 'cd ${chronos}; ./bin/start-chronos.bash --master zk://localhost:2181/mesos --zk_hosts zk://localhost:2181/mesos --http_port 8081' > start-chronos.sh"
        rem $SSH_USER $node "chmod +x start-chronos.sh; at now -f start-chronos.sh"
    done
    echo "Chronos is running at http://$HOST:8081"
fi

echo "configuring $INSTANCES nodes"

echo "Enabling docker"

for node in "${nodes[@]}"
do
    rem ${SSH_USER} $node "sudo sh -c \"echo 'docker,mesos' > /etc/mesos-slave/containerizers\"; sudo sh -c \"echo '5mins' > /etc/mesos-slave/executor_registration_timeout\"; sudo service mesos-slave restart"
done

echo "Installing consul"

post $HOST services/consul-master.json

echo "Setting master consul to: "
masterConsul=$node
echo $masterConsul

if [ $INSTANCES -lt 2 ]
then
    echo "Starting consul in single mode"
    post $HOST services/consul-slave.json
else
    consulJoinTrigger="true"
fi

#TODO: Detect when consul comes online and join slaves to master

echo "Installing registrar"

post $HOST services/registrator.json

echo "Installing consul-templates"

for node in "${masters[@]}"
do
    consulTemplateFile="consul-template_0.6.5_linux_amd64"
    rem $SSH_USER $node "sudo apt-get install -y haproxy"
    rem $SSH_USER $node "if [ ! -f ${consulTemplateFile}.tar.gz ]; then wget https://github.com/hashicorp/consul-template/releases/download/v0.6.5/${consulTemplateFile}.tar.gz; fi"
    rem $SSH_USER $node "tar -xzvf ${consulTemplateFile}.tar.gz"
    scp configuration/galera-haproxy.ctmpl $SSH_USER@$node:galera-haproxy.ctmpl
    scp configuration/start-galera-proxy.sh $SSH_USER@$node:galera-start.sh
    rem $SSH_USER $node "cp ${consulTemplateFile}/consul-template . && chmod +x galera-start.sh"
    rem $SSH_USER $node "sudo sh -c 'at now < \"HOST=$HOST galera-start.sh\"'"
done

#post $HOST configuration/enable-docker.json