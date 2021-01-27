#!/bin/bash
export DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

export PATH="/llvm-build/bin:${PATH}"
source /emsdk/emsdk_env.sh
# source $DIR/emsdk/emsdk_env.sh

pushd julia

(cd build-wasm && make VERBOSE=1 --trace -C deps -j 8 BUILDING_HOST_TOOLS=1 install-libuv install-utf8proc 2>&1 | tee log)
(cd build-wasm && make VERBOSE=1 --trace -C deps -j 8 2>&1 | tee log)
(cd build-native && make VERBOSE=1 --trace -j 8 2>&1 | tee log)
(cd build-wasm && make VERBOSE=1 --trace -j 8 julia-ui-release 2>&1 | tee log)
