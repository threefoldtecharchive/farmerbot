FROM --platform=$BUILDPLATFORM ubuntu:20.04 AS build

ARG TARGETPLATFORM

RUN apt-get update && \
    apt-get install -y build-essential gcc-arm-linux-gnueabihf gcc-aarch64-linux-gnu git

WORKDIR /opt/vlang
RUN git clone https://github.com/vlang/v /opt/vlang 
RUN make
RUN ./v symlink
RUN v -version

WORKDIR /baobab
RUN git clone -b development https://github.com/freeflowuniverse/baobab.git .
RUN bash install.sh

WORKDIR /crystallib
RUN git clone -b development https://github.com/freeflowuniverse/crystallib.git .
RUN bash install.sh

WORKDIR /farmerbot
COPY . .
RUN bash install.sh
RUN if [ $TARGETPLATFORM = linux/arm/v7 ]; then v -prod -cc arm-linux-gnueabihf-gcc main.v; fi
RUN if [ $TARGETPLATFORM = linux/arm64 ]; then v -prod -cc aarch64-linux-gnu-gcc main.v; fi

# ===== SECOND STAGE ======

FROM ubuntu:20.04
LABEL description="This is the 2nd stage: a very small image where we copy the farmerbot binary."

COPY --from=build /farmerbot/main /usr/local/bin/farmerbot

RUN apt-get update && apt-get install -y curl ca-certificates libatomic1

# checks
# RUN ldd /usr/local/bin/farmerbot && /usr/local/bin/farmerbot --version

# Shrinking
RUN rm -rf /usr/lib/python* && \
	rm -rf /src && \
	rm -rf /usr/share/man
RUN apt-get clean && rm -rf /var/cache/apt/archives/* && \
    rm -rf /var/lib/apt/lists/*

VOLUME ["/farmerbot"]

ENTRYPOINT ["/usr/local/bin/farmerbot"]

