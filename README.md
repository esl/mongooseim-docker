# mongooseim-docker

MongooseIM is Erlang Solutions' robust and efficient XMPP server aimed at large installations.
Specifically designed for enterprise purposes,
it is fault-tolerant, can utilize resources of multiple clustered machines and easily scale in need of more capacity (by just adding a box/VM).
Its home at GitHub is http://github.com/esl/MongooseIM.

## Quick start guide

The docker images for [MongooseIM](https://github.com/esl/MongooseIM) are available at
[hub.docker.com](https://hub.docker.com/r/erlangsolutions/mongooseim/).
You only need this repo if you want to build a custom image.

The `./build.sh` script is a good starting point, because it automatically performs the whole build procedure.
Individual build steps are described below.

### Building a MongooseIM tarball

In order to build the MongooseIM tarball, a builder image and container need to be created.
You can create an image by running the following command:

```bash
docker build -f Dockerfile.builder -t mongooseim-builder .
```

After that you can run the builder container.
It's important to mount the container's `/builds` directory as a volume, because the MongooseIM tarball will be placed there after the build.
For simplicity it's assumed that the environment variable `VOLUMES` is exported and set to an existing absolute path, e.g. `pwd`.

```bash
docker run --rm --name mongooseim-builder -h mongooseim-builder -e TARBALL_NAME=mongooseim \
       -v ${VOLUMES}/builds:/builds mongooseim-builder
```

`${VOLUMES}/builds` will contain a `build.log` file with logs
and, if the build is successful, the resulting tarball: `mongooseim-${ARCH}.tar.gz`,
where `${ARCH}` is the target architecture.

#### Modifying Erlang/OTP version

You can modify which Erlang/OTP version is used by MongooseIM when creating a builder image by overriding the `OTP_VSN` argument defined in `Dockerfile.builder`.

```bash
docker build --build-arg OTP_VSN=26.1.2 -f Dockerfile.builder -t mongooseim-builder .
```

#### Building a custom version

Should you need to build a custom version of MongooseIM, you can run the builder container in the interactive mode:

```bash
docker run -it --rm --name mongooseim-builder -h mongooseim-builder -e TARBALL_NAME=mongooseim \
       -v ${VOLUMES}/builds:/builds mongooseim-builder bash
```

Now you can execute `/build.sh` with additional arguments.
This command will by default build MongooseIM's master branch from: https://github.com/esl/MongooseIM.
This can be changed by specifying a parameter to the `build.sh` command:

```bash
/build.sh project_name repo commit
```

* `project_name` - friendly name for the build

* `commit` - commit or branch or tag - what to checkout?

* `repo` - where to checkout from

In order to build a specific commit, following command can be used:

```bash
/build.sh MongooseIM https://github.com/esl/MongooseIM a37c196
```

When building a private project, set up your git credentials before running the build command.

### Creating MongooseIM containers

In order to build the image, the MongooseIM tarball has to be copied to the `member` directory:

```bash
cp builds/mongooseim-${ARCH}.tar.gz ./member/
```

The image can now be build from `Dockerfile.member`:

```bash
docker build -f Dockerfile.member -t mongooseim .
```

### Running MongooseIM

The member container can be created and started with the following command:

```bash
docker run -dtP -h mongooseim-1 --name mongooseim-1 mongooseim
```

You can check that `docker logs mongooseim-1` shows something similar to:

```
...
MongooseIM cluster primary node mongooseim@mongooseim-1
Clustered mongooseim@mongooseim-1 with mongooseim@mongooseim-1
Root: /usr/lib/mongooseim
Exec: /usr/lib/mongooseim/erts-13.1.5/bin/erlexec -boot /usr/lib/mongooseim/releases/6.1.0/start -embedded -config /usr/lib/mongooseim/etc/app.config -args_file /usr/lib/mongooseim/etc/vm.args -args_file /usr/lib/mongooseim/etc/vm.dist.args -- live --noshell -noinput +Bd
when=2023-10-24T14:28:03.386139+00:00 level=warning what=report_transparency pid=<0.574.0> at=service_mongoose_system_metrics:report_transparency/1:175 text="We are gathering the MongooseIM system's metrics to analyse the trends and needs of our users, improve MongooseIM, and know where to focus our efforts. For more info on how to customise, read, enable, and disable these metrics visit: \
- MongooseIM docs - \
      https://esl.github.io/MongooseDocs/latest/operation-and-maintenance/System-Metrics-Privacy-Policy/ \
- MongooseIM GitHub page - https://github.com/esl/MongooseIM \
The last sent report is also written to a file log/system_metrics_report.json" report_filename=log/system_metrics_report.json
```

We can health-check the MongooseIM node with `telnet`.
To do that, you need to provide the IP of the container (usually 127.0.0.1) and the published TCP port which translates to container’s port 5222.
In order to find the port you can use the following docker command:

```
$ docker ps -f "name=mongooseim-1" --format "{{.Names}}: {{.Ports}}"
mongooseim-1: 0.0.0.0:32772->4369/tcp, 0.0.0.0:32771->5222/tcp, 0.0.0.0:32770->5269/tcp, 0.0.0.0:32769->5280/tcp, 0.0.0.0:32768->9100/tcp
```

In the example above you can see that port 5222 inside the container was published on port 32771 on the docker host machine.
It can be used to check if the server is really listening on that port:

```
$ telnet 127.0.0.1 32771
Connected to localhost.
Escape character is '^]'.
```

Success! MongooseIM is accepting XMPP connections.

## Customising the configuration

You can override the default configuration files by providing them using docker volumes. Let's assume on the local machine there is directory `mongooseim-1` with the following content:

```bash
$ tree mongooseim-1
mongooseim-1
└── mongooseim.toml
└── app.config
└── vm.args
```

Now we can run the container:

```bash
docker run -dt -h mongooseim-1 --name mongooseim-1 -p 5222:5222 -v `pwd`/mongooseim-1:/member mongooseim
```

The server will use the customised configuration files.
There is also a `vm.dist.args` file which can be overwritten in the same way.

## Setting up a cluster

There are two methods of clustering: the default, automatic one and a method where you have more control over the cluster formation.

### Default clustering

To use default clustering behaviour, your containers need both container names (`--name` option) and host names (`-h` option) with the `-n` suffix,
where `n` are consecutive integers starting with `1` (configurable with `MASTER_ORDINAL` env variable), e.g. `mongooseim-1`, `mongooseim-2` and so on.
Make sure you have started a node with `-${MASTER_ORDINAL}` suffix first (e.g. `-h mongooseim-1` and `--name mongooseim-1`), as all the other nodes will connect to it when joining the cluster.

Few things are important here:

1. The following parameters must be set to the same value if used in docker/docker-compose. The second and all the subsequent containers have the same requirement.

    * `-h` option sets `HOSTNAME` environment variable for the container which in turn sets long hostname of the machine. The [start.sh](https://github.com/esl/mongooseim-docker/blob/bcaa3c17/member/start.sh#L19) script uses it to generate the Erlang node name if `NODE_TYPE=name`.
    If `NODE_TYPE=sname` (default), short hostname will be used instead. If the value provided to `-h` option is already a short hostname, it will be used as is,
    otherwise it will be shortened (longest part that doesn't contain '.' character).
    If you need to make the host part of the node name different from `HOSTNAME` (or use an IP address instead), you can do it with the `NODE_HOST` environment variable, e.g. `-e NODE_HOST=192.168.1.1`.
    * `--name` is required to provide automatic DNS resolution between the containers. See [Docker network documentation](https://docs.docker.com/network/bridge/#differences-between-user-defined-bridges-and-the-default-bridge) page for more details.

1. Format of the host name:

    * Host name of the first container must be in the `${NODE_NAME}-${MASTER_ORDINAL}` format. That allows [start.sh](https://github.com/esl/mongooseim-docker/blob/bcaa3c17/member/start.sh#L75) to identify the primary node of the cluster.
    * All the subsequent containers must follow the `${NODE_NAME}-N` host name format, where `N` > `${MASTER_ORDINAL}`.

#### Example

Create a user-defined bridge network and start two nodes connected to it:
```
docker network create mim
docker run -dt --net mim -h mongooseim-1 --name mongooseim-1 mongooseim
docker run -dt --net mim -h mongooseim-2 --name mongooseim-2 mongooseim
```

The nodes should already form a cluster. Let's check it:

```bash
$ docker exec mongooseim-1 /usr/lib/mongooseim/bin/mongooseimctl mnesia systemInfo --keys '["running_db_nodes"]'
{
  "data" : {
    "mnesia" : {
      "systemInfo" : [
        {
          "result" : [
            "mongooseim@mongooseim-2",
            "mongooseim@mongooseim-1"
          ],
          "key" : "running_db_nodes"
        }
      ]
    }
  }
}
$ docker exec mongooseim-2 /usr/lib/mongooseim/bin/mongooseimctl mnesia systemInfo --keys '["running_db_nodes"]'
{
  "data" : {
    "mnesia" : {
      "systemInfo" : [
        {
          "result" : [
            "mongooseim@mongooseim-1",
            "mongooseim@mongooseim-2"
          ],
          "key" : "running_db_nodes"
        }
      ]
    }
  }
}
```

#### Kubernetes notes

Default clustering may work as part of Kubernetes StatefulSet deployment with only two changes:

* `MASTER_ORDINAL` has to be set to `0` as `StatefulSet` starts counting instances from 0
* `NODE_TYPE` has to be set to `name` (use of long names) as Kubernetes uses FQDN within internal DNS to resolve `pod's` IP address.
  Please note that for `pod` domain to work you have to have headless service running that matches your `StatefulSet`
  (see https://kubernetes.io/docs/concepts/services-networking/service/#headless-services)

### Manual clustering

With the manual clustering method, you need to explicitly specify the name of the node to join the cluster with via the `CLUSTER_WITH` environment variable.
You may also disable clustering during container startup altogether by setting `JOIN_CLUSTER=false` variable (it's set to `true` by default).

#### Examples

Let's try providing a name of the node to join the cluster with manually:

```bash
docker run -dt --net mim -h first-node --name first-node -e JOIN_CLUSTER=false mongooseim
docker run -dt --net mim -h second-node --name second-node -e CLUSTER_WITH=mongooseim@first-node mongooseim
```

The first command starts a node and tells it not to try to join any clusters (as there are no other nodes).
We then tell the second node to join the cluster with the first node.

You can now check that the nodes have formed the cluster:

```bash
$ docker exec first-node /usr/lib/mongooseim/bin/mongooseimctl mnesia systemInfo --keys '["running_db_nodes"]'
{
  "data" : {
    "mnesia" : {
      "systemInfo" : [
        {
          "result" : [
            "mongooseim@second-node",
            "mongooseim@first-node"
          ],
          "key" : "running_db_nodes"
        }
      ]
    }
  }
}
$ docker exec second-node /usr/lib/mongooseim/bin/mongooseimctl mnesia systemInfo --keys '["running_db_nodes"]'
{
  "data" : {
    "mnesia" : {
      "systemInfo" : [
        {
          "result" : [
            "mongooseim@first-node",
            "mongooseim@second-node"
          ],
          "key" : "running_db_nodes"
        }
      ]
    }
  }
}
```

## Database setup

MongooseIM can be integrated with various databases and other external services.
For example, let's run a [PostgreSQL](https://hub.docker.com/_/postgres/) container:

```bash
docker run -d --name mongooseim-postgres --net mim \
       -e POSTGRES_PASSWORD=mongooseim -e POSTGRES_USER=mongooseim \
       -v ${PATH_TO_MONGOOSEIM_PGSQL_FILE}:/docker-entrypoint-initdb.d/pgsql.sql:ro \
       -p 5432:5432 postgres
```

`${PATH_TO_MONGOOSEIM_PGSQL_FILE}` is an absolute path to `priv/pgsql.sql`, which can be found in the MongooseIM repo.

Don't forget to configure the [outgoing connection pools](https://esl.github.io/MongooseDocs/latest/configuration/outgoing-connections/) in `mongooseim.toml` to connect with the services you set up!

### Using CETS

You can use CETS instead of Mnesia - see the [tutorial](https://esl.github.io/MongooseDocs/latest/tutorials/CETS-configure/) for more details.
You will need to start all nodes with `JOIN_CLUSTER=false`.

```bash
docker run -dt --net mim -h mongooseim-1 --name mongooseim-1 -v `pwd`/mongooseim-1:/member -e JOIN_CLUSTER=false mongooseim
docker run -dt --net mim -h mongooseim-2 --name mongooseim-2 -v `pwd`/mongooseim-2:/member -e JOIN_CLUSTER=false mongooseim
```

You can check the CETS status on both nodes to see if the clustering is successful:

```bash
$ docker exec mongooseim-1 /usr/lib/mongooseim/bin/mongooseimctl cets systemInfo
{
  "data" : {
    "cets" : {
      "systemInfo" : {
        (...)
        "availableNodes" : [
          "mongooseim@mongooseim-1",
          "mongooseim@mongooseim-2"
        ]
      }
    }
  }
}

$ docker exec mongooseim-2 /usr/lib/mongooseim/bin/mongooseimctl cets systemInfo
{
  "data" : {
    "cets" : {
      "systemInfo" : {
        (...)
        "availableNodes" : [
          "mongooseim@mongooseim-2",
          "mongooseim@mongooseim-1"
        ]
      }
    }
  }
}
```

---

This work, though it's not reflected in git history, was bootstrapped from  https://github.com/ppikula/MongooseIM-docker/.
