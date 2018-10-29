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
│   ├── ejabberd.cfg
│   ├── hosts
│   ├── mongooseim
│   └── mongooseim.tar.gz
└── myproject-mongooseim-2
    ├── ejabberd.cfg
    ├── hosts
    ├── mongooseim
    └── mongooseim.tar.gz
```

We're preparing a 2 node cluster hence two directories (`myproject-mongooseim-X`).
The only file we need to place there is `ejabberd.cfg` (a predefined config file).
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
$ docker exec -it myproject-mongooseim-1 /member/mongooseim/bin/mongooseimctl mnesia running_db_nodes
['mongooseim@myproject-mongooseim-2','mongooseim@myproject-mongooseim-1']
$ docker exec -it myproject-mongooseim-2 /member/mongooseim/bin/mongooseimctl mnesia running_db_nodes
['mongooseim@myproject-mongooseim-1','mongooseim@myproject-mongooseim-2']
```

Tadaa! There you have a brand new shiny cluster running.

Note that the first container is started with `-h mongooseim-1` and `--name mongooseim-1` parameters - a few things are important here:

1. Both parameters must be set to the same value. The second and all the subsequent containers have the same requirement.

    * `-h` option sets `HOSTNAME` environment variable for the container. The [start.sh](https://github.com/esl/mongooseim-docker/blob/66666b9/member/start.sh#L11) script uses it to generate the Erlang node name.
    * `--name` is required to provide automatic DNS resolution between the containers. See [Docker network documentation](https://docs.docker.com/network/bridge/#differences-between-user-defined-bridges-and-the-default-bridge) page for more details.

1. Format of the host name:

    * Host name of the first container must be in the `some_name-1` format. That allows [start.sh](https://github.com/esl/mongooseim-docker/blob/66666b9/member/start.sh#L50) to identify the primary node of the cluster.
    * All the subsequent containers must follow the `some_name-N` host name format, where `N` > 1.

1. Clustering is done automatically by the [start.sh](https://github.com/esl/mongooseim-docker/blob/66666b9/member/start.sh#L50) script. If you want to modify that logic please check [the latest MongooseIM documentation](https://mongooseim.readthedocs.io/en/latest/operation-and-maintenance/Cluster-configuration-and-node-management/).


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
which can be found in MongooseIM's repo in `apps/ejabberd/priv/pgsql.sql`

Don't forget to tweak your `ejabberd.cfg` to connect with the services you set up!
For example, like this in case of the PostgreSQL container mentioned above:

```
{odbc_server, {pgsql, "mongooseim-postgres", "mongooseim", "mongooseim", "mongooseim"}}.
```

