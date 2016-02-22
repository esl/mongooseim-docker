.PHONY: builder builder.build builder.create builder.start

PROJECT 	?= test
VOLUMES 	?= $(shell pwd)/examples
BUILDS 		?= ${VOLUMES}/builds
BUILDER 	?= ${PROJECT}-builder
HAPROXY 	?= ${PROJECT}-haproxy
MEMBER  	?= ${PROJECT}-mongooseim
GRAPHITE    ?= ${PROJECT}-graphite
GRAPHITE_DATA ?= ${PROJECT}-graphite-data
MEMBER_BASE     ?= ${PROJECT}-mongooseim
MEMBER_TGZ      ?= mongooseim-esl-34097d5-2015-11-09_135646.tar.gz
DNS	        = ${PROJECT}-resolvable
DNS_IP	        = $(shell echo ${DNS} | ./docker-to-hosts-line | cut -d' ' -f1)
# Public
#

builder: builder.build builder.create builder.start

builder.destroy:
	-docker stop ${BUILDER}
	-docker rm ${BUILDER}

# TODO: unfinished!
#cluster-2:
#    make ${MEMBER}-1
#    make ${MEMBER}-2

#cluster-2.destroy:
#    make member.destroy MEMBER=${MEMBER}-1
#    make member.destroy MEMBER=${MEMBER}-2

#
# Private
#
dns.create:
	docker create --hostname ${DNS} --name ${DNS} \
        -v /var/run/docker.sock:/tmp/docker.sock mgood/resolvable
dns.start:
	docker start ${DNS}

dns.ip:
	@echo ${DNS_IP}

builder.build:
	docker build -f Dockerfile.builder -t ${BUILDER} .

builder.create:
	docker create --name ${BUILDER} -h ${BUILDER} \
		-v ${VOLUMES}/builds:/builds ${BUILDER}

builder.start:
	docker start ${BUILDER}

builder.shell:
	docker exec -it ${BUILDER} bash

# MEMBER here is like test-mongooseim, i.e. no numeric suffix
member.build:
	docker build -f Dockerfile.member -t ${MEMBER_BASE} .

# TODO: temporary
# MEMBER here is like test-mongooseim-1, test-mongooseim-2, ...
member.create:
	-mkdir -p ${VOLUMES}/${MEMBER}
	-rm -rf ${VOLUMES}/${MEMBER}/mongooseim/Mnesia*
	cp ${BUILDS}/${MEMBER_TGZ} ${VOLUMES}/${MEMBER}/mongooseim.tar.gz
	docker create --name ${MEMBER} -h ${MEMBER} -P -t \
		-v ${VOLUMES}/${MEMBER}:/member \
		--dns=${DNS_IP} --dns-search=. \
		${MEMBER_BASE}
	#./generate-hosts ${PROJECT} > ${VOLUMES}/${MEMBER}/hosts
	docker start ${MEMBER}

# TODO: unfinished!
# MEMBER here is like test-mongooseim-1, test-mongooseim-2, ...
#member.create:
#    docker create --name ${MEMBER} -h ${MEMBER} \
#        -v ${VOLUMES}/${MEMBER}:/member \
#        ${MEMBER_BASE}

# MEMBER here is like test-mongooseim-1, test-mongooseim-2, ...

member.start:
	docker start ${MEMBER}

# MEMBER here is like test-mongooseim-1, test-mongooseim-2, ...
member.destroy:
	-docker stop ${MEMBER}
	-docker rm ${MEMBER}

haproxy.build:
	docker build -f Dockerfile.haproxy -t ${HAPROXY} .

haproxy.create:
	docker create --name ${HAPROXY} -h ${HAPROXY} -p 5222:5222 -p 9000:9000 -t \
		--dns=${DNS_IP} --dns-search=. \
		${HAPROXY}
	docker start ${HAPROXY}

graphite.build:
	docker build -f Dockerfile.graphite -t ${GRAPHITE} .

graphite.create:
	docker create \
		--name ${GRAPHITE} -h ${GRAPHITE} \
		-p 8080:80 \
		-p 2003-2004:2003-2004 \
		-p 2023-2024:2023-2024 \
		-p 8125:8125/udp \
		-p 8126:8126 \
		-v ${GRAPHITE_DATA}:/opt/graphite/storage \
		--dns=${DNS_IP} --dns-search=. \
		${GRAPHITE}
	docker start ${GRAPHITE}

graphite.start:
	docker start ${GRAPHITE}
