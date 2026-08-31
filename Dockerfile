# Dev/test image for tryst-segmented. Built from this repo's own root as
# context - both tryst and tryst-vector are `github:` shard dependencies
# (their own repos), so `shards install` fetches them directly rather
# than needing them copied into the build context.
#
# Debian forky for the same reason tryst-vector/Dockerfile is: it's the
# first Debian release carrying libthorvg-dev, which this shard also
# links (it renders through tryst-vector's Surface).
#
# Must be run as `docker run --rm --init <image>` - same requirement as
# every other Dockerfile in this repo. Without --init, xvfb-run hangs
# forever as PID 1.
FROM debian:forky

ARG CRYSTAL_VERSION=1.21.0
ARG CRYSTAL_RELEASE=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    tcl-dev tk-dev \
    libthorvg-dev \
    xvfb xauth \
    ca-certificates curl git gcc pkg-config \
    libpcre2-dev libgc-dev libevent-dev libssl-dev zlib1g-dev libyaml-dev libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    arch="$(uname -m)"; \
    curl -fsSL -o /tmp/crystal.tar.gz \
      "https://github.com/crystal-lang/crystal/releases/download/${CRYSTAL_VERSION}/crystal-${CRYSTAL_VERSION}-${CRYSTAL_RELEASE}-linux-${arch}.tar.gz"; \
    mkdir -p /opt/crystal; \
    tar -xzf /tmp/crystal.tar.gz -C /opt/crystal --strip-components=1; \
    rm /tmp/crystal.tar.gz; \
    ln -s /opt/crystal/bin/crystal /usr/local/bin/crystal; \
    ln -s /opt/crystal/bin/shards /usr/local/bin/shards; \
    crystal --version

WORKDIR /app
COPY shard.yml ./
COPY src/ src/
COPY spec/ spec/

# Docker's cache key for this layer is shard.yml's own content, not
# what's actually at the github: refs it resolves - a persistent Docker
# daemon (a long-running local dev daemon, or a self-hosted CI runner)
# would otherwise keep reusing whatever tryst/tryst-vector/ameba commit
# got fetched the FIRST time this layer ever ran, no matter how many
# times the actual dependency changed afterward. CACHEBUST forces this
# layer (only this one - everything above it still caches normally) to
# always re-resolve.
ARG CACHEBUST=1
RUN shards install

CMD ["xvfb-run", "-a", "crystal", "spec"]
