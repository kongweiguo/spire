IMG_AGENT := cr-cn-beijing.volces.com/will/spire-agent:v1.7.1
IMG_SERVER := cr-cn-beijing.volces.com/will/spire-server:v1.7.1

IMG_BASE := spire-base:latest
IMG_BUILDER := spire-builder:latest

PLATFORM ?= linux/amd64
go_version_full := $(shell cat .go-version)
go_version := $(go_version_full:.0=)
go_dir := $(build_dir)/go/$(go_version)

.PHONY: default all
default: build
all: build

############################################################################
# RUN SPIRE Server
############################################################################

.PHONY: run
run:
	go run cmd/spire-server/main.go run -config=config/server/conf/server.conf

############################################################################
# Determine go flags
############################################################################

# Flags passed to all invocations of go test
go_test_flags := -timeout=60s

go_flags :=
ifneq ($(GOPARALLEL),)
	go_flags += -p=$(GOPARALLEL)
endif

ifneq ($(GOVERBOSE),)
	go_flags += -v
endif

# Determine the ldflags passed to the go linker.
go_ldflags := -s -w
#############################################################################
# Build Targets
#############################################################################

.PHONY: build
build: bin/spire-server bin/spire-agent #plugins

define binary_rule
.PHONY: $1
$1: | bin/
	@echo Building $1...
	go build $$(go_flags) -ldflags '$$(go_ldflags)' -o $1 $2
endef

# main SPIRE binaries
$(eval $(call binary_rule,bin/spire-server,./cmd/spire-server))
$(eval $(call binary_rule,bin/spire-agent,./cmd/spire-agent))


.PHONY: bin/
bin/:
	@mkdir -p $@

#############################################################################
# Build Plugins
#############################################################################

# .PHONY: plugins
# plugins: bin/agent-spire-psat bin/server-spire-psat bin/server-spire-upstreamauthority bin/server-spire-keymanager bin/spire-k8s-workload-registrar

# # plugins binaries
# $(eval $(call binary_rule,bin/server-spire-upstreamauthority,./cmd/plugins/upstreamauthority/server))
# $(eval $(call binary_rule,bin/server-spire-keymanager,./cmd/plugins/keymanager/server))
# $(eval $(call binary_rule,bin/server-spire-psat,./cmd/plugins/cispsat/server))
# $(eval $(call binary_rule,bin/agent-spire-psat,./cmd/plugins/cispsat/agent))
# $(eval $(call binary_rule,bin/spire-k8s-workload-registrar,./cmd/plugins/spire-k8s-workload-registrar))

#############################################################################
# Docker Images
#############################################################################
.PHONY: images-dep
images-dep: spire-builder-image spire-base-image

define image_rule_dep
.PHONY: $1
$1: $3
	echo Building docker image $2 ...
	docker build \
		--build-arg goversion=$(go_version_full) \
		--build-arg  PLATFORM=${PLATFORM} \
		--target $2 \
		-t $4 \
		-f $3 \
		.
endef

$(eval $(call image_rule_dep,spire-builder-image,spire-builder,Dockerfile.builder,$(IMG_BUILDER)))
$(eval $(call image_rule_dep,spire-base-image,spire-base,Dockerfile.base,$(IMG_BASE)))


.PHONY: images 
images: spire-server-image spire-agent-image

define image_rule
.PHONY: $1
$1: $3
	echo Building docker image $2 ...
	docker build \
		--build-arg  goversion=$(go_version_full) \
		--build-arg  PLATFORM=${PLATFORM} \
		--build-arg  BUILDER=${IMG_BUILDER} \
		--build-arg  BASE=${IMG_BASE} \
		--target $2 \
		-t $4 \
		-f $3 \
		.
endef

$(eval $(call image_rule,spire-agent-image,spire-agent,Dockerfile.agent,$(IMG_AGENT)))
$(eval $(call image_rule,spire-server-image,spire-server,Dockerfile.server,$(IMG_SERVER)))

.PHONY: push-images
push-images:
	docker push $(IMG_AGENT)
	docker push $(IMG_SERVER)


# .PHONY: images-buildx
# images-buildx: server-image-buildx agent-image-buildx

# .PHONY: container-builder
# container-builder:
# 	docker buildx create --platform $(PLATFORMS) --name container-builder --node container-builder0 --use

# define image_rule_buildx
# .PHONY: $1
# $1: $3 container-builder
# 	echo Building docker image $2 $(PLATFORMS)…
# 	docker buildx build \
# 		--platform $(PLATFORMS) \
# 		--build-arg GOVERSION=$(GO_VERSION_FULL) \
# 		--target $2 \
# 		-t $4 \
# 		-f $3 \
# 		--load \
# 		.

# endef

# $(eval $(call image_rule_buildx,agent-image-buildx,spire-agent,Dockerfile,$(IMG_SPIRE_AGENT)))
# $(eval $(call image_rule_buildx,server-image-buildx,spire-server,Dockerfile,$(IMG_SPIRE_SERVER)))
