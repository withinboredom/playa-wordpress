#!/bin/bash

echo "docker,mesos" |
sudo tee /etc/mesos-slave/containerizers

echo "5mins" |
sudo tee /etc/mesos-slave/executor_registration_timeout