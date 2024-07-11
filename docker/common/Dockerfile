################### Build SMTS #########################################################################################
FROM satcomp-infrastructure:common
USER root

# Install required software
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt install -y apt-utils make cmake \
       build-essential libgmp-dev bison flex git python3

ENV CMAKE_BUILD_TYPE=Release
ENV ENABLE_LINE_EDITING=OFF
ENV PARALLEL=ON

# Fetch and build SMTS
RUN git clone https://github.com/usi-verification-and-security/SMTS.git --branch cube-and-conquer --single-branch
WORKDIR SMTS
RUN bash bin/make_smts.sh
RUN rm -rf \
    graphviz \
    gui \
    build/lib \
    build/_deps/ptplib-src/tests \
    build/_deps/opensmt-src/regression* \
    build/_deps/opensmt-src/benchmark \
    build/_deps/opensmt-src/docs \
    build/_deps/opensmt-src/examples \
