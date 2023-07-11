# ===== FIRST STAGE ======
# Download the dependencies
# Create the vlang binaries of file creator

FROM --platform=$BUILDPLATFORM ubuntu:20.04 AS build
ARG TARGETPLATFORM

RUN apt-get update && \
    apt-get install -y build-essential gcc-arm-linux-gnueabihf gcc-aarch64-linux-gnu git
RUN apt-get install -y wget

WORKDIR /opt/vlang
RUN git clone https://github.com/vlang/v /opt/vlang && make && ./v symlink && v -version

WORKDIR /crystallib
RUN git clone -b development https://github.com/freeflowuniverse/crystallib.git .
RUN bash install.sh

WORKDIR /farmerbot
RUN wget https://raw.githubusercontent.com/threefoldtech/farmerbot/development/scripts/file_creator.v
RUN if [ $TARGETPLATFORM = linux/arm/v7 ]; then v -prod -cc arm-linux-gnueabihf-gcc file_creator.v; fi
RUN if [ $TARGETPLATFORM = linux/arm64 ]; then v -prod -cc aarch64-linux-gnu-gcc file_creator.v; fi

# ===== SECOND STAGE ======
# Copy the Farmerbot's file creator binaries
# Create an entrypoint to run the file creator binaries

FROM ubuntu:20.04

WORKDIR /farmerbot
COPY --from=build /farmerbot/file_creator /usr/local/bin/file_creator
ENTRYPOINT /usr/local/bin/file_creator
