#!/bin/bash

# Post a json file to marathon cluster
post () {
    curl -X POST -H "Content-Type: application/json" http://$1:8080/v2/apps -d"$(perl -p -i -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' < $2)" > $2.log
}

template () {
    perl -p -i -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' < $2
}

rem () {
    ssh $1@$2 $3
}