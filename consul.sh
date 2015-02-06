#!/bin/bash

source config.sh

post $HOST consul-master.json
post $HOST consul-slave.json