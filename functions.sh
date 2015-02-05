#!/bin/bash

# Post a json file to marathon cluster
post () {
    curl -X POST -H "Content-Type: application/json" http://$1:8080/v2/apps -d@$2
}