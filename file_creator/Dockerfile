# ===== FIRST STAGE ======
# Download the dependencies
# Create the vlang binaries of file creator

FROM thevlang/vlang:ubuntu-build AS build

WORKDIR /opt/vlang
RUN git clone https://github.com/vlang/v /opt/vlang && make && v -version
RUN apt-get update

WORKDIR /crystallib
RUN git clone -b development https://github.com/freeflowuniverse/crystallib.git .
RUN bash install.sh

WORKDIR /farmerbot
RUN wget https://raw.githubusercontent.com/threefoldtech/farmerbot/development/scripts/file_creator.v
RUN v -prod file_creator.v

# ===== SECOND STAGE ======
# Copy the Farmerbot's file creator binaries
# Create an entrypoint to run the file creator binaries

FROM ubuntu:20.04

WORKDIR /farmerbot
COPY --from=build /farmerbot/file_creator /usr/local/bin/file_creator
ENTRYPOINT /usr/local/bin/file_creator