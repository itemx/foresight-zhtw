#!/bin/zsh
# Builds OpenCC (arm64) for Simplified -> Traditional conversion of transcripts.
# Installs into ~/local-llm/models/special/foresight-zh/opencc (lib + share/opencc).
# Homebrew's opencc is not used: on many Macs Homebrew runs under Rosetta and its
# x86_64 dylib cannot load into the arm64 Foresight process. Needs cmake.
set -e
OPENCC_VERSION=1.1.9
DEST=${FORESIGHT_ZH_MODELS:-$HOME/local-llm/models/special/foresight-zh}/opencc
if [[ -f "$DEST/lib/libopencc.dylib" && -f "$DEST/share/opencc/s2twp.json" ]]; then
  echo "opencc already installed in $DEST"; exit 0
fi
command -v cmake >/dev/null || { echo "cmake is required (brew install cmake)"; exit 1 }
tmp=$(mktemp -d)
# Some Command Line Tools installs have an empty usr/include/c++/v1, which hides
# the SDK's libc++ headers from clang. Point at the SDK copy directly.
cxxflags=""
if ! echo '#include <limits>' | clang++ -arch arm64 -x c++ -c -o /dev/null - 2>/dev/null; then
  cxxflags="-nostdinc++ -isystem $(xcrun --show-sdk-path)/usr/include/c++/v1"
  echo "libc++ headers missing from Command Line Tools - using the SDK copy"
fi
echo "downloading OpenCC $OPENCC_VERSION"
curl -fsSL "https://github.com/BYVoid/OpenCC/archive/refs/tags/ver.$OPENCC_VERSION.tar.gz" | tar xz -C "$tmp"
cmake -S "$tmp"/OpenCC-* -B "$tmp/build" -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$DEST" -DBUILD_SHARED_LIBS=ON -DBUILD_DOCUMENTATION=OFF -DENABLE_GTEST=OFF \
  -DENABLE_BENCHMARK=OFF -DENABLE_DARTS=OFF -DCMAKE_CXX_FLAGS="$cxxflags" >/dev/null
cmake --build "$tmp/build" -j >/dev/null
cmake --install "$tmp/build" >/dev/null
rm -rf "$tmp"
file "$DEST/lib/libopencc.dylib"
