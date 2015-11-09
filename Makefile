.PHONY: builder builder.build builder.create builder.start

PROJECT 	?= test
BUILDER 	?= ${PROJECT}-builder
MEMBER  	?= ${PROJECT}-mongooseim
MEMBER_BASE ?= ${PROJECT}-mongooseim
VOLUMES 	?= $(shell pwd)/examples

#
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

cluster-2.destroy:
	make member.destroy MEMBER=${MEMBER}-1
	make member.destroy MEMBER=${MEMBER}-2

#
# Private
#

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
	docker build -f Dockerfile.member -t ${MEMBER} .

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
