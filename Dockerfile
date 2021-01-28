FROM debian:latest AS builder
SHELL ["/bin/bash", "-c"]
RUN apt-get update && apt-get -qq install -y --no-install-recommends \
  python \
  python3-pip \
  curl \
  build-essential \
  cmake \
  ninja-build \
  gcc-multilib \
  g++-multilib \
  git \
  libatomic1 \
  gfortran \
  perl \
  wget \
  m4 \
  pkg-config
# RUN curl -sL https://deb.nodesource.com/setup_10.x | bash && \
#   apt-get -qq install -y nodejs
RUN pip3 install certifi

FROM builder AS emsdk
RUN git clone https://github.com/emscripten-core/emsdk.git /emsdk
WORKDIR /emsdk
ENV EM_CACHE /emsdk/.data/cache
RUN git pull
RUN ./emsdk install latest emscripten-master-64bit binaryen-master-64bit
RUN ./emsdk activate latest emscripten-master-64bit binaryen-master-64bit

FROM builder AS llvm
RUN git clone -b release/12.x https://github.com/llvm/llvm-project /llvm-project
RUN mkdir /llvm-build
WORKDIR /llvm-build
RUN CC=`which gcc` CXX=`which g++` CMAKE_MAKE_PROGRAM=`which make` \
  cmake -G "Ninja" -DLLVM_ENABLE_PROJECTS="clang;lld" -DCMAKE_BUILD_TYPE=Release ../llvm-project/llvm
RUN ninja -j 8

FROM builder AS julia
WORKDIR /src
COPY /src .
COPY --from=emsdk /emsdk /emsdk
COPY --from=llvm /llvm-build /llvm-build
RUN echo "LLVM_ROOT='/llvm-build/bin'" >> /emsdk/.emscripten && \
  echo "export PATH=/llvm-build/bin:$PATH" >> "/root/.bashrc" && \
  echo "source /emsdk/emsdk_env.sh" >> "/root/.bashrc"

# configure_julia_wasm.sh
RUN git clone https://github.com/JuliaLang/julia /julia
WORKDIR /julia
RUN git checkout vc/wasm
RUN make O=build-native configure && \
  make O=build-wasm configure
COPY /build-native/Make.user build-native/
COPY /build-wasm/Make.user build-wasm/

# build_julia_wasm.sh
RUN source /root/.bashrc && \
  export DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" && \
  (cd build-wasm && make VERBOSE=1 --trace -C deps -j 8 BUILDING_HOST_TOOLS=1 install-libuv install-utf8proc 2>&1 | tee log) && \
  (cd build-wasm && make VERBOSE=1 --trace -C deps -j 8 2>&1 | tee log) && \
  (cd build-native && make VERBOSE=1 --trace -j 8 2>&1 | tee log) && \
  (cd build-wasm && make VERBOSE=1 --trace -j 8 julia-ui-release 2>&1 | tee log)

# RUN chmod +x ./configure_julia_wasm.sh ./build_julia_wasm.sh ./rebuild_js.sh
# RUN source /root/.bashrc && \
#   ./configure_julia_wasm.sh && \
#   ./build_julia_wasm.sh && \
#   ./rebuild_js.sh
# RUN source /root/.bashrc && ./build_julia_wasm.sh
# RUN source /root/.bashrc && ./rebuild_js.sh

CMD ["/bin/bash", "-l"]
