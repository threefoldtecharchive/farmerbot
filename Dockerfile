FROM thevlang/vlang:latest as build

RUN apt-get update && apt-get install -y git

WORKDIR /baobab
RUN git clone -b development_actor https://github.com/freeflowuniverse/baobab.git .
RUN bash install.sh


WORKDIR /crystallib
RUN git clone -b development_38 https://github.com/freeflowuniverse/crystallib.git .
RUN bash install.sh

WORKDIR /farmerbot
COPY . .
RUN bash install.sh
RUN v main.v

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