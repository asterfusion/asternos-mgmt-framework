################################################################################
#                                                                              #
#  Copyright 2019 Broadcom. The term Broadcom refers to Broadcom Inc. and/or   #
#  its subsidiaries.                                                           #
#                                                                              #
#  Licensed under the Apache License, Version 2.0 (the "License");             #
#  you may not use this file except in compliance with the License.            #
#  You may obtain a copy of the License at                                     #
#                                                                              #
#     http://www.apache.org/licenses/LICENSE-2.0                               #
#                                                                              #
#  Unless required by applicable law or agreed to in writing, software         #
#  distributed under the License is distributed on an "AS IS" BASIS,           #
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.    #
#  See the License for the specific language governing permissions and         #
#  limitations under the License.                                              #
#                                                                              #
################################################################################

.PHONY: all clean cleanall codegen rest-server rest-clean yamlGen cli

TOPDIR := $(abspath .)
BUILD_DIR := $(TOPDIR)/build
export TOPDIR

ifeq ($(BUILD_GOPATH),)
export BUILD_GOPATH=$(TOPDIR)/gopkgs
endif

export GOPATH=$(BUILD_GOPATH):$(TOPDIR)

ifeq ($(GO),)
GO := /usr/local/go/bin/go 
export GO
endif

INSTALL := /usr/bin/install

MAIN_TARGET = sonic-mgmt-framework_1.0-01_amd64.deb

GO_DEPS_LIST = github.com/gorilla/mux \
               github.com/Workiva/go-datastructures/queue \
               github.com/go-redis/redis \
               github.com/golang/glog \
               github.com/pkg/profile \
               gopkg.in/go-playground/validator.v9 \
               golang.org/x/crypto/ssh \
               github.com/antchfx/jsonquery \
               github.com/antchfx/xmlquery \
               github.com/facette/natsort \
               github.com/philopon/go-toposort

# GO_DEPS_LIST_2 includes "download only" dependencies.
# They are patched, compiled and installed explicitly later.
GO_DEPS_LIST_2 = github.com/openconfig/goyang \
                 github.com/openconfig/gnmi/proto/gnmi_ext \
                 github.com/openconfig/ygot/ygot

REST_BIN = $(BUILD_DIR)/rest_server/main
CERTGEN_BIN = $(BUILD_DIR)/rest_server/generate_cert


all: build-deps go-deps go-pkg-version go-patch translib rest-server cli

build-deps:
	mkdir -p $(BUILD_DIR)

go-deps: $(GO_DEPS_LIST) $(GO_DEPS_LIST_2) 

go-pkg-version: go-deps
	cd $(BUILD_GOPATH)/src/github.com/go-redis/redis; git checkout d19aba07b47683ef19378c4a4d43959672b7cec8 2>/dev/null ; true; \
$(GO) install -v -gcflags "-N -l" $(BUILD_GOPATH)/src/github.com/go-redis/redis; \
cd $(BUILD_GOPATH)/src/github.com/gorilla/mux; git checkout 49c01487a141b49f8ffe06277f3dca3ee80a55fa 2>/dev/null ; true; \
$(GO) install -v -gcflags "-N -l" $(BUILD_GOPATH)/src/github.com/gorilla/mux; \
cd $(BUILD_GOPATH)/src/github.com/Workiva/go-datastructures; git checkout f07cbe3f82ca2fd6e5ab94afce65fe43319f675f 2>/dev/null ; true; \
$(GO) install -v -gcflags "-N -l" $(BUILD_GOPATH)/src/github.com/Workiva/go-datastructures; \
cd $(BUILD_GOPATH)/src/github.com/golang/glog; git checkout 23def4e6c14b4da8ac2ed8007337bc5eb5007998 2>/dev/null ; true; \
$(GO) install -v -gcflags "-N -l" $(BUILD_GOPATH)/src/github.com/golang/glog; \
cd $(BUILD_GOPATH)/src/github.com/pkg/profile; git checkout acd64d450fd45fb2afa41f833f3788c8a7797219 2>/dev/null ; true; \
$(GO) install -v -gcflags "-N -l" $(BUILD_GOPATH)/src/github.com/pkg/profile; \
cd $(BUILD_GOPATH)/src/github.com/antchfx/xmlquery; git checkout 16f1e6cdc5fe44a7f8e2a8c9faf659a1b3a8fd9b 2>/dev/null ; true; \
$(GO) install -v -gcflags "-N -l" $(BUILD_GOPATH)/src/github.com/antchfx/xmlquery; \
cd $(BUILD_GOPATH)/src/github.com/facette/natsort; git checkout 2cd4dd1e2dcba4d85d6d3ead4adf4cfd2b70caf2 2>/dev/null ; true; \
$(GO) install -v -gcflags "-N -l" $(BUILD_GOPATH)/src/github.com/facette/natsort; \
cd $(BUILD_GOPATH)/src/github.com/philopon/go-toposort; git checkout 9be86dbd762f98b5b9a4eca110a3f40ef31d0375 2>/dev/null ; true; \
$(GO) install -v -gcflags "-N -l" $(BUILD_GOPATH)/src/github.com/philopon/go-toposort; \
cd $(BUILD_GOPATH)/src/github.com/openconfig/gnmi/proto/gnmi_ext; git checkout e7106f7f5493a9fa152d28ab314f2cc734244ed8 2>/dev/null ; true; \
$(GO) install -v -gcflags "-N -l" $(BUILD_GOPATH)/src/github.com/openconfig/gnmi/proto/gnmi_ext

$(GO_DEPS_LIST):
	$(GO) get -v $@

$(GO_DEPS_LIST_2):
	$(GO) get -v -d $@

cli: rest-server
	$(MAKE) -C src/CLI

cvl: go-deps go-patch go-pkg-version
	$(MAKE) -C src/cvl
	$(MAKE) -C src/cvl/schema
	$(MAKE) -C src/cvl/testdata/schema

cvl-test:
	$(MAKE) -C src/cvl gotest

rest-server: translib
	$(MAKE) -C src/rest

rest-clean:
	$(MAKE) -C src/rest clean

translib: cvl
	$(MAKE) -C src/translib

codegen:
	$(MAKE) -C models

yamlGen:
	$(MAKE) -C models/yang
	$(MAKE) -C models/yang/sonic

go-patch: go-deps
	cd $(BUILD_GOPATH)/src/github.com/openconfig/ygot/; git reset --hard HEAD; git clean -f -d; git checkout 724a6b18a9224343ef04fe49199dfb6020ce132a 2>/dev/null ; true; \
cd ../; cp $(TOPDIR)/ygot-modified-files/ygot.patch .; \
patch -p1 < ygot.patch; rm -f ygot.patch; \
$(GO) install -v -gcflags "-N -l" $(BUILD_GOPATH)/src/github.com/openconfig/ygot/ygot; \
        cd $(BUILD_GOPATH)/src/github.com/openconfig/goyang/; git reset --hard HEAD; git clean -f -d; git checkout 064f9690516f4f72db189f4690b84622c13b7296 >/dev/null ; true; \
	cp $(TOPDIR)/goyang-modified-files/goyang.patch .; \
	patch -p1 < goyang.patch; rm -f goyang.patch; \
	$(GO) install -v -gcflags "-N -l" $(BUILD_GOPATH)/src/github.com/openconfig/goyang; \
	cd $(BUILD_GOPATH)/src/github.com/antchfx/jsonquery; git reset --hard HEAD; \
	git checkout 3535127d6ca5885dbf650204eb08eabf8374a274 2>/dev/null ; \
	git apply $(TOPDIR)/patches/jsonquery.patch; \
	$(GO) install -v -gcflags "-N -l" $(BUILD_GOPATH)/src/github.com/antchfx/jsonquery

install:
	$(INSTALL) -D $(REST_BIN) $(DESTDIR)/usr/sbin/rest_server
	$(INSTALL) -D $(CERTGEN_BIN) $(DESTDIR)/usr/sbin/generate_cert
	$(INSTALL) -d $(DESTDIR)/usr/sbin/schema/
	$(INSTALL) -d $(DESTDIR)/usr/sbin/lib/
	$(INSTALL) -d $(DESTDIR)/usr/models/yang/
	$(INSTALL) -D $(TOPDIR)/models/yang/sonic/*.yang $(DESTDIR)/usr/models/yang/
	$(INSTALL) -D $(TOPDIR)/models/yang/sonic/common/*.yang $(DESTDIR)/usr/models/yang/
	$(INSTALL) -D $(TOPDIR)/src/cvl/schema/*.yin $(DESTDIR)/usr/sbin/schema/
	$(INSTALL) -D $(TOPDIR)/src/cvl/testdata/schema/*.yin $(DESTDIR)/usr/sbin/schema/
	$(INSTALL) -D $(TOPDIR)/models/yang/*.yang $(DESTDIR)/usr/models/yang/
	$(INSTALL) -D $(TOPDIR)/config/transformer/models_list $(DESTDIR)/usr/models/yang/
	$(INSTALL) -D $(TOPDIR)/models/yang/common/*.yang $(DESTDIR)/usr/models/yang/
	$(INSTALL) -D $(TOPDIR)/models/yang/annotations/*.yang $(DESTDIR)/usr/models/yang/
	cp -rf $(TOPDIR)/build/rest_server/dist/ui/ $(DESTDIR)/rest_ui/
	cp -rf $(TOPDIR)/build/cli $(DESTDIR)/usr/sbin/
	cp -rf $(TOPDIR)/build/swagger_client_py/ $(DESTDIR)/usr/sbin/lib/
	cp -rf $(TOPDIR)/src/cvl/conf/cvl_cfg.json $(DESTDIR)/usr/sbin/cvl_cfg.json

ifeq ($(SONIC_COVERAGE_ON),y)
	echo "" > $(DESTDIR)/usr/sbin/.test
endif

$(addprefix $(DEST)/, $(MAIN_TARGET)): $(DEST)/% :
	mv $* $(DEST)/

clean: rest-clean
	$(MAKE) -C src/cvl clean
	$(MAKE) -C src/translib clean
	$(MAKE) -C src/cvl/schema clean
	$(MAKE) -C src/cvl cleanall
	rm -rf build/*
	rm -rf debian/.debhelper
	rm -rf $(BUILD_GOPATH)/src/github.com/openconfig/goyang/annotate.go

cleanall:
	$(MAKE) -C src/cvl cleanall
	rm -rf build/*
