#!/bin/bash

#Master IP Address
export HOST=10.141.141.10
export INSTANCES=1
export MASTER_COUNT=1
export INSTALL_CHRONOS="n"
export SSH_USER="vagrant"
export nodes=(${HOST})
export masters=($HOST)

source functions.sh