# Cloud Foundry Java Multi-war Buildpack

This buildpack is a fork of the official [Cloud Foundry java buildpack](https://github.com/cloudfoundry/java-buildpack.git) which has been extended to support deploying multiple `.war` files to Tomcat, either individually or zipped up in one or more zip files.

## Usage
To use this buildpack specify the URI of the repository when pushing an application to Cloud Foundry:

```bash
cf push <APP-NAME> -p <ARTIFACT> -b https://github.com/happiestminds-covisint/java-buildpack.git
```

## Testing using Vagrant

Bring up the vagrant virtual machine and ssh into it.

```bash
vagrant up
vagrant ssh
```

Run the `detect`, `compile` and `release` commands within the vagrant machine.

```bash
cd /vagrant/<directory-containing-war-or-zip-files>

/vagrant/vagrant/run/detect
/vagrant/vagrant/run/compile
/vagrant/vagrant/run/release
```

Connect to the Tomcat instance on port 12345 on your local machine.

[http://localhost:12345](http://localhost:12345)
