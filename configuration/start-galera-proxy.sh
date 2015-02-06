#!/bin/sh
consul-template -consul $HOST:8500 -template haproxy.ctmpl:/var/haproxy/haproxy.conf