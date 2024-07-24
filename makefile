# VARS
SHELL := /bin/bash
DOMAIN ?= crucible.dev
ADMIN_PASS ?= Tartans@1


generate_certs:
	./scripts/generate_certs.sh	crucible.dev -loglevel 3

clean:
	rm -rf ./dist && \
	rm -rf ./cache
	rm -rf ./packer/output

.PHONY: all clean

all: generate_certs