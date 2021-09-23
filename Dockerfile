FROM debian:jessie
ENV DEBIAN_FRONTEND noninteractive
ENV LUAROCKS_VERSION=2.4.1
# Install required software
# wrk2 dependencies:
#   git make build-essential libssl-dev
# Luarocks dependencies:
#   make build-essential curl unzip lua5.1 liblua5.1-dev
RUN apt-get update -y \
  && apt-get install -y git make build-essential libssl-dev curl unzip lua5.1 liblua5.1-dev zlib1g-dev \
  && apt-get clean \
  # Cleanup this layer as we go
  && rm -rf /var/lib/apt/lists/* /var/tmp/*

# Start Build and install process
WORKDIR /tmp

# Install Luarocks lua package manager and cjson package
RUN curl https://keplerproject.github.io/luarocks/releases/luarocks-$LUAROCKS_VERSION.tar.gz -O \
  && tar -xzvf luarocks-$LUAROCKS_VERSION.tar.gz \
  && cd luarocks-$LUAROCKS_VERSION \
  && ./configure \
  && make build \
  && make install \
  && luarocks install lua-cjson \
  # Cleanup this layer as we go
  && rm -rf /tmp/*


# Install wrk2 - benchmarking software
RUN git clone https://github.com/giltene/wrk2 \
  && cd wrk2 \
  && make \
  && mv wrk /usr/local/bin/wrk2 \
  # Cleanup this layer as we go
  && rm -rf /tmp/*

WORKDIR /

# Raise the limits to successfully run benchmarks
RUN ulimit -c -m -s -t unlimited

#DEBIAN_FRONTEND=newt
