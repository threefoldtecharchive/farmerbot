FROM thevlang/vlang:ubuntu-build AS build

WORKDIR /opt/vlang
RUN git clone https://github.com/vlang/v /opt/vlang && make && v -version
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    clang llvm-dev tcc && \
    apt-get clean && rm -rf /var/cache/apt/archives/* && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /baobab
RUN git clone -b development https://github.com/freeflowuniverse/baobab.git .
RUN bash install.sh

WORKDIR /crystallib
RUN git clone -b development https://github.com/freeflowuniverse/crystallib.git .
RUN bash install.sh

WORKDIR /farmerbot
COPY . .
RUN bash install.sh
RUN v -prod main.v

# ===== SECOND STAGE ======

FROM ubuntu:20.04
LABEL maintainer="brandon@threefold.tech"
LABEL description="This is the 2nd stage: a very small image where we copy the farmebot binary."

COPY --from=build /farmerbot/main /usr/local/bin/farmerbot

RUN apt-get update && apt-get install -y curl ca-certificates libatomic1

# checks
RUN ldd /usr/local/bin/farmerbot && /usr/local/bin/farmerbot --version

# Shrinking
RUN rm -rf /usr/lib/python* && \
	rm -rf /src && \
	rm -rf /usr/share/man

VOLUME ["/farmerbot"]

ENTRYPOINT ["/usr/local/bin/farmerbot"]