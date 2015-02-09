#!/bin/bash

source config.sh

function keys() {
    ip=$1
    type=$2
    counter=$3

    scp ~/.ssh/id_rsa.pub ${SSH_USER}@${ip}:~/pub.key
    rem $SSH_USER $ip "cat ~/pub.key | tee -a ~/.ssh/authorized_keys"
}

function provision () {
    ip=$1
    type=$2
    counter=$3

    scp -r ./* $SSH_USER@$ip:~/provisioning
    rem $SSH_USER $ip "mkdir provisioning"
    sleep 1
    rem $SSH_USER $ip "cd provisioning && ./pre-provision.sh ${type} $ip ${counter}"
}

function do_keys () {
    for node in "${masters[@]}"
    do
        keys $node "master" 0
    done

    for node in "${slaves[@]}"
    do
        keys $node "slave" 0
    done
}

function do_zookeepers () {
    echo "${lightblue}Provisioning zookeeper nodes${reset}"
    counter=1
    for node in "${masters[@]}"
    do
        echo "${yellow}Starting provisioning of node: ${counter}${reset}"
        provision ${node} "zookeeper" ${counter}
        counter=$((counter+1))
    done
}

function do_masters () {
    echo "${lightblue}Provisioning master nodes${reset}"

    counter=1
    for node in "${masters[@]}"
    do
        echo "Provisioning master compute node"
        provision ${node} "master" ${counter}
        counter=$((counter+1))
    done
}

function do_slaves () {
    echo "${lightblue}Now, the slaves${reset}"
    for node in "${slaves[@]}"
    do
        provision ${node} "slave" ${counter}
        counter=$((counter+1))
    done
}

zoo=true
master=true
slave=true

while test $# -gt 0; do
    case "$1" in
        --no-zoo)
            zoo=false
            ;;
        --no-master)
            master=false
            ;;
        --no-slaves)
            slave=false
            ;;
        --keys-only)
            do_keys
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

if [ "$zoo" = true ]
then
    do_zookeepers
fi

if [ "$master" = true ]
then
    do_masters
fi

if [ "$slave" = true ]
then
    do_slaves
fi

echo "Finished provisioning machines, master-0 is ${masters[0]}"

MASTER=${masters[0]}

exit 0

if [ ! -z $INSTALL_CHRONOS ] && [ $INSTALL_CHRONOS = "y" ]
then
    echo "installing chronos on master"
    cronos="chronos-2.1.0_mesos-0.14.0-rc4"
    for node in "${masters[@]}"
    do
        rem $SSH_USER $node "sudo apt-get install -y at"
        echo
        echo "Installing chronos on node $node"
        rem $SSH_USER $node "if [ ! -f chronos-2.1.0_mesos-0.14.0-rc4.tgz ]; then curl -sSfL http://downloads.mesosphere.io/chronos/${cronos}.tgz --output ${chronos}.tgz && tar xzf ${chronos}.tgz; fi"
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

echo "Waiting for consul to come online"
sleep 60

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
    rem $SSH_USER $node "echo 'HOST=$HOST ./galera-start.sh' | sudo at now"
done

#post $HOST configurat