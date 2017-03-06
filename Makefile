.PHONY: builder builder.build builder.create builder.start

PROJECT 	?= test
VOLUMES 	?= $(shell pwd)/examples
BUILDS 		?= ${VOLUMES}/builds
BUILDER 	?= ${PROJECT}-builder
BUILDER_IMAGE   ?= mongooseim/mongooseim-builder:latest
MEMBER  	?= ${PROJECT}-mongooseim
MEMBER_BASE     ?= ${PROJECT}-mongooseim
# Public
#

builder: builder.start

builder.destroy:
	-docker stop ${BUILDER}
	-docker rm ${BUILDER}

builder.build:
	docker build -f Dockerfile.builder -t ${BUILDER} .

builder.create:
	docker create --name ${BUILDER} -h ${BUILDER} \
		-v ${VOLUMES}/builds:/builds ${BUILDER_IMAGE}

builder.start:
	docker start ${BUILDER}

builder.shell:
	docker exec -it ${BUILDER} bash

# MEMBER here is like test-mongooseim, i.e. no numeric suffix
member.build:
	cp ${BUILDS}/${MEMBER_TGZ} member/mongooseim.tar.gz
	docker build -f Dockerfile.member -t ${MEMBER_BASE} .

# TODO: temporary
# MEMBER here is like test-mongooseim-1, test-mongooseim-2, ...
member.create:
	-mkdir -p ${VOLUMES}/${MEMBER}
	-rm -rf ${VOLUMES}/${MEMBER}/mongooseim/Mnesia*
	docker create --name ${MEMBER} -h ${MEMBER} -P -t \
		-v ${VOLUMES}/${MEMBER}:/member \
		${MEMBER_BASE}
	docker start ${MEMBER}

member.start:
	docker start ${MEMBER}

# MEMBER here is like test-mongooseim-1, test-mongooseim-2, ...
member.destroy:
	-docker stop ${MEMBER}
	-docker rm ${MEMBER}

