#!/bin/bash

# Do testing here and print usage

source config.sh

INSTANCES=1

post $HOST configuration/enable-docker.json

wget https://github.com/hashicorp/consul-template/releases/download/v0.6.5/consul-template_0.6.5_linux_amd64.tar.gz
tar -xzvf consul-template_0.6.5_linux_amd64.tar.gz