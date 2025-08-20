TOP ?= $(shell git rev-parse --show-toplevel)

# Settings for docker image
DOCKER_PLATFORM ?=
USE_LOCAL_CREDENTIALS ?=

# Supported platforms
ALL_PLATFORMS := $(subst Dockerfile.,,$(wildcard Dockerfile.*))
ifneq ($(filter $(DOCKER_PLATFORM),$(ALL_PLATFORMS)),$(DOCKER_PLATFORM))
$(error DOCKER_PLATFORM "$(DOCKER_PLATFORM)" is invalid. Allowed values: $(ALL_PLATFORMS)")
endif

docker-run: ## mounts as a docker container
docker-run: run-$(DOCKER_PLATFORM)
run-%: build-%
	@$(eval CONTAINER_NAME := $(notdir $(TOP)))
	@$(eval CONTAINER_NAME := $(notdir $(TOP)))
	@$(eval DOCKER_WORKMNT := $(TOP):/work/$(CONTAINER_NAME))
	@$(eval DOCKER_WORKVOL := --volume=$(DOCKER_WORKMNT))
	@$(eval DOCKER_RUNARGS += $(if $(USE_LOCAL_CREDENTIALS),--volume=$(DOCKER_WORKMNT),))
	@$(eval DOCKER_RUNARGS += $(if $(USE_LOCAL_CREDENTIALS),--network=host,))
	@docker run $(DOCKER_RUNARGS) -it $(CONTAINER_NAME)

docker-build: ## creates a docker image
docker-build: build-$(DOCKER_PLATFORM)
build-%: Dockerfile.% entrypoint.%.sh requirements.txt
	@$(eval CONTAINER_NAME := $(notdir $(TOP)))
	@$(eval USER_NAME      := $(if $(USE_LOCAL_CREDENTIALS),$(USER),build))
	@$(eval USER_ID        := $(if $(USE_LOCAL_CREDENTIALS),$(shell id -u),1234))
	@$(eval GROUP_NAME     := $(if $(USE_LOCAL_CREDENTIALS),$(USER),build))
	@$(eval GROUP_ID       := $(if $(USE_LOCAL_CREDENTIALS),$(shell id -g),5678))
	@$(eval OTHER_GROUPS   := $(if $(USE_LOCAL_CREDENTIALS),$(shell id --groups),))
	@docker build . -f $< \
		--progress=plain --network=host \
		--build-arg BUILDKIT_INLINE_CACHE=1 --cache-from $(CONTAINER_NAME) \
		--build-arg USER_NAME="$(USER_NAME)" \
		--build-arg USER_ID="$(USER_ID)" \
		--build-arg GROUP_NAME="$(GROUP_NAME)" \
		--build-arg GROUP_ID="$(GROUP_ID)" \
		--build-arg OTHER_GROUPS="$(OTHER_GROUPS)" \
		-t $(CONTAINER_NAME)

