.PHONY: builder builder.build builder.create builder.start

PROJECT ?= test
BUILDER ?= ${PROJECT}-builder
VOLUMES ?= $(shell pwd)/examples

builder: builder.build builder.create builder.start

builder.build:
	docker build -f Dockerfile.builder -t mongooseim-builder .

builder.create:
	docker create --name ${BUILDER} -h ${BUILDER} \
		-v ${VOLUMES}/builds:/builds mongooseim-builder

builder.start:
	docker start ${BUILDER}

builder.shell:
	docker exec -it ${BUILDER} bash
