.PHONY: builder builder.build builder.create builder.start

PROJECT ?= test
BUILDER ?= ${PROJECT}-builder
VOLUMES ?= $(shell pwd)/examples

builder: builder.build builder.create builder.start

builder.build:
	docker build -f Dockerfile.builder -t ${BUILDER} .

builder.create:
	docker create --name ${BUILDER} -h ${BUILDER} \
		-v ${VOLUMES}/builds:/builds ${BUILDER}

builder.start:
	docker start ${BUILDER}

builder.shell:
	docker exec -it ${BUILDER} bash

builder.destroy:
	-docker stop ${BUILDER}
	-docker rm ${BUILDER}
