#!/bin/bash

sudo stop zookeeper
echo manual | sudo tee /etc/init/zookeeper.override