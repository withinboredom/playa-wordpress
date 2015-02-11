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
    shift
    type=$1
    shift
    num=$1
    shift
    script=$1
    shift

    if [ ! -f ${num}.provisioned ]
    then
        rem $SSH_USER $ip "rm -rf provisioning"
        rem $SSH_USER $ip "mkdir provisioning"
        scp -r ./* $SSH_USER@$ip:~/provisioning
        touch ${num}.provisioned
    fi

    if [ "$ASYNC" = true ]
    then
        echo "${red}ASYNC${reset}: ./${script} ${type} $ip ${num} $@"
        rem_async $SSH_USER $ip "cd provisioning && ./${script} ${type} $ip ${num} $@"
    else
        echo "${red}SYNC${reset}: ./${script} ${type} $ip ${num} $@"
        rem $SSH_USER $ip "cd provisioning && ./${script} ${type} $ip ${num} $@"
    fi
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

function do_masters () {
    #echo "${lightblue}Provisioning master nodes${reset}"

    counter=1
    script=$1
    shift
    for node in "${masters[@]}"
    do
        #echo "Provisioning master compute node"
        provision ${node} "master" ${counter} $script $@
        counter=$((counter+1))
    done
    wait
}

function do_slaves () {
    echo "${lightblue}Now, the slaves${reset}"
    script=$1
    shift
    count=$counter
    for node in "${slaves[@]}"
    do
        provision ${node} "slave" ${count} $script $@
        count=$((count+1))
    done
    wait
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
        --reset)
            rm *.provisioned
            do_masters "remote/reset.sh"
            do_slaves "remote/reset.sh"
            rm *.provisioned
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

if [ "$master" = true ]
then
    ASYNC=false
    do_masters "remote/repos.sh"
    ASYNC=true
    do_masters "remote/mesosphere.sh"
    zk_string "/mesos"
    do_masters "remote/zk.sh" "$zk_string"
    zk_conf
    do_masters "remote/zk_master_conf.sh"
    for item in ${zk_conf_string}
    do
        do_masters "remote/zk_master_cfg.sh" $item
    done
    do_masters "remote/quorum.sh" "$QUORUM"
    do_masters "remote/mesos_ip.sh"
    zk_string "/marathon"
    do_masters "remote/marathon.sh"
    do_masters "remote/marathon_zk.sh" "$zk_string"
    do_masters "remote/enable_docker.sh"
    do_masters "remote/set_cluster_name.sh" "SPHERE"
    do_masters "remote/start_master_services.sh"
    do_masters "remote/set_slave_ip.sh"
    do_masters "remote/add_attribute.sh" "slave-type" "master"
    sleep 3
    do_masters "remote/start_slave.sh"
fi

if [ "$slave" = true ]
then
    zk_string "/mesos"
    ASYNC=false
    do_slaves "remote/repos.sh"
    ASYNC=true
    do_slaves "remote/mesos.sh"
    do_slaves "remote/zk.sh" "$zk_string"
    do_slaves "remote/stop_zk.sh"
    do_slaves "remote/stop_mesos_master.sh"
    do_slaves "remote/set_slave_ip.sh"
    do_slaves "remote/enable_docker.sh"
    do_slaves "remote/add_attribute.sh" "slave-type" "slave"
    do_slaves "remote/start_slave.sh"
fi

echo "Finished provisioning machines, master-0 is ${masters[0]}"

MASTER=${masters[0]}

echo "${red}Waiting for mesos to come online${reset}"
sleep 10

post $MASTER services/infrastructure-group.json groups

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