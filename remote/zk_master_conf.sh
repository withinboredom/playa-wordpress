#!/bin/bash

echo "$3" |
sudo tee /etc/zookeeper/conf/myid

if [ -f /etc/zookeeper/conf/zoo.cfg.orig ]
then
    sudo cp /etc/zookeeper/conf/zoo.cfg.orig /etc/zookeeper/conf/zoo.cfg
else
    sudo cp /etc/zookeeper/conf/zoo.cfg /etc/zookeeper/conf/zoo.cfg.orig
fi