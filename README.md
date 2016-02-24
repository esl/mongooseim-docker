# mongooseim-docker

MongooseIM server version 1.5.  

MongooseIM is Erlang Solutions' robust and efficient XMPP server aimed at large installations.
Specifically designed for enterprise purposes,
it is fault-tolerant, can utilize resources of multiple clustered machines and easily scale in need of more capacity (by just adding a box/VM).
Its home at GitHub is http://github.com/esl/MongooseIM.

This work, though it's not reflected in git history,
was bootstrapped from Paweł Pikuła's (@ppikula) great https://github.com/ppikula/MongooseIM-docker/.

## Quick start guide


### Build a MongooseIM tarball

Building the build bot:

```
make PROJECT=myproject builder
```

The builder is started with an external volume `${VOLUMES}/builds` mounted as `/builds`.
By default `VOLUMES` is defined as `$(shell pwd)/examples`,
but you can override it in the Makefile or on the command line (as is done with `PROJECT`).

The `PROJECT` variable isn't really used in any other way than identifying your container.
That way if you want to customize the builder Dockerfile for different projects,
you can still use a single Makefile to build multiple different builders.
The container will be named `${PROJECT}-builder`.

The builder expects to find a `/builds/specs` file with the following format:

```
myproject  3414588 https://git.repo.address.com
myproject2 3414588 https://git.repo.address.com custom_build_script.sh
```

The columns are:

-   project name / unique name - used to identify the line

-   commit / branch / tag - what to checkout?

-   repo address - where to checkout from? this can be a local address, so
    you can place the repo next to the `specs` file itself for fast builds
    from the local file system

-   optional custom build script - if the default build procedure doesn't
    work with the repo you provide
    (see `builder/build.sh` if you want to inspect it);
    if you provide a custom script, it will be called like this:

    ```
    custom_build_script.sh myproject2 3414588 https://git.repo.address.com custom_build_script.sh
    ```

To use a valid MongooseIM repo and commit we'll use this `specs` file:

```
myproject 34097d5 https://github.com/esl/mongooseim
```

To build a MongooseIM tarball run:

```
docker exec -it myproject-builder /build.sh
```

For troubleshooting you might also use:

```
make PROJECT=myproject builder.shell
# inside the container
/build.sh
```

A log file of the build is available at `/builds/build.log`,
so it's accessible from the host system at `${VOLUMES}/builds/build.log`.

Finally, a tarball you get after a successful build will land
at `${VOLUMES}/builds/mongooseim-myproject-3414588-2015-11-20_095715.tar.gz`
(it's `mongooseim-${PROJECT}-${COMMIT}-${TIMESTAMP}.tar.gz`).


### Creating MongooseIM containers

First, we need to setup some volumes (don't mind `builds/` for this stage):

```
${VOLUMES}/
├── builds
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

We create a cluster member image with 

```
make PROJECT=myproject member.build
```

Then we can create a member container:

```
make member.create PROJECT=myproject MEMBER=myproject-mongooseim-1 \
    MEMBER_TGZ=mongooseim-myproject-3414588-2015-11-20_095715.tar.gz
```

After `docker logs docker logs myproject-mongooseim-1` shows something similar to:

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

Let's start another cluster member:

```
make member.create PROJECT=myproject MEMBER=myproject-mongooseim-2 \
    MEMBER_TGZ=mongooseim-myproject-3414588-2015-11-20_095715.tar.gz
```

Redo the `docker logs` and `telnet` checks, but this time against `myproject-mongooseim-2`.
The nodes should already form a cluster.
Let's check it:

```
$ docker exec -it myproject-mongooseim-1 /member/mongooseim/bin/mongooseimctl mnesia running_db_nodes
['mongooseim@myproject-mongooseim-2','mongooseim@myproject-mongooseim-1']
$ docker exec -it myproject-mongooseim-2 /member/mongooseim/bin/mongooseimctl mnesia running_db_nodes
['mongooseim@myproject-mongooseim-1','mongooseim@myproject-mongooseim-2']
```

Tadaa! There you have a brand new shiny cluster running.


### Adding backends

There are plenty of ready to use Docker images with databases
or external services you might want to integrate with the cluster.
For example, I'm running a [stock `postgres:9.4`](https://hub.docker.com/_/postgres/) container.
Thanks to prefixing its name with `PROJECT` (as defined before),
it is automatically picked up by the `member.create` rule:

```
$ docker ps | grip postgres
ffac07900f4f  postgres:9.4  "/docker-entrypoint.s"  9 days ago  Up 9 days  0.0.0.0:32768->5432/  myproject-postgres
```

The discovered hosts for respective cluster members are:

```
$ cat examples/myproject-mongooseim-1/hosts
172.17.0.2 myproject-postgres
$ cat examples/myproject-mongooseim-2/hosts
172.17.0.2 myproject-postgres
172.17.0.3 myproject-mongooseim-1
```

Just make sure to start it before you create your cluster members,
as that's when the `hosts` files are generated.
See Makefile rule `member.create` and script `generate-hosts`
if you need to troubleshoot this mechanism.
The `hosts` file is appended to member's `/etc/hosts` in `member/start.sh`.
Don't forget to tweak your `ejabberd.cfg` to connect with the services you set up!
For example, like this in case of the PostgreSQL container mentioned above:

```
{odbc_server, {pgsql, "myproject-postgres", "postgres", "postgres", "%YOUR_PASSWORD%"}}.
```

## Very quick start guide

The repository contains a script that uses all the building blocks and
builds a MongooseIM cluster with basic monitoring and load-balancing from
scratch.

To build a 3 node cluster from the current master branch follow these
steps:

Build all necessary Docker images and MongooseIM release:
```
PROJECT=example COMMIT=master ./quickstart build
```

Start all the containers and set them up:
```
PROJECT=example NODES=3 ./quickstart start
```
If you see something like:
```
You should be able to connect to MongooseIM via XMPP at $DOCKERIP:5222.
...
```
at the end of the output then you should be able to explore MongooseIM on
all the dashboards listed there. Please note that Graphite metrics need
some time to show up for the first time.

To list all the containers created for the project:
```
PROJECT=example ./quickstart status
```

To stop and remove all of them:
```
PROJECT=example ./quickstart stop
```

## ToDo

- [ ] make cluster setup fully automatic
