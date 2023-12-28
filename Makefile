SHELL := /bin/bash
PWD = $(shell pwd)

clean:
	@source makescript.sh; clean "$(PWD)"

reset:
	@source makescript.sh; clean "$(PWD)" "all"

fetch: clean
	@source makescript.sh; fetch_source_image "$(PWD)"

build: fetch
	@source makescript.sh; build "$(PWD)"

DOCKER_CTX_build_image:
	@source makescript.sh; build_image

test:
	@source test/all.sh; run_all_tests "$(PWD)"

.PHONY: build test