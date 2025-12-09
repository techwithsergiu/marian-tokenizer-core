

#===
# Detect OS
UNAME_S := $(shell uname -s)

ifeq ($(OS),Windows_NT)
    # Native Windows CMD or PowerShell
    DETECTED_OS := windows
else ifeq ($(findstring MINGW,$(UNAME_S)),MINGW)
    # Git Bash / MSYS2 / MinGW
    DETECTED_OS := windows
else ifeq ($(findstring MSYS,$(UNAME_S)),MSYS)
    DETECTED_OS := windows
else ifeq ($(findstring CYGWIN,$(UNAME_S)),CYGWIN)
    DETECTED_OS := windows
else ifeq ($(UNAME_S),Linux)
    DETECTED_OS := linux
else ifeq ($(UNAME_S),Darwin)
    DETECTED_OS := darwin
else
    $(error Unsupported OS: $(UNAME_S))
endif

# Detect ARCH
UNAME_M := $(shell uname -m)

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

TARGET := $(TARGET_OS)_$(TARGET_ARCH)
#===

# ===== 2. Paths for sentencepiece =====

SP_SCRIPT := ./scripts/build_sentencepiece.sh
SP_PATH  := ./deps/sentencepiece
SP_LIB   := $(SP_PATH)/$(TARGET)/lib/static/libsentencepiece.a
SP_HEAD  := $(SP_PATH)/include/sentencepiece_processor.h

# ===== 3. Toolchain / OS flags =====

ifeq ($(TARGET_OS),windows)
    SHARED_EXT := dll
    CXX        ?= x86_64-w64-mingw32-g++
    AR         ?= x86_64-w64-mingw32-ar
    CXXFLAGS   ?= -std=c++17 -O3 -I. -I$(SP_PATH)/include -DMARIAN_CORE_BUILD
    LDFLAGS    ?= -shared -static-libstdc++ -static-libgcc -Wl,-Bstatic -lwinpthread -Wl,-Bdynamic
else ifeq ($(TARGET_OS),darwin)
    SHARED_EXT := dylib
    CXX        ?= clang++
    AR         ?= ar
    CXXFLAGS   ?= -std=c++17 -O3 -fPIC -I. -I$(SP_PATH)/include -DMARIAN_CORE_BUILD
    LDFLAGS    ?= -dynamiclib -lstdc++
else ifeq ($(TARGET_OS),android)
    ifndef ANDROID_NDK_HOME
        $(error ANDROID_NDK_HOME is not set. Please export ANDROID_NDK_HOME to your NDK path.)
    endif

    # TODO: Add Android support (NDK toolchain)
    $(error Android target for marian_core is not supported yet. Please build only linux/windows/darwin.)
#     SHARED_EXT := so
#     ANDROID_TOOLCHAIN  ?= $(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64
#     ANDROID_TRIPLE     ?= aarch64-linux-android
#     ANDROID_API        ?= 21
#     CXX ?= $(ANDROID_TOOLCHAIN)/bin/$(ANDROID_TRIPLE)$(ANDROID_API)-clang++
#     AR  ?= $(ANDROID_TOOLCHAIN)/bin/llvm-ar
#     CXXFLAGS ?= -std=c++17 -O3 -fPIC -DMARIAN_CORE_BUILD \
#         --target=$(ANDROID_TRIPLE)$(ANDROID_API) \
#         --sysroot=$(ANDROID_TOOLCHAIN)/sysroot \
#         -I. -I$(SP_PATH)/include
#     LDFLAGS  ?= -shared \
#         --target=$(ANDROID_TRIPLE)$(ANDROID_API) \
#         --sysroot=$(ANDROID_TOOLCHAIN)/sysroot
else
    SHARED_EXT := so
    CXX        ?= g++
    AR         ?= ar
    CXXFLAGS   ?= -std=c++17 -O3 -fPIC -I. -I$(SP_PATH)/include -DMARIAN_CORE_BUILD
    LDFLAGS    ?= -shared -lstdc++
endif

# ===== 4. Paths for marian_core =====

OUT_DIR        := ./build
OUT_HEAD_DIR   := $(OUT_DIR)/include
OUT_SRC_DIR    := $(OUT_DIR)/src
OUT_LIB_DIR    := $(OUT_DIR)/$(TARGET)/lib
OUT_STATIC_DIR := $(OUT_LIB_DIR)/static

SHARED_LIB     := $(OUT_LIB_DIR)/libmarian_core.$(SHARED_EXT)
STATIC_LIB     := $(OUT_STATIC_DIR)/libmarian_core.a
HEADNAME       := $(OUT_HEAD_DIR)/marian_core.h

SRC_DIR := ./src

SRCS := $(SRC_DIR)/marian_core.cc
OBJS := $(SRC_DIR)/marian_core.o

.INTERMEDIATE: $(OBJS)

.PHONY: clean deps all static shared

all: deps $(OUT_HEAD_DIR) $(SHARED_LIB) $(STATIC_LIB)

static: $(OUT_HEAD_DIR) $(STATIC_LIB)
shared: $(OUT_HEAD_DIR) $(SHARED_LIB)

$(OUT_HEAD_DIR):
	mkdir -p $(OUT_HEAD_DIR)
	mkdir -p $(OUT_SRC_DIR)
	mkdir -p $(OUT_LIB_DIR)
	mkdir -p $(OUT_STATIC_DIR)
	@echo "Makefile - Copying files:"
	cp $(SRC_DIR)/marian_core.h $(HEADNAME)
	cp $(SRC_DIR)/marian_core.cc $(SRC_DIR)/json.hpp $(OUT_SRC_DIR)

$(SHARED_LIB): $(OUT_HEAD_DIR) $(OBJS) $(SP_LIB)
	@echo "Makefile - Building SHARED for: $(TARGET)"
	$(CXX) -o $@ $(OBJS) $(SP_LIB) $(LDFLAGS)

$(STATIC_LIB): $(OUT_HEAD_DIR) $(OBJS)
	@echo "Makefile - Building STATIC for: $(TARGET)"
	$(AR) rcs $@ $(OBJS)

$(OBJS): $(SRC_DIR)/marian_core.cc \
		$(SRC_DIR)/json.hpp \
		$(SRC_DIR)/marian_core.h \
		$(SP_HEAD)
	@echo "Makefile - Compiling for: $(TARGET)"
	$(CXX) $(CXXFLAGS) -c $(SRC_DIR)/marian_core.cc -o $(SRC_DIR)/marian_core.o

clean:
	rm -f $(OBJS) $(SHARED_LIB) $(STATIC_LIB) $(HEADNAME)

deps: $(SP_LIB)
	@echo "SentencePiece is already built at $(SP_LIB)"
$(SP_LIB):
	@echo "==> Building SentencePiece for $(TARGET)"
	chmod +x $(SP_SCRIPT)
	TARGET_OS=$(TARGET_OS) TARGET_ARCH=$(TARGET_ARCH) $(SP_SCRIPT)
