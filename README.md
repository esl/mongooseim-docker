# mongooseim-docker

MongooseIM is Erlang Solutions' robust and efficient XMPP server aimed at large installations.
Specifically designed for enterprise purposes,
it is fault-tolerant, can utilize resources of multiple clustered machines and easily scale in need of more capacity (by just adding a box/VM).
Its home at GitHub is http://github.com/esl/MongooseIM.

This work, though it's not reflected in git history,
was bootstrapped from Paweł Pikuła's (@ppikula) great https://github.com/ppikula/MongooseIM-docker/.

## Prerequisites

Linux, preferably Ubuntu 14. On Mac there are some routing issues which are not covered in this document.

## General

```
Image:mongooseim/mongooseim-builder
 |
 |-Container:mongooseim-builder
   |
   |-Build:mongooseim-myproj-master.tar.gz
   |  |
   |  |-Image:myproj-master
   |    |
   |    |-Container:master-1 -----|
   |    |                         |- config-dir-1/
   |    |-Container:master-2 -----|
   |  
   |-Build:mongooseim-myproj-branch.tar.gz
     |
     |-Image:myproj-branch
       |
       |-Container:branch-1 ------|
       |                          |
       |-Container:branch-2 ------|- config-dir-2/
       |                          |
       |-Container:branch-3 ------|

```

## Installation

If you need vanila MongooseIM as found on https://github.com/esl/MongooseIM please use docker images from
https://hub.docker.com/r/mongooseim/mongooseim/

If customised images are needed, following documentation may be useful.

### Build a MongooseIM tarball

#### The builder bot

In order to build MongooseIM tarball a mongooseim-builder needs to be started.
It's important to mount the container `/builds` volume as the MongooseIM tarball
will be placed there after the build.
For simplicity it's assumed that env var `VOLUMES` is exported and set to an existing
absolute path, f.e: `pwd`

```
docker run -d --name mongooseim-builder -h mongooseim-builder \
       -v ${VOLUMES}/builds:/builds mongooseim/mongooseim-builder
```

#### Building MongooseIM

Now building MongooseIM tarball is as simple as runing following command:
```
docker exec -i mongooseim-builder /build.sh
```

This command will by default build MongooseIM's master branch from: https://github.com/esl/MongooseIM.
This can be changed by specificing parameter to the `build.sh` command:

```
/build.sh project_name repo commit
```

* `project_name` - friendly name for the build (defaults to "mongooseim")

* `commit` - commit or branch or tag - what to checkout? (defaults to "master")

* `repo` - where to checkout from (defaults to "https://github.com/esl/MongooseIM")

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
MongooseIM can be build now from `Dockerfile.member`. 

IMPORTANT: dockerfile will look for your mongooseim tarball in `./member/mongooseim.tar.gz`. To use your build
create a symlink, like:

```
cd member
ln -s ../builds/builds/mongooseim-myproject-3414588-2015-11-20_095715.tar.gz mongooseim.tar.gz
```

The image can now be build with this command:

`docker build -f Dockerfile.member -t mongooseim-myversion .`

This will create a `mongooseim-myversion` image from which you can now create containers running this version of MongooseIM.

#### Creating a container

First, create a subdirectory which will hold configuration files for your cluster. Put there your custom
`ejabberd.cfg`, `app.config`, `vm.args` and `vm.dist.args` (if you omit some files then the container will use defaults
from the source code).

You need only one set of files per cluster; the only thing that changes per node is nodename, and this is handled
automatically by the container's startups script.

Your configuration directory will be mounted inside a container as `/member`; if you need ssl keys, put them in a subdirectory
in your custom config file, and then refer to them in vm.args as `/member/[filename]`.

Then, assuming your custom config is in `./config`, run:

```
docker run -t -d -v "$(pwd)/config/":/member -h mongooseim-node-1 --name mongooseim-node-1 mongooseim-myversion
```

This command creates and runs a `mongooseim-node-1` container, based on `mongooseim-myversion` image, and mounts configuration
directory. MongooseIM node name will be `mongooseim@mongooseim-node-1`.

IMPORTANT: your first node/host name has to end with "-1", and all subsequent names have to follow the same convention. 
This is because docker scripts try to automatically set up a cluster using this naming scheme.

#### Managing a container

Start and stop a container using standard docker commands.

You can run mongoose control scripts within a container; for convenience, use the ./mongooseimctl script. The first arg 
is required and is a container name (which is also a node domain name). So:

```
u@localhost$ ./mongooseimctl mongooseim-node-1 mnesia running_db_nodes
['mongoose@mongooseim-node-1']
u@localhost$
```

To check if MongooseIM is accepting connections use the `./tnet` script. It automatically detects the container's IP and port
and tries to telnet to it. If you type anything at the shell prompt you should receive an xmpp stream error stanza:

```
u@localhost$ ./tnet mongooseim-node-1
Mongoose node: mongooseim-node-1, 172.17.0.5:5222
Trying 172.17.0.5...
Connected to 172.17.0.5.
Escape character is '^]'.
z
<?xml version='1.0'?><stream:stream xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' id='CB94EBB01F892081' from='localhost' version='1.0'><stream:error><xml-not-well-formed xmlns='urn:ietf:params:xml:ns:xmpp-streams'/></stream:error></stream:stream>Connection closed by foreign host.
u@localhost$
```

### Clustering

A necessary prerequisite is to enable name resolution, so that your containers can resolve one another's names to IPs
of containers, or of hosts they are running and exposing their ports on. 

If your containers are running on the same host and share config directory, then create a user network and add
your containers to it:

```
docker network create myclusternetwork
docker network connect myclusternetwork mongooseim-node-1
docker network connect myclusternetwork mongooseim-node-2
```

(or create the network beforehand and pass `--network` option to `docker run`).

Another option is to create custom hosts file in your config directory and restart the containers. 
The container's startup script will append those entries to its /etc/hosts file.

Then check if it works:

```
docker exec -it mongooseim-node-1 ping mongooseim-node-2
```

Once name resolution works, you can proceed with clustering as you normally would:

```
./mongooseimctl mongooseim-node-2 join_cluster mongooseim@mongooseim-node-1
```

Check if it works:

```
u@localhost$ ./mongooseimctl mongooseim-node-1 mnesia running_db_nodes
['mongooseim@mongooseim-node-2','mongooseim@mongooseim-node-1']
u@localhost$
```

If you created your network first and then started nodes in that network, chances are they cluster themselves automatically.

### Adding backends

There are plenty of ready to use Docker images with databases
or external services you might want to integrate with the cluster.
For example, I'm running a [stock `postgres:9.6.1`](https://hub.docker.com/_/postgres/) container.
```
docker run -d --name mongooseim-postgres \
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

Ah, and you didn't forget to add `mongooseim-postgres` container to your cluster network, did you? Of course you didn't.

## Running tests

Testing is a bit more involved, because normally tests are run on the same host as the MongooseIM server, so they expect
mongoose to listen on certain ports on localhost, use localhost as addressing domain, and set up erlang distribution in the
most straighforward way possible. To make it run when your servers are inside docker containers requires some tweaks to 
both environment and test configuration file. There are may ways to do it, here is one of them:

### Tests on host, minimal changes to test config file

1. Publish port(s) from mongooseim

To run the most basic tests you have to access port 5222 of your container. Publish it on host by adding
```
-p 5222:5222
```

to the `docker run` command.

2. Allow request from non-localhost

Since you will be using published ports, the host you are connecting from is not localhost anymore. Default ejabberd.cfg
in many places accepts requests only from 127.0.0.1 (e.g. registering users or admin REST commands). You have to change it
to 0.0.0.0 everywhere.

3. Install MongooseIM on host

* install required packages (find a list of them on readthedocs)
* install and activate Erlang (hint: kerl is a very good tool for that)
* clone MongooseIM, run `make` (this is enough, you don't need releases)

4. Enable erlang distribution

Tests use distribution to set up nodes they are testing. Here we have to tell tests how to reach the node:

* check your container's IP (`docker inspect mongooseim-node-1 | grep IPAddress)`
* add it to /etc/hosts
* edit test.config file:
```
      {ejabberd_node, 'mongooseim@localhost'}.         => {ejabberd_node, 'mongooseim@mongooseim-node-1'}.
      {hosts, [{mim,  [{node, 'mongooseim@localhost'}, => {hosts, [{mim,  [{node, 'mongooseim@mongooseim-node-1'},
```

Now simple tests (e.g. `mod_ping_SUITE`) should pass. For more elaborate test suits you may have to publish more ports, like
http endpoints, and configure other mongoose nodes, like mim2 or fed. Remember that other nodes will publish different ports,
for instance mim2 listens for xmpp connections on 5232, so you will publish it by `-p 5232:5222`.

One last reminder: if you are going to use ssl keys, the keys in your container have to match those in `tests.disabled/ejabberd_tests/priv/ssl`.
