# mongooseim-docker

MongooseIM is Erlang Solutions' robust and efficient XMPP server aimed at large installations.
Specifically designed for enterprise purposes,
it is fault-tolerant, can utilize resources of multiple clustered machines and easily scale in need of more capacity (by just adding a box/VM).
Its home at GitHub is http://github.com/esl/MongooseIM.

This work, though it's not reflected in git history,
was bootstrapped from Paweł Pikuła's (@ppikula) great https://github.com/ppikula/MongooseIM-docker/.

## Quick start guide

If you need vanilla MongooseIM as found on https://github.com/esl/MongooseIM please use docker images from
https://hub.docker.com/r/mongooseim/mongooseim/

If customised images are needed, following documentation may be useful.

### Build a MongooseIM tarball

#### The builder container

In order to build MongooseIM tarball a builder image and container need to be created.
You can create an image by running the following command:

```
docker build -f Dockerfile.builder -t mongooseim-builder .
```

After that you can run the builder container.
It's important to mount the container's `/builds` directory as a volume because MongooseIM tarball will be placed there after the build.
For simplicity it's assumed that env var `VOLUMES` is exported and set to an existing absolute path, f.e: `pwd`

```
docker run -d --name mongooseim-builder -h mongooseim-builder \
       -v ${VOLUMES}/builds:/builds mongooseim/mongooseim-builder
```

##### Modifying Erlang/OTP version

You can modify which Erlang/OTP version is used by MongooseIM when creating a builder image by providing `OTP_VSN` build argument:


```
docker build --build-arg OTP_VSN=19.3.6 -f Dockerfile.builder -t mongooseim-builder:otp19.3.6 .
```

By default the builder will use Erlang/OTP 20.3.


#### Building MongooseIM

Now building MongooseIM tarball is as simple as running the following command:

```
docker exec -i mongooseim-builder /build.sh
```

This command will by default build MongooseIM's master branch from: https://github.com/esl/MongooseIM.
This can be changed by specifying a parameter to the `build.sh` command:

```
/build.sh project_name repo commit
```

* `project_name` - friendly name for the build

* `commit` - commit or branch or tag - what to checkout?

* `repo` - where to checkout from

In order to build a specific commit, following command can be used:

```
docker exec -i mongooseim-builder /build.sh MongooseIM https://github.com/esl/MongooseIM a37c196
```

A log file of the build is available at `/builds/build.log`,
so it's accessible from the host system at `${VOLUMES}/builds/build.log`.

Finally, a tarball you get after a successful build will land
at `${VOLUMES}/builds/mongooseim-myproject-3414588-2015-11-20_095715.tar.gz`
(it's `mongooseim-${PROJECT}-${COMMIT}-${TIMESTAMP}.tar.gz`).


### Creating MongooseIM containers

#### Building the image

Provided a tarball was produced by mongooseim-builder a small image with only
MongooseIM can be build now from `Dockerfile.member`. In order to build the image
the MongooseIM tarball has to be copied to `members` directory.
The image can now be build with this command:

`docker build -f Dockerfile.member -t mongooseim .`

First, we need to setup some volumes:

```
${VOLUMES}/
├── myproject-mongooseim-1
│   ├── mongooseim.cfg
│   ├── hosts
│   ├── mongooseim
│   └── mongooseim.tar.gz
└── myproject-mongooseim-2
    ├── mongooseim.cfg
    ├── hosts
    ├── mongooseim
    └── mongooseim.tar.gz
```

We're preparing a 2 node cluster hence two directories (`myproject-mongooseim-X`).
The only file we need to place there is `mongooseim.cfg` (a predefined config file).
The rest is actually created when we build our cluster member containers.

The member container can be created with the following command

```
docker run -t -d -h mongooseim-1 --name mongooseim-1  mongooseim
```

After `docker logs mongooseim-1` shows something similar to:

```
MongooseIM cluster primary node mongooseim@myproject-mongooseim-1
Clustered mongooseim@myproject-mongooseim-1 with mongooseim@myproject-mongooseim-1
Exec: /member/mongooseim/erts-6.3/bin/erlexec -boot /member/mongooseim/releases//mongooseim -embedded -config /member/mongooseim/etc/app.config -args_file /member/mongooseim/etc/vm.args -- live --noshell -noinput +Bd -mnesia dir "/member/mongooseim/Mnesia.mongooseim@myproject-mongooseim-1"
Root: /member/mongooseim
2015-11-20 10:42:35.903 [info] <0.7.0> Application lager started on node 'mongooseim@myproject-mongooseim-1'
...
2015-11-20 10:42:36.420 [info] <0.145.0>@ejabberd_app:do_notify_fips_mode:270 Used Erlang/OTP does not support FIPS mode
2015-11-20 10:42:36.453 [info] <0.7.0> Application mnesia exited with reason: stopped
2015-11-20 10:42:36.535 [info] <0.7.0> Application mnesia started on node 'mongooseim@myproject-mongooseim-1'
2015-11-20 10:42:36.571 [info] <0.7.0> Application p1_cache_tab started on node 'mongooseim@myproject-mongooseim-1'
```

We can health-check the MongooseIM node with `telnet`.
Supply the IP based on your setup - Docker Machine or localhost - and port
which translates to the container's 5222:

```
$ telnet $BOOT2DOCKER_IP 32822
Trying 192.168.99.100...
Connected to 192.168.99.100.
Escape character is '^]'.
<?xml version='1.0'?><stream:stream xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' id='1996592071' from='localhost' version='1.0'><stream:error><xml-not-well-formed xmlns='urn:ietf:params:xml:ns:xmpp-streams'/></stream:error></stream:stream>Connection closed by foreign host.
```

Success! MongooseIM is accepting XMPP connections.


### Setting up a cluster

There are two methods of clustering: the default, automatic one and a method where you have more control over the cluster formation.

#### Default clustering

To use default clustering behaviour, your containers need both container names (`--name` option) and host names (`-h` option) with the `-n` suffix,
where `n` are consecutive integers starting with `1` (configurable with `MASTER_ORDINAL` env variable), e.g. `mongooseim-1`, `mongooseim-2` and so on.
Make sure you have started a node with `-${MASTER_ORDINAL}` suffix first (e.g. `-h mongooseim-1` and `--name mongooseim-1`), as all the other nodes will connect to it when joining the cluster.

Few things are important here:

1. Both parameters must be set to the same value if used in docker/docker-compose. The second and all the subsequent containers have the same requirement.

    * `-h` option sets `HOSTNAME` environment variable for the container which in turn sets long hostname of the machine. The [start.sh](https://github.com/esl/mongooseim-docker/blob/1948b42/member/start.sh#L20) script uses it to generate the Erlang node name if `NODE_TYPE=name`.
    If `NODE_TYPE=sname` (default), short hostname will be used instead. If value provided to `-h` option is already short hostname, it will be used as is,
    otherwise it will be shortened (longest part that doesn't contain '.' character).
    * `--name` is required to provide automatic DNS resolution between the containers. See [Docker network documentation](https://docs.docker.com/network/bridge/#differences-between-user-defined-bridges-and-the-default-bridge) page for more details.

1. Format of the host name:

    * Host name of the first container must be in the `${NODE_NAME}-${MASTER_ORDINAL}` format. That allows [start.sh](https://github.com/esl/mongooseim-docker/blob/1948b42/member/start.sh#L71) to identify the primary node of the cluster.
    * All the subsequent containers must follow the `${NODE_NAME}-N` host name format, where `N` > `${MASTER_ORDINAL}`.

##### Example

Create a user-defined bridge network and connect `mongooseim-1` container to it:
```
docker network create mim_cluster
docker network connect mim_cluster mongooseim-1
```

And now let's start another cluster member:

```
docker run -t -d --network mim_cluster -h mongooseim-2 --name mongooseim-2 mongooseim
```

Redo the `docker logs` and `telnet` checks, but this time against `mongooseim-2`.
The nodes should already form a cluster.
Let's check it:

```
$ docker exec -it myproject-mongooseim-1 /usr/lib/mongooseim/bin/mongooseimctl mnesia running_db_nodes
['mongooseim@myproject-mongooseim-2','mongooseim@myproject-mongooseim-1']
$ docker exec -it myproject-mongooseim-2 /usr/lib/mongooseim/bin/mongooseimctl mnesia running_db_nodes
['mongooseim@myproject-mongooseim-1','mongooseim@myproject-mongooseim-2']
```

Tadaa! There you have a brand new shiny cluster running.

##### Kubernetes notes

Default clustering may work as part of Kubernetes StatefulSet deployment with only two changes:

* `MASTER_ORDINAL` has to be set to `0` as `StatefulSet` starts counting instances from 0
* `NODE_TYPE` has to be set to `name` (use of long names) as Kubernetes uses FQDN within internal DNS to resolve `pod's` IP address.
  Please note that for `pod` domain to work you have to have headless service running that matches your `StatefulSet`
  (see https://kubernetes.io/docs/concepts/services-networking/service/#headless-services)

#### Manual clustering

With the manual clustering method, you need to explicitly specify the name of the node to join the cluster with via the `CLUSTER_WITH` environment variable.
You may also disable clustering during container startup altogether by setting `JOIN_CLUSTER=false` variable (it's set to `true` by default).

##### Examples

Let's try providing a name of the node to join the cluster with manually:

```
docker network create mim
docker run -dt --net mim -h first-node --name first-node -e JOIN_CLUSTER=false mongooseim
docker run -dt --net mim -h second-node --name second-node -e CLUSTER_WITH=mongooseim@first-node --name mongooseim-2 mongooseim
```

Let's break up these commands on by one.

The first command creates a network for nodes so that they reach each other via network by container name.
The second command starts a node and tells it not to try to join any clusters (as there are no other nodes).
We then tell the second node to join the cluster with the first node.

You can now check that the nodes have formed the cluster:

```
$ docker exec -t mongooseim-1 /usr/lib/mongooseim/bin/mongooseimctl mnesia running_db_nodes
['mongooseim@first-host','mongooseim@second-host']
$ docker exec -t mongooseim-2 /usr/lib/mongooseim/bin/mongooseimctl mnesia running_db_nodes
['mongooseim@second-host','mongooseim@first-host']
```


### Adding backends

There are plenty of ready to use Docker images with databases
or external services you might want to integrate with the cluster.
For example, I'm running a [stock `postgres:9.6.1`](https://hub.docker.com/_/postgres/) container.

```
docker run -d --name mongooseim-postgres --network mim_cluster \
       -e POSTGRES_PASSWORD=mongooseim -e POSTGRES_USER=mongooseim \
       -v ${PATH_TO_MONGOOSEIM_PGSQL_FILE}:/docker-entrypoint-initdb.d/pgsql.sql:ro \
       -p 5432:5432 postgres:9.6.1
```

Where `${PATH_TO_MONGOOSEIM_PGSQL_FILE}` is an absolute path to pgsql.sql file
which can be found in MongooseIM's repo in `priv/pgsql.sql`

Don't forget to tweak your `mongooseim.cfg` to connect with the services you set up!
For example, like this in case of the PostgreSQL container mentioned above:

```
{rdbms_server, {pgsql, "mongooseim-postgres", "mongooseim", "mongooseim", "mongooseim"}}.
```

