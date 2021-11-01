# -*- mode: makefile -*-

#
# Usage notes:
#
# Most commonly building will look something like this instantiation
#
#   make build BUILD_OPTIONS=--fakeroot GIT_DIRTY=
#
# That relies on Singularity being a symlink to "latest" versioned recipe file, to build a specific version
#
#  make build BUILD_OPTIONS=--fakeroot GIT_DIRTY= RECIPE_FILE=Singularity.0.0.999
#
# Other targets include `dist`, `install` and `symlinks`, where dist builds an installable tar.gz, install
# installs and symlinks creates the symlinks to the built image. `install` uses the `PREFIX` variable as a
# method to pass the install location (default = /opt/singularity) e.g.
#
#  make install PREFIX=/software/bioinformatics/example-0.0.999
#
# Maintainer notes:
#
# Add any source files that the build depends on to SOURCE_DEPS - these will commonly be in
# %files section of the recipe file


PREFIX=/opt/singularity
RECIPE_FILE=Singularity

GIT_TOPLEVEL=$(shell git rev-parse --show-toplevel)
GIT_DIRTY=$(shell git status --porcelain)

RECIPE_FILE_TARGET=$(shell readlink $(RECIPE_FILE))
IMAGE_NAME=$(shell basename $(GIT_TOPLEVEL) -srf)
ifeq ($(RECIPE_FILE_TARGET),)
    IMAGE_VERSION=$(shell echo $(RECIPE_FILE) | sed -e 's/Singularity\.//')
else
    IMAGE_VERSION=$(shell echo $(RECIPE_FILE_TARGET) | sed -e 's/Singularity\.//')
endif
IMAGE_FILE=$(IMAGE_NAME)-$(IMAGE_VERSION).sif

# Building options - generally pass like:  make image BUILD_OPTIONS=--fakeroot
BUILD_OPTIONS=
LOCAL_IMAGE_DEPS=
LOCAL_IMAGE_TARGET=.local-images
SOURCE_DEPS=

# How to create symlinks - delete as appropriate
#SYMLINK_COMMAND=ln -sf $(IMAGE_FILE) name-of-app
#SYMLINK_COMMAND=singularity inspect --list-apps $(IMAGE_FILE) | xargs -n1 ln -sf $(IMAGE_FILE)
SYMLINK_COMMAND=singularity exec $(IMAGE_FILE) /opt/app-commands | xargs -n1 ln -sf $(IMAGE_FILE)

.PHONY: all run symlinks clean build install
all: build

run: clean build

symlinks: $(IMAGE_FILE)
	@$(SYMLINK_COMMAND)

clean:
	@rm -rf $(IMAGE_FILE)

$(IMAGE_FILE): $(RECIPE_FILE) $(SOURCE_DEPS) $(LOCAL_IMAGE_TARGET)
	@echo Will build $(IMAGE_FILE) from $(RECIPE_FILE)
	@singularity build $(BUILD_OPTIONS) $(IMAGE_FILE) $(RECIPE_FILE)

# LOCAL_RECIPE_FILE is actually the version.
# use rev and cut to reliably get the last part
# add more fields to retain any rogue - separators in version i.e. cut -d- -f1,2,3,4,5
$(LOCAL_IMAGE_DEPS): LOCAL_RECIPE_FILE=$(shell grep "^From: $@/" $(RECIPE_FILE) | cut -d' ' -f2 | xargs -I{} basename {} .sif | rev | cut -d- -f1 | rev)
$(LOCAL_IMAGE_DEPS):
	@$(MAKE) -C $@ build RECIPE_FILE=Singularity.$(LOCAL_RECIPE_FILE)

$(LOCAL_IMAGE_TARGET): $(LOCAL_IMAGE_DEPS)
	@ls -td $? | head -n 1 | xargs -I{} touch -r {} $@

build: $(IMAGE_FILE)

install: build
	@install -d $(PREFIX)/bin/
	@install $(IMAGE_FILE) $(PREFIX)/bin/
	@cd $(PREFIX)/bin/ && $(SYMLINK_COMMAND)

dist: NAME_VERSION=$(IMAGE_NAME)-$(IMAGE_VERSION)
dist: build
	@make install PREFIX=$(NAME_VERSION)
	@tar -zcf $(NAME_VERSION).tar.gz $(NAME_VERSION)
	@rm -rf $(NAME_VERSION)
