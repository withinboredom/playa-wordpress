#!/bin/bash

echo "Configuring Consul"

source config.sh

post $HOST consul-master.json
post $HOST consul-slave.json

echo "