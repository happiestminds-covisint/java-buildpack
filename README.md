# Cloud Foundry Java Buildpack + support zip files are having *.war + CT-agent jar support + Shared lib support with YAML upload having maven GAV co-ordinates with custom tomcat jdk and jce support
[![Build Status](https://travis-ci.org/cloudfoundry/java-buildpack.svg?branch=master)](https://travis-ci.org/cloudfoundry/java-buildpack)
[![Dependency Status](https://gemnasium.com/cloudfoundry/java-buildpack.svg)](https://gemnasium.com/cloudfoundry/java-buildpack)
[![Code Climate](https://codeclimate.com/repos/5224adaec7f3a3415107004c/badges/bc49f7d7f8dfc47057c8/gpa.svg)](https://codeclimate.com/repos/5224adaec7f3a3415107004c/feed)
[![Code Climate](https://codeclimate.com/repos/5224adaec7f3a3415107004c/badges/bc49f7d7f8dfc47057c8/coverage.svg)](https://codeclimate.com/repos/5224adaec7f3a3415107004c/feed)

The `java-buildpack` is a [Cloud Foundry][] buildpack for running JVM-based applications.  It is designed to run many JVM-based applications ([Grails][], [Groovy][], Java Main, [Play Framework][], [Spring Boot][], and Servlet) with no additional configuration, but supports configuration of the standard components, and extension to add custom components.
Also we can push *.zip file which has contain multiple war files. cleartrust-plugin jar will be available in part of buildpack and  will be extracted into tomcat/libs folders. Also Tomcat-Valve config entry will be part of <Host> section in server.xml

currently this buildback has been enhanced  for supporting YAML structure which will have libraries , webapps , repository url , credentials,for getting maven 	application artifacts.
multiple context path mapping also take care.
Added custom tomcat and jdk support with YAML structure.

## shared lib - webapps and custom tomcat,jdk support using YAML file upload
web applications along with supported libraries can be uploaded as YAML format with GAV co-ordinates. below are the sample YAML structure. Also multiple context path
will be dynamically added to Server.xml as a <Context> entry.

```repository:
  location: <LOCATION>
  repo-id: <REPOSITORY>
  authentication:
    username: <username>
    password: <password>
libraries: #specify all libraries as a sequence of GAV Coordinates. These would go in tomcat\lib folder
- g: <groupId>
  a: <artifactId>
  v: <version>
      
webapps: #specify all wars as a sequence of GAV Coordinates this would go into tomcat\webapps folder
- g: <groupId>
  a: <artifactId>
  v: <version>
  context-path: <contextpath>
- g: <groupId>
  a:<artifactId>
  v:<version>
  context-path: /abc
container: #allowed keys for configtomcat[tomcat8,tomcat7,tomcat6] and configjdk[oraclejdk8,oraclejdk7,openjdk8,openkdk7]
   configtomcat: <tomcatkey>
   configjdk: <jdkkey>
```	
all the jars and wars will be downloaded and verify SHA checksum for validation. all the jars will be copied over to tomcat/lib and webapps will have all wars.

###Even shared libs can be (optional). if we want to use libraries as optional then remove the below section from YAML
```
libraries: #specify all libraries as a sequence of GAV Coordinates. These would go in tomcat\lib folder
- g: <groupId>
  a: <artifactId>
  v: <version>
```

## cf push for YAML steps
```
##Following are the steps to push this yaml and test out the buildpack..
1.	Copy the attached YAML to an empty directory
2.	With PWD being the directory in 1 do a "cf p <app-name> -b https://github.com/happiestminds-covisint/java-buildpack.git”
3.	Your instance should come up with out issue.
4.	Now go to http://<domain>/check. And you should get a success response.
5.	Now go to http://<domain>/classes?className=sample.SampleTCValve. And it will tell the sample.SampleTCValve class was found. This class is part of the library that is being pushed using the manifest and it goes into the shared classpath.
```
##Notes:
1.	Passing the manifest using "–p” does not work. Looks like the CF CLI does not support upload of a single file which is not an Archive. I think this might work using the CF rest APIs. Let me know if it does not.. Will find some work around for you.
2.	Use *.yaml for now. *.yml does not work. Looks like CF CLI strips *.yml files before upload. Should work with the rest API. But stick to *.yaml as that seems to the official extension

##convert YAML file into zip formation and use like below 
```
 cf p <app-name> -b https://github.com/happiestminds-covisint/java-buildpack.git -p repo-manifest.zip 
```


##Generic support for different jdk , tomcat version with JCE support 
```
	This build has now enhanced to support different jdk and tomcat versions enable via config.yml and based on that versions both jdk(open and Oracle) and tomcat will be downloaded.
Also respective version of JCE security jars will be copied over to jre/security/ folder.	
 cf p <app-name> -b https://github.com/happiestminds-covisint/java-buildpack.git#custom-jdk-tomcat-jce-enabled -p repo-manifest.zip 
```


## Usage
To use this buildpack specify the URI of the repository when pushing an application to Cloud Foundry:

```bash
cf push <APP-NAME> -p <ARTIFACT> -b https://github.com/happiestminds-covisint/java-buildpack.git
```

## Examples
The following are _very_ simple examples for deploying the artifact types that we support.

* [Embedded web server](docs/example-embedded-web-server.md)
* [Grails](docs/example-grails.md)
* [Groovy](docs/example-groovy.md)
* [Java Main](docs/example-java_main.md)
* [Play Framework](docs/example-play_framework.md)
* [Servlet](docs/example-servlet.md)
* [Spring Boot CLI](docs/example-spring_boot_cli.md)

## Configuration and Extension
The buildpack supports extension through the use of Git repository forking. The easiest way to accomplish this is to use [GitHub's forking functionality][] to create a copy of this repository.  Make the required extension changes in the copy of the repository. Then specify the URL of the new repository when pushing Cloud Foundry applications. If the modifications are generally applicable to the Cloud Foundry community, please submit a [pull request][] with the changes.

Buildpack configuration can be overridden with an environment variable matching the configuration file you wish to override minus the `.yml` extension and with a prefix of `JBP_CONFIG`. The value of the variable should be valid inline yaml. For example, to change the default version of Java to 7 and adjust the memory heuristics apply this environment variable to the application.

```cf set-env my-application JBP_CONFIG_OPEN_JDK_JRE '[jre: {version: 1.7.0_+}, memory_calculator: {memory_heuristics: {heap: 85, stack: 10}}]'```

If the key or value contains a special character such as `:` it should be escaped with double quotes. For example, to change the default repository path for the buildpack.

```cf set-env my-application JBP_CONFIG_REPOSITORY '[ default_repository_root: "http://repo.example.io" ]'```

Environment variable can also be specified in the applications `manifest` file. See the [Environment Variables][] documentation for more information.

To learn how to configure various properties of the buildpack, follow the "Configuration" links below. More information on extending the buildpack is available [here](docs/extending.md).

## Additional Documentation
* [Design](docs/design.md)
* [Security](docs/security.md)
* Standard Containers
	* [Dist ZIP](docs/container-dist_zip.md)
	* [Groovy](docs/container-groovy.md) ([Configuration](docs/container-groovy.md#configuration))
	* [Java Main](docs/container-java_main.md) ([Configuration](docs/container-java_main.md#configuration))
	* [Play Framework](docs/container-play_framework.md)
	* [Ratpack](docs/container-ratpack.md)
	* [Spring Boot](docs/container-spring_boot.md)
	* [Spring Boot CLI](docs/container-spring_boot_cli.md) ([Configuration](docs/container-spring_boot_cli.md#configuration))
	* [Tomcat](docs/container-tomcat.md) ([Configuration](docs/container-tomcat.md#configuration))
* Standard Frameworks
	* [AppDynamics Agent](docs/framework-app_dynamics_agent.md) ([Configuration](docs/framework-app_dynamics_agent.md#configuration))
	* [Introscope Agent](docs/framework-introscope_agent.md) ([Configuration](docs/framework-introscope_agent.md#configuration))
	* [DynaTrace Agent](docs/framework-dyna_trace_agent.md) ([Configuration](docs/framework-dyna_trace_agent.md#configuration))
	* [Java Options](docs/framework-java_opts.md) ([Configuration](docs/framework-java_opts.md#configuration))
	* [JRebel Agent](docs/framework-jrebel_agent.md) ([Configuration](docs/framework-jrebel_agent.md#configuration))
	* [MariaDB JDBC](docs/framework-maria_db_jdbc.md) ([Configuration](docs/framework-maria_db_jdbc.md#configuration))
	* [New Relic Agent](docs/framework-new_relic_agent.md) ([Configuration](docs/framework-new_relic_agent.md#configuration))
	* [Play Framework Auto Reconfiguration](docs/framework-play_framework_auto_reconfiguration.md) ([Configuration](docs/framework-play_framework_auto_reconfiguration.md#configuration))
	* [Play Framework JPA Plugin](docs/framework-play_framework_jpa_plugin.md) ([Configuration](docs/framework-play_framework_jpa_plugin.md#configuration))
	* [PostgreSQL JDBC](docs/framework-postgresql_jdbc.md) ([Configuration](docs/framework-postgresql_jdbc.md#configuration))
	* [Spring Auto Reconfiguration](docs/framework-spring_auto_reconfiguration.md) ([Configuration](docs/framework-spring_auto_reconfiguration.md#configuration))
	* [Spring Insight](docs/framework-spring_insight.md)
* Standard JREs
	* [OpenJDK](docs/jre-open_jdk_jre.md) ([Configuration](docs/jre-open_jdk_jre.md#configuration))
	* [Oracle](docs/jre-oracle_jre.md) ([Configuration](docs/jre-oracle_jre.md#configuration))
* [Extending](docs/extending.md)
	* [Application](docs/extending-application.md)
	* [Droplet](docs/extending-droplet.md)
	* [BaseComponent](docs/extending-base_component.md)
	* [VersionedDependencyComponent](docs/extending-versioned_dependency_component.md)
	* [ModularComponent](docs/extending-modular_component.md)
	* [Caches](docs/extending-caches.md) ([Configuration](docs/extending-caches.md#configuration))
	* [Logging](docs/extending-logging.md) ([Configuration](docs/extending-logging.md#configuration))
	* [Repositories](docs/extending-repositories.md) ([Configuration](docs/extending-repositories.md#configuration))
	* [Utilities](docs/extending-utilities.md)
* [Debugging the Buildpack](docs/debugging-the-buildpack.md)
* [Buildpack Modes](docs/buildpack-modes.md)
* Related Projects
	* [Java Buildpack Dependency Builder](https://github.com/cloudfoundry/java-buildpack-dependency-builder)
	* [Java Test Applications](https://github.com/cloudfoundry/java-test-applications)
	* [Java Buildpack System Tests](https://github.com/cloudfoundry/java-buildpack-system-test)

## Building Packages
The buildpack can be packaged up so that it can be uploaded to Cloud Foundry using the `cf create-buildpack` and `cf update-buildpack` commands.  In order to create these packages, the rake `package` task is used.

### Online Package
The online package is a version of the buildpack that is as minimal as possible and is configured to connect to the network for all dependencies.  This package is about 50K in size.  To create the online package, run:

```bash
bundle install
bundle exec rake package
...
Creating build/java-buildpack-cfd6b17.zip
```

### Offline Package
The offline package is a version of the buildpack designed to run without access to a network.  It packages the latest version of each dependency (as configured in the [`config/` directory][]) and [disables `remote_downloads`][]. This package is about 180M in size.  To create the offline package, use the `OFFLINE=true` argument:

```bash
bundle install
bundle exec rake package OFFLINE=true
...
Creating build/java-buildpack-offline-cfd6b17.zip
```

### Package Versioning
Keeping track of different versions of the buildpack can be difficult.  To help with this, the rake `package` task puts a version discriminator in the name of the created package file.  The default value for this discriminator is the current Git hash (e.g. `cfd6b17`).  To change the version when creating a package, use the `VERSION=<VERSION>` argument:

```bash
bundle install
bundle exec rake package VERSION=2.1
...
Creating build/java-buildpack-2.1.zip
```

## Running Tests
To run the tests, do the following:

```bash
bundle install
bundle exec rake
```

[Running Cloud Foundry locally][] is useful for privately testing new features.

## Running Tests with Vagrant for Zip supported files
To run the tests, do the following:
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

	
## Contributing
[Pull requests][] are welcome; see the [contributor guidelines][] for details.

## License
This buildpack is released under version 2.0 of the [Apache License][].

[`config/` directory]: config
[Apache License]: http://www.apache.org/licenses/LICENSE-2.0
[Cloud Foundry]: http://www.cloudfoundry.com
[contributor guidelines]: CONTRIBUTING.md
[disables `remote_downloads`]: docs/extending-caches.md#configuration
[Environment Variables]: http://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html#env-block
[GitHub's forking functionality]: https://help.github.com/articles/fork-a-repo
[Grails]: http://grails.org
[Groovy]: http://groovy.codehaus.org
[Play Framework]: http://www.playframework.com
[pull request]: https://help.github.com/articles/using-pull-requests
[Pull requests]: http://help.github.com/send-pull-requests
[Running Cloud Foundry locally]: http://docs.cloudfoundry.org/deploying/run-local.html
[Spring Boot]: http://projects.spring.io/spring-boot/
