#!/bin/bash

sudo restart zookeeper
sudo service mesos-master restart
sudo service marathon restart