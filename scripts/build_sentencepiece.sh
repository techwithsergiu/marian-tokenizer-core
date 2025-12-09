#!/usr/bin/env bash
set -euo pipefail

# If TARGET_OS / TARGET_ARCH are set externally, they will be used.
os="${TARGET_OS:-}"
arch="${TARGET_ARCH:-}"

if [[ -z "${os}" || -z "${arch}" ]]; then
    # 1. Detect OS
    uname_s="$(uname -s)"

    case "$uname_s" in
        Linux)
            os="linux"
            ;;
        Darwin)
            os="darwin"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            # Git Bash / MSYS2 / Cygwin — consider this to be Windows
            os="windows"
            ;;
        *)
            echo "Unsupported OS: $uname_s"
            exit 1
            ;;
    esac

    # 2. Detect ARCH
    uname_m="$(uname -m)"

    case "$uname_m" in
        x86_64|amd64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        *)
            echo "Unsupported ARCH: $uname_m"
            exit 1
            ;;
    esac
fi

target="${os}_${arch}"
echo "Shell script - Building sentencepiece for: $target"


# ========================
# build sentencepiece

cd ./third_party/sentencepiece
rm -rf ./build
mkdir -p ./build
cd ./build

# Prepare make files
if [[ "$os" == "windows" ]]; then
    # Windows:
    cmake .. -G "MSYS Makefiles" -DCMAKE_BUILD_TYPE=Release
elif [[ "$os" == "linux" || "$os" == "darwin" ]]; then
    # Linux, Mac
    cmake .. -DCMAKE_BUILD_TYPE=Release
elif [[ "$os" == "android" ]]; then
    # TODO : Android (cross-compile using NDK)

    echo "Android is not supported.. (os=$os)"
    exit 1
    
    # if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
    #     echo "ERROR: ANDROID_NDK_HOME is not set. Please export ANDROID_NDK_HOME to your NDK path."
    #     exit 1
    # fi
    # cmake .. \
    #     -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    #     -DANDROID_ABI=arm64-v8a \
    #     -DANDROID_PLATFORM=android-21 \
    #     -DCMAKE_BUILD_TYPE=Release \
    #     -DSPM_ENABLE_SHARED=OFF
else
    echo "Something else.. is not supported.. (os=$os)"
    exit 1
fi

# Build
cmake --build . --config Release --parallel "$(nproc)"


# ========================
# Cleanup
rm -rf "../../../deps/sentencepiece/$target"
mkdir -p "../../../deps/sentencepiece/$target/lib/static"
mkdir -p "../../../deps/sentencepiece/include"

# Copy deps
if [[ "$os" == "linux" ]]; then
    echo "Linux: Copy deps"
    cp ./src/libsentencepiece.a  "../../../deps/sentencepiece/$target/lib/static"
    cp ./src/libsentencepiece.so "../../../deps/sentencepiece/$target/lib"
    cp ../src/sentencepiece_processor.h "../../../deps/sentencepiece/include"

    # Creating symlinks
    echo "Linux: Creating symlinks"
    cd "../../../deps/sentencepiece/$target/lib"
    ln -s libsentencepiece.so libsentencepiece.so.0
    ln -s libsentencepiece.so libsentencepiece.so.0.0.0

elif [[ "$os" == "windows" ]]; then
    echo "Windows: Copy deps (static only, shared not supported yet)"
    cp ./src/libsentencepiece.a  "../../../deps/sentencepiece/$target/lib/static"
    touch "../../../deps/sentencepiece/$target/lib/libsentencepiece.NOT_SUPPORTED"
    cp ../src/sentencepiece_processor.h "../../../deps/sentencepiece/include"

elif [[ "$os" == "darwin" ]]; then
    echo "Darwin: Copy deps"
    cp ./src/libsentencepiece.a      "../../../deps/sentencepiece/$target/lib/static"
    cp ./src/libsentencepiece.dylib  "../../../deps/sentencepiece/$target/lib"
    cp ../src/sentencepiece_processor.h "../../../deps/sentencepiece/include"

else
    echo "Something else.. is not supported.."
fi
