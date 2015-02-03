#!/bin/bash

sudo apt-get update
sudo apt-get install -y realpath unzip

if [[ ! -f ${HOME}/.rvm/bin/rvm ]]; then
	sudo apt-get install -y curl
	gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
	curl -sSL https://get.rvm.io | bash -s stable
fi

source /home/vagrant/.rvm/scripts/rvm
rvm use --install 1.9.3
rvm alias create default 1.9.3

gem install rubyzip

sudo mkdir /app
sudo chown vagrant:vagrant /app
