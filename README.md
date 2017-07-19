# mongooseim-docker

MongooseIM is Erlang Solutions' robust and efficient XMPP server aimed at large installations.
Specifically designed for enterprise purposes,
it is fault-tolerant, can utilize resources of multiple clustered machines and easily scale in need of more capacity (by just adding a box/VM).
Its home at GitHub is http://github.com/esl/MongooseIM.

This work, though it's not reflected in git history,
was bootstrapped from Paweł Pikuła's (@ppikula) great https://github.com/ppikula/MongooseIM-docker/.

## Quick start guide

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

Then, assuming your custom config is in `./config`, run:

```
docker run -t -d -v "$(pwd)/config/":/member -h mongo-1 --name mongo-1 mongooseim-myversion
```

This command creates and runs a `mongo-1` container, based on `mongooseim-myversion` image, and mounts configuration
directory. MongooseIM node name will be `mongooseim@mongo-1`.

#### Managing a container

Start and stop a container using standard docker commands.

You can run mongoose control scripts within a container; for convenience, use the ./mongooseimctl script. The first arg 
is required and is a container name (which is also a node domain name). So:

```
u@localhost$ ./mongooseimctl mongo-1 mnesia running_db_nodes
['mongoose@mongo-1']
u@localhost$
```

To check if MongooseIM is accepting connections use the `./tnet` script. It automatically detects the container's IP and port
and tries to telnet to it. If you type anything at the shell prompt you should receive an xmpp stream error stanza:

```
u@localhost$ ./tnet mongo-1
Mongoose node: mongo-1, 172.17.0.5:5222
Trying 172.17.0.5...
Connected to 172.17.0.5.
Escape character is '^]'.
z
<?xml version='1.0'?><stream:stream xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' id='CB94EBB01F892081' from='localhost' version='1.0'><stream:error><xml-not-well-formed xmlns='urn:ietf:params:xml:ns:xmpp-streams'/></stream:error></stream:stream>Connection closed by foreign host.
u@localhost$
```

### Clustering

A necessary prerequisite is to enable name resolution, so that your containers can resolve one another's names to IPs
of containers, or of hosts they are running and exposing their ports on. There is a few ways to approach it, the most
straightforward is set up a common hosts file for a cluster. 

If your containers are running on the same host and share config directory, then create a `./config/hosts` file like:

```
172.17.0.5 mongo-1
172.17.0.6 mongo-2
```

and restart the containers. Then you can proceed with clustering as you normally would:

```
./mongooseimctl mongo-2 join_cluster mongooseim@mongo-1
```

Check if it works:

```
u@localhost$ ./mongooseimctl mongo-1 mnesia running_db_nodes
['mongooseim@mongo-2','mongooseim@mongo-1']
u@localhost$
'''

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

