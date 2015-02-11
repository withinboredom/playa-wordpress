#!/bin/bash

key="$4"
value="$5"

if [ ! -d /etc/mesos-slave/attributes ]
then
    sudo mkdir /etc/mesos-slave/attributes
fi

echo "${value}" |
sudo tee /etc/mesos-slave/attributes/${key}