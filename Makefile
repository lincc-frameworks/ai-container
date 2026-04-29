SHELL := /usr/bin/env bash
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
REPO_ROOT := $(abspath $(ROOT_DIR)/)
BUILD_DIR := $(ROOT_DIR)/build
IMAGE := $(BUILD_DIR)/rubin-ai.sif
DEF := $(ROOT_DIR)/Apptainer.def
PACKED_FILES := $(wildcard $(ROOT_DIR)/container-scripts/*)
OVERLAY := $(BUILD_DIR)/overlay.img
# 16 GB overlay
OVERLAY_SIZE_MB ?= 16384

.PHONY: build shell shell-raw rebuild clean inspect exec

build: $(IMAGE) $(OVERLAY)

$(IMAGE): $(DEF) $(PACKED_FILES)
	mkdir -p "$(BUILD_DIR)"
	cd "$(REPO_ROOT)" && \
	  n=0; until [ $$n -ge 3 ]; do \
	    apptainer build "$(IMAGE)" "$(DEF)" && break; \
	    n=$$((n+1)); \
	    echo "apptainer build failed (attempt $$n/3), retrying in 10s..." >&2; \
	    sleep 10; \
	  done; \
	  [ $$n -lt 3 ]

$(OVERLAY):
	mkdir -p "$(BUILD_DIR)"
	apptainer overlay create --size "$(OVERLAY_SIZE_MB)" "$(OVERLAY)"

shell:
	RUBIN_RAW_SHELL=0 "$(ROOT_DIR)/run.sh"

shell-raw:
	RUBIN_RAW_SHELL=1 "$(ROOT_DIR)/run.sh"

exec:
	@if [[ -z "$(CMD)" ]]; then echo "Usage: make -C container exec CMD='python --version'"; exit 1; fi
	"$(ROOT_DIR)/run.sh" $(CMD)

inspect:
	apptainer inspect "$(IMAGE)"

rebuild: clean build

clean:
	rm -f "$(IMAGE)" "$(OVERLAY)"
