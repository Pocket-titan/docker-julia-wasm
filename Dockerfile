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
RUN git clone https://github.com/llvm/llvm-project /llvm-project
RUN mkdir /llvm-build
WORKDIR /llvm-build
RUN cmake -G Ninja -DLLVM_ENABLE_PROJECTS="clang;lld" -DCMAKE_BUILD_TYPE=Release ../llvm-project/llvm
RUN ninja -j 8

FROM builder AS julia
WORKDIR /src
COPY /src .
COPY --from=emsdk /emsdk /emsdk
COPY --from=llvm /llvm-build /llvm-build
RUN echo "LLVM_ROOT='/llvm-build/bin'" >> /emsdk/.emscripten && \
  echo "export PATH=/llvm-build/bin:$PATH" >> "/root/.bashrc" && \
  echo "source /emsdk/emsdk_env.sh" >> "/root/.bashrc"
RUN chmod +x ./configure_julia_wasm.sh ./build_julia_wasm.sh ./rebuild_js.sh
RUN source /root/.bashrc && \
  ./configure_julia_wasm.sh && \
  ./build_julia_wasm && \
  ./rebuild_js.sh
# RUN source /root/.bashrc && ./build_julia_wasm.sh
# RUN source /root/.bashrc && ./rebuild_js.sh

CMD ["/bin/bash", "-l"]
