#!/bin/bash

if type -P tput >/dev/null; then
  # font formatting
  reset=$(tput -T xterm sgr 0)
  underline=$(tput -T xterm sgr 0 1)./b
  bold=$(tput -T xterm bold)
  red=$(tput -T xterm setaf 1)
  yellow=$(tput -T xterm setaf 3)
  blue=$(tput -T xterm setaf 4)
  lightblue=$(tput -T xterm setaf 6)
else
  reset='';underline='';bold='';red='';
  yellow='';blue='';lightblue='';
fi

toUpper() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Post a json file to marathon cluster
post () {
    curl -X POST -H "Content-Type: application/json" http://$1:8080/v2/$3 \
    -d"$(perl -p -i -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' < $2)"

    echo "POSTed:"
    echo "$(perl -p -i -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' < $2)"
}

template () {
    perl -p -i -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg'
}

rem () {
    u=$1
    shift
    h=$1
    shift
    ssh $u@$h "$@"
}

rem_async() {
    u=$1
    shift
    h=$1
    shift
    ssh $u@$h "$@" &
}

zk_string () {
    exit=""

    if [ -z $1 ]
    then
        endpoint="/mesos"
    else
        endpoint=$1
    fi

    for node in "${masters[@]}"
    do
        if [ -z $exit ]
        then
            exit="zk://"
        else
            exit="${exit},"
        fi
        exit="${exit}${node}:2181"
    done

    exit="${exit}${endpoint}"

    zk_string=$exit
}

zk_conf () {
    exit=""

    c=1
    for node in "${masters[@]}"
    do
        exit="${exit}server.${c}=${node}:2888:3888 "
        c=$((c+1))
    done

    zk_conf_string=$exit
}