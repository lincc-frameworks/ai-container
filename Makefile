SHELL := /usr/bin/env bash
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
REPO_ROOT := $(abspath $(ROOT_DIR)/..)
BUILD_DIR := $(ROOT_DIR)/build
IMAGE := $(BUILD_DIR)/rubin-ai.sif
DEF := $(ROOT_DIR)/Apptainer.def
OVERLAY := $(BUILD_DIR)/overlay.img
OVERLAY_SIZE_MB ?= 16384

.PHONY: build overlay shell shell-raw rebuild clean inspect exec

build:
	mkdir -p "$(BUILD_DIR)"
	cd "$(REPO_ROOT)" && \
	  n=0; until [ $$n -ge 3 ]; do \
	    apptainer build "$(IMAGE)" "$(DEF)" && break; \
	    n=$$((n+1)); \
	    echo "apptainer build failed (attempt $$n/3), retrying in 10s..." >&2; \
	    sleep 10; \
	  done; \
	  [ $$n -lt 3 ]
	$(MAKE) overlay

overlay:
	mkdir -p "$(BUILD_DIR)"
	if [[ ! -f "$(OVERLAY)" ]]; then apptainer overlay create --size "$(OVERLAY_SIZE_MB)" "$(OVERLAY)"; fi

shell:
	RUBIN_RAW_SHELL=0 "$(ROOT_DIR)/scripts/run.sh"

shell-raw:
	RUBIN_RAW_SHELL=1 "$(ROOT_DIR)/scripts/run.sh"

exec:
	@if [[ -z "$(CMD)" ]]; then echo "Usage: make -C container exec CMD='python --version'"; exit 1; fi
	"$(ROOT_DIR)/scripts/run.sh" $(CMD)

inspect:
	apptainer inspect "$(IMAGE)"

rebuild: clean build

clean:
	rm -f "$(IMAGE)" "$(OVERLAY)"
