#!/bin/sh
./consul-template -consul $HOST:8500 -template galera-haproxy.ctmpl:/var/haproxy/haproxy.conf