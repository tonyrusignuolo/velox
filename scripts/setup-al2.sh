#!/bin/bash
# Copyright (c) Facebook, Inc. and its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Minimal setup for Ubuntu 20.04.
set -eufx -o pipefail
SCRIPTDIR=$(dirname "${BASH_SOURCE[0]}")
source $SCRIPTDIR/setup-helper-functions.sh

NPROC=$(getconf _NPROCESSORS_ONLN)
DEPENDENCY_DIR=${DEPENDENCY_DIR:-$(pwd)}

# Install all velox and folly dependencies.
# sudo --preserve-env apt install -y \
#   g++ \
#   cmake \
#   ccache \
#   ninja-build \
#   checkinstall \
#   git \
#   libssl-dev \
#   libboost-all-dev \
#   libdouble-conversion-dev \
#   libgoogle-glog-dev \
#   libbz2-dev \
#   libgflags-dev \
#   libgmock-dev \
#   libevent-dev \
#   liblz4-dev \
#   libzstd-dev \
#   libre2-dev \
#   libsnappy-dev \
#   liblzo2-dev \
#   bison \
#   flex \
#   tzdata \
#   wget

function run_and_time {
  time "$@"
  { echo "+ Finished running $*"; } 2> /dev/null
}

function prompt {
  (
    while true; do
      local input="${PROMPT_ALWAYS_RESPOND:-}"
      echo -n "$(tput bold)$* [Y, n]$(tput sgr0) "
      [[ -z "${input}" ]] && read input
      if [[ "${input}" == "Y" || "${input}" == "y" || "${input}" == "" ]]; then
        return 0
      elif [[ "${input}" == "N" || "${input}" == "n" ]]; then
        return 1
      fi
    done
  ) 2> /dev/null
}

function install_fmt {
  github_checkout fmtlib/fmt 8.0.0
  cmake_install -DFMT_TEST=OFF
}

function install_protobuf {
  wget https://github.com/protocolbuffers/protobuf/releases/download/v21.4/protobuf-all-21.4.tar.gz
  tar -xzf protobuf-all-21.4.tar.gz
  cd protobuf-21.4
  ./configure \
      CXXFLAGS="-fPIC" \
      --prefix=/usr
  make "-j$(nproc)"
  sudo make install
  sudo ldconfig
}

function install_folly {
  github_checkout facebook/folly v2022.07.11.00
  cmake_install -DBUILD_TESTS=OFF
}

function install_libhdfs3 {
  github_checkout apache/hawq master
  cd depends/libhdfs3
  sed -i "/FIND_PACKAGE(GoogleTest REQUIRED)/d" ./CMakeLists.txt
  sed -i "s/dumpversion/dumpfullversion/" ./CMake/Platform.cmake
  cmake_install -DCMAKE_CXX_LINK_FLAGS="-Wl,-rpath,/usr/local/lib64 -L/usr/local/lib64"
}

function install_velox_deps {
  run_and_time install_fmt
  run_and_time install_protobuf
  run_and_time install_folly
  run_and_time install_libhdfs3
}

(return 2> /dev/null) && return # If script was sourced, don't run commands.

(
  if [[ $# -ne 0 ]]; then
    for cmd in "$@"; do
      run_and_time "${cmd}"
    done
  else
    install_velox_deps
  fi
)

echo "All deps for Velox installed! Now try \"make\""