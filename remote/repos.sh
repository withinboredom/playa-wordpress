#!/bin/bash

if [ -f ~/packages ]
then
    exit 0
fi

sudo add-apt-repository ppa:webupd8team/java -y
echo debconf shared/accepted-oracle-license-v1-1 select true |
sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true |
sudo debconf-set-selections

echo "deb http://repos.mesosphere.io/ubuntu/ trusty main" |
sudo tee /etc/apt/sources.list.d/mesosphere.list
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

curl -sSL https://get.docker.com/ubuntu/ | sudo sh

sudo apt-get install -y python oracle-java7-installer curl unzip

sudo apt-get -y upgrade

touch ~/packages