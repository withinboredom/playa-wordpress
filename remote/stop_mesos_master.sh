#!/bin/bash

echo manual | sudo tee /etc/init/mesos-master.override
sudo stop mesos-master