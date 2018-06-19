Docker image for one-way replication with SymmetricDS
=====================================================

This will be a [Docker] image for running simple, one-way replication
using [SymmetricDS].

*Please note, this image is not yet ready for production.*

Getting started
---------------

Make sure you have Docker and [Docker Compose] installed on your system
and run:

```bash
$ git clone git@github.com:UKHomeOffice/docker-symmetricds.git
$ cd docker-symmetricds
$ make
$ docker-compose up
```

Configuration
-------------

Configuration is available using environment variables in order to configure the symmetric container.

```
GROUP_ID: <Node Group that this Node is a member of. [SymmetricDSGroups]>
DB_HOST: <Database host name>
DB_SSL: Defines whether or not to use SSL/TLS. Set to FALSE to disable. Defaults to TRUE.
DB_CA: A base64 encoded CA certificate to verify the database's certificate against. If no certificate is provided then the certificate will not be verified.
DB_TYPE: <Used to tell symmetric what JDBC driver to use. Can be mysql, postgres or oracle. Defaults to postgres.>
DB_NAME: <Database name>
DB_USER: <Database user>
DB_PASS: <Database password
USERNAME: <Username for basic auth>
PASSWORD: <Password for basic auth>
SYNC_URL: <URL where this Node can be contacted for synchronization. At startup and during each heartbeat, the Node updates its entry in the database with this URL>
REGISTRATION_URL: <URL where this Node can connect for registration to receive its configuration. The registration server is part of SymmetricDS and is enabled as part of the deployment>
HTTPS: <A flag to allow TLS termination. Defaults to TRUE. When set to FALSE will listen on the HTTP port, accepting insecure traffic.>
HTTPS_CRT: <HTTPS certificate to use if terminating TLS.
HTTPS_KEY: <Key for provided certificate.>
HTTPS_CA_BUNDLE: <Certificate authority for HTTPS used to verify other nodes. In a two node setup this could be the other nodes public certificate.>
REPLICATE_TO: <Name of symmetric GROUP_ID to replicate to.>
REPLICATE_TABLES: <Name of tables (space separated) and optional columns to replicate (columns are specified with a pipe and the comma separation). See [docker-compose] for more info.>
```

Clustering
----------

Targets can be clustered in the example docker-compose files by simply using scale for example:

```docker-compose up --scale symds_target=2```

This will create a cluster of two targets.

Example Usage
-------------

You can check out a pretty standard example of a replication using a source and target (postgres to postgres) using the following [docker-compose].

To see basic auth in action please check out [docker-compose-basic-auth].

Example k8s
-----------

A basic example of a k8s deployment for [target-mode].

Authors
-------

* **Daniel A.C. Martin** - *Initial work* - [daniel-ac-martin]
* **Ben Marvell** - *TLS, Basic Auth, Multiple table and field replication* - [easternbloc]

See also the list of [contributors] who participated in this project.

License
-------

This project is licensed under the MIT License - see the [LICENSE.md]
file for details.

[contributors]:              https://github.com/UKHomeOffice/docker-symmetricds/graphs/contributors
[daniel-ac-martin]:          https://github.com/daniel-ac-martin
[easternbloc]:               https://github.com/easternbloc
[Docker]:                    https://www.docker.com/
[DockerCompose]:             https://docs.docker.com/compose/
[LICENSE.md]:                LICENSE.md
[SymmetricDS]:               https://www.symmetricds.org/
[SymmetricDSGroups]:         https://www.symmetricds.org/doc/3.8/html/user-guide.html#_groups
[docker-compose]:            docker-compose.yml
[docker-compose-basic-auth]: docker-compose-basic-auth.yml
[target-mode]:               k8s/target.yaml

