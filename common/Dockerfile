################### Build SMTS #########################################################################################
FROM satcomp-common-base-image
USER root

ENV CMAKE_BUILD_TYPE Release
ENV USE_READLINE OFF
ENV ENABLE_LINE_EDITING OFF
ENV PARALLEL ON

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt install -y apt-utils make cmake \
     build-essential libgmp-dev bison flex git python3


RUN git clone https://github.com/usi-verification-and-security/SMTS.git --branch cube-and-conquer --single-branch
WORKDIR SMTS
RUN bash bin/make_smts.sh && cd ..
RUN rm -rf graphviz
RUN rm -rf gui
RUN rm -rf build/_deps/ptplib-src/tests
RUN rm -rf build/lib
RUN rm -rf build/_deps/opensmt-src/regression* && rm -rf build/_deps/opensmt-src/benchmark && \
    rm -rf build/_deps/opensmt-src/docs && rm -rf build/_deps/opensmt-src/examples

