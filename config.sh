#!/bin/bash

#Master IP Address
export SLAVE_INSTANCES=4
export MASTER_INSTANCES=3
export SSH_USER="vagrant"
export slaves=(10.0.0.10 10.0.0.11 10.0.0.12 10.0.0.13)
export masters=(10.0.0.4 10.0.0.5 10.0.0.6)

# remove these
#export INSTANCES=1
#export MASTER_COUNT=1
#export INSTALL_CHRONOS="n"
#export SSH_USER="vagrant"
#export nodes=(${HOST})
#export masters=($HOST)

source functions.sh