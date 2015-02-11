#!/bin/bash

sudo apt-get update
sudo apt-get install -y curl realpath sysvbanner unzip

mkdir /app
chown vagrant:vagrant /app

cat >/home/vagrant/.bash_1st_time <<EOT
#!/bin/bash

set -e

cd /vagrant/vagrant/run
ln -s detect compile
ln -s detect release

banner Installing rvm
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -sSL https://get.rvm.io | bash -s stable

banner Installing ruby 1.9.3
source /home/vagrant/.rvm/scripts/rvm
rvm use --install 1.9.3
rvm alias create default 1.9.3
EOT

cat >>/home/vagrant/.bash_profile <<EOT1

FIRST_RUN_SCRIPT=\${HOME}/.bash_1st_time
if [[ -f \${FIRST_RUN_SCRIPT} ]]; then
	bash \${FIRST_RUN_SCRIPT}
	if [[ \$? -eq 0 ]]; then
		banner "Done"
		source \${HOME}/.rvm/scripts/rvm
	else
		echo -e "\n\nFAILED TO SET UP RUBY 1.9.3\n\n"
	fi
	rm -f \${FIRST_RUN_SCRIPT}

fi
EOT1
