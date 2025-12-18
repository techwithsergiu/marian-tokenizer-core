#!/usr/bin/env bash
# scripts/build_sentencepiece.sh

set -euo pipefail

##@deps
## name: sentencepiece
## kind: builder
## source: third_party/sentencepiece (git submodule)
## outputs:
##   - deps/sentencepiece/${target}/lib/static/libsentencepiece.a
##   - deps/sentencepiece/${target}/lib/libsentencepiece.so
##   - deps/sentencepiece/${target}/lib/libsentencepiece.dylib
##   - deps/sentencepiece/include/sentencepiece_processor.h
##@enddeps

detect_platform() {
  local os="${TARGET_OS:-}"
  local arch="${TARGET_ARCH:-}"

  if [[ -n "$os" && -n "$arch" ]]; then
    echo "${os}" "${arch}"
    return
  fi

  local uname_s uname_m
  uname_s="$(uname -s)"
  uname_m="$(uname -m)"

  case "$uname_s" in
    Linux) os="linux" ;;
    Darwin) os="darwin" ;;
    MINGW*|MSYS*|CYGWIN*) os="windows" ;;
    *) echo "Unsupported OS: $uname_s" >&2; exit 1 ;;
  esac

  case "$uname_m" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) echo "Unsupported ARCH: $uname_m" >&2; exit 1 ;;
  esac

  echo "${os}" "${arch}"
}

cpu_count() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    sysctl -n hw.ncpu
  else
    echo 4
  fi
}

cmake_configure() {
  local os="$1"

  if [[ "$os" == "windows" ]]; then
    cmake .. -G "MSYS Makefiles" -DCMAKE_BUILD_TYPE=Release
  elif [[ "$os" == "linux" || "$os" == "darwin" ]]; then
    cmake .. -DCMAKE_BUILD_TYPE=Release
  elif [[ "$os" == "android" ]]; then
    echo "Android is not supported (os=$os)" >&2
    exit 1
  else
    echo "Unsupported target OS: $os" >&2
    exit 1
  fi
}

copy_outputs() {
  local os="$1"
  local target="$2"

  local out_root="../../../deps/sentencepiece/${target}"
  rm -rf "${out_root}"
  mkdir -p "${out_root}/lib/static"
  mkdir -p "../../../deps/sentencepiece/include"

  # header
  cp ../src/sentencepiece_processor.h "../../../deps/sentencepiece/include"

  if [[ "$os" == "linux" ]]; then
    cp ./src/libsentencepiece.a  "${out_root}/lib/static/"
    cp ./src/libsentencepiece.so "${out_root}/lib/"
    ( cd "${out_root}/lib" && ln -sf libsentencepiece.so libsentencepiece.so.0 && ln -sf libsentencepiece.so libsentencepiece.so.0.0.0 )
  elif [[ "$os" == "darwin" ]]; then
    cp ./src/libsentencepiece.a      "${out_root}/lib/static/"
    cp ./src/libsentencepiece.dylib  "${out_root}/lib/"
  elif [[ "$os" == "windows" ]]; then
    cp ./src/libsentencepiece.a "${out_root}/lib/static/"
    touch "${out_root}/lib/libsentencepiece.NOT_SUPPORTED"
  else
    echo "Copy step: unsupported OS=$os" >&2
    exit 1
  fi
}

read -r os arch < <(detect_platform)
target="${os}_${arch}"

echo "Building SentencePiece for: ${target}"

cd ./third_party/sentencepiece
rm -rf ./build
mkdir -p ./build
cd ./build

cmake_configure "$os"
cmake --build . --config Release --parallel "$(cpu_count)"

copy_outputs "$os" "$target"

echo "Done: deps/sentencepiece/${target}"
