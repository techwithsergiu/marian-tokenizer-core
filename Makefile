# marian-tokenizer-core/Makefile

SHELL := /usr/bin/env bash

# =============================================================================
# Project meta (for humans + CLI)
# =============================================================================

##@meta
## project: marian-tokenizer-core
## language: c++
## outputs:
##   - build/${TARGET}/lib/libmarian_core.${SHARED_EXT}
##   - build/${TARGET}/lib/static/libmarian_core.a
##   - build/include/marian_core.h
##@endmeta

# =============================================================================
# Platform detection
# =============================================================================

UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(OS),Windows_NT)
    DETECTED_OS := windows
else ifneq (,$(findstring MINGW,$(UNAME_S)))
    DETECTED_OS := windows
else ifneq (,$(findstring MSYS,$(UNAME_S)))
    DETECTED_OS := windows
else ifneq (,$(findstring CYGWIN,$(UNAME_S)))
    DETECTED_OS := windows
else ifeq ($(UNAME_S),Linux)
    DETECTED_OS := linux
else ifeq ($(UNAME_S),Darwin)
    DETECTED_OS := darwin
else
    $(error Unsupported OS: $(UNAME_S))
endif

ifeq ($(UNAME_M),x86_64)
    DETECTED_ARCH := amd64
else ifeq ($(UNAME_M),amd64)
    DETECTED_ARCH := amd64
else ifeq ($(UNAME_M),aarch64)
    DETECTED_ARCH := arm64
else ifeq ($(UNAME_M),arm64)
    DETECTED_ARCH := arm64
else
    $(error Unsupported ARCH: $(UNAME_M))
endif

TARGET_OS   ?= $(DETECTED_OS)
TARGET_ARCH ?= $(DETECTED_ARCH)
TARGET      := $(TARGET_OS)_$(TARGET_ARCH)

# =============================================================================
# Dependencies registry (for CLI)
# =============================================================================

##@deps
## name: sentencepiece
## kind: git_submodule
## path: third_party/sentencepiece
## build_script: scripts/build_sentencepiece.sh
## outputs:
##   - deps/sentencepiece/${TARGET}/lib/static/libsentencepiece.a
##   - deps/sentencepiece/${TARGET}/lib/libsentencepiece.so
##   - deps/sentencepiece/${TARGET}/lib/libsentencepiece.dylib
##   - deps/sentencepiece/include/sentencepiece_processor.h
## notes:
##   - windows produces static only; shared is marked as NOT_SUPPORTED
##@enddeps

##@deps
## name: marian-tokenizer-core
## kind: builder
## inputs:
##   - src/marian_core.cc
##   - src/marian_core.h
##   - third_party/nlohmann/json.hpp
##   - deps/sentencepiece/include/sentencepiece_processor.h
##   - deps/sentencepiece/${TARGET}/lib/static/libsentencepiece.a
## outputs:
##   - build/include/marian_core.h
##   - build/src/marian_core.cc
##   - build/src/json.hpp
##   - build/${TARGET}/lib/libmarian_core.${SHARED_EXT}
##   - build/${TARGET}/lib/static/libmarian_core.a
##@enddeps

##@deps
## name: nlohmann-json
## kind: vendored_header
## path: third_party/nlohmann/json.hpp
## outputs:
##   - build/src/json.hpp
## notes:
##   - header-only; used only in src/marian_core.cc
##@enddeps

# =============================================================================
# Paths
# =============================================================================

SP_SCRIPT := scripts/build_sentencepiece.sh
SP_PATH   := ./deps/sentencepiece
SP_LIB    := $(SP_PATH)/$(TARGET)/lib/static/libsentencepiece.a
SP_HEAD   := $(SP_PATH)/include/sentencepiece_processor.h
NJ_PATH   := ./third_party/nlohmann

OUT_DIR        := ./build
OUT_HEAD_DIR   := $(OUT_DIR)/include
OUT_SRC_DIR    := $(OUT_DIR)/src
OUT_LIB_DIR    := $(OUT_DIR)/$(TARGET)/lib
OUT_STATIC_DIR := $(OUT_LIB_DIR)/static

SRC_DIR := ./src

SHARED_LIB := $(OUT_LIB_DIR)/libmarian_core.$(SHARED_EXT)
STATIC_LIB := $(OUT_STATIC_DIR)/libmarian_core.a
HEADNAME   := $(OUT_HEAD_DIR)/marian_core.h

SRCS := $(SRC_DIR)/marian_core.cc
OBJS := $(SRC_DIR)/marian_core.o

.INTERMEDIATE: $(OBJS)

# =============================================================================
# Toolchain
# =============================================================================

ifeq ($(TARGET_OS),windows)
    SHARED_EXT := dll
    CXX        ?= x86_64-w64-mingw32-g++
    AR         ?= x86_64-w64-mingw32-ar
    CXXFLAGS   ?= -std=c++17 -O3 -I. -I$(SP_PATH)/include -I$(NJ_PATH) -DMARIAN_CORE_BUILD
    LDFLAGS    ?= -shared -static-libstdc++ -static-libgcc -Wl,-Bstatic -lwinpthread -Wl,-Bdynamic
else ifeq ($(TARGET_OS),darwin)
    SHARED_EXT := dylib
    CXX        ?= clang++
    AR         ?= ar
    CXXFLAGS   ?= -std=c++17 -O3 -fPIC -I. -I$(SP_PATH)/include -I$(NJ_PATH) -DMARIAN_CORE_BUILD
    LDFLAGS    ?= -dynamiclib -lstdc++
else ifeq ($(TARGET_OS),android)
    $(error Android target is not supported yet. Use TARGET_OS=linux/windows/darwin.)
else
    SHARED_EXT := so
    CXX        ?= g++
    AR         ?= ar
    CXXFLAGS   ?= -std=c++17 -O3 -fPIC -I. -I$(SP_PATH)/include -I$(NJ_PATH) -DMARIAN_CORE_BUILD
    LDFLAGS    ?= -shared -lstdc++
endif

# =============================================================================
# Targets
# =============================================================================

.PHONY: help all deps static shared clean print-vars

## Show help
help:
	@echo ""
	@echo "marian-tokenizer-core"
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [TARGET_OS=linux|darwin|windows] [TARGET_ARCH=amd64|arm64]"
	@echo ""
	@echo "Detected: TARGET_OS=$(DETECTED_OS) TARGET_ARCH=$(DETECTED_ARCH) -> TARGET=$(TARGET)"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS=":.*## "}; /^[a-zA-Z0-9_\-]+:.*## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""

print-vars: ## Print resolved variables
	@echo "TARGET_OS=$(TARGET_OS)"
	@echo "TARGET_ARCH=$(TARGET_ARCH)"
	@echo "TARGET=$(TARGET)"
	@echo "SP_LIB=$(SP_LIB)"
	@echo "SHARED_LIB=$(SHARED_LIB)"
	@echo "STATIC_LIB=$(STATIC_LIB)"

all: deps $(OUT_HEAD_DIR) $(SHARED_LIB) $(STATIC_LIB) ## Build shared + static

deps: $(SP_LIB) ## Build SentencePiece dependency
	@echo "SentencePiece OK: $(SP_LIB)"

static: deps $(OUT_HEAD_DIR) $(STATIC_LIB) ## Build static lib only
shared: deps $(OUT_HEAD_DIR) $(SHARED_LIB) ## Build shared lib only

$(OUT_HEAD_DIR):
	@mkdir -p $(OUT_HEAD_DIR) $(OUT_SRC_DIR) $(OUT_LIB_DIR) $(OUT_STATIC_DIR)
	@cp $(SRC_DIR)/marian_core.h $(HEADNAME)
	@cp $(SRC_DIR)/marian_core.cc $(NJ_PATH)/json.hpp $(OUT_SRC_DIR)

$(SHARED_LIB): $(OUT_HEAD_DIR) $(OBJS) $(SP_LIB)
	@echo "Building shared: $(TARGET)"
	$(CXX) -o $@ $(OBJS) $(SP_LIB) $(LDFLAGS)

$(STATIC_LIB): $(OUT_HEAD_DIR) $(OBJS)
	@echo "Building static: $(TARGET)"
	$(AR) rcs $@ $(OBJS)

$(OBJS): $(SRC_DIR)/marian_core.cc $(NJ_PATH)/json.hpp $(SRC_DIR)/marian_core.h $(SP_HEAD)
	@echo "Compiling: $(TARGET)"
	$(CXX) $(CXXFLAGS) -c $(SRC_DIR)/marian_core.cc -o $(SRC_DIR)/marian_core.o

clean: ## Remove build artifacts
	@rm -f $(OBJS) $(SHARED_LIB) $(STATIC_LIB) $(HEADNAME)

$(SP_LIB):
	@echo "==> Building SentencePiece for $(TARGET)"
	@chmod +x $(SP_SCRIPT)
	@TARGET_OS=$(TARGET_OS) TARGET_ARCH=$(TARGET_ARCH) $(SP_SCRIPT)
