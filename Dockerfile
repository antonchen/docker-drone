FROM golang:1.19.8-bullseye AS Builder

ARG DEBIAN_FRONTEND="noninteractive"
ARG MIRROR_DOMAIN="mirrors.tuna.tsinghua.edu.cn"
ARG DRONE_SERVER_VERSION

RUN \
    echo "Asia/Shanghai" > /etc/timezone && \
    sed -i "s/deb.debian.org/${MIRROR_DOMAIN}/g" /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y curl unzip && \
    go env -w GO111MODULE=on && \
    go env -w GOPROXY=https://goproxy.cn && \
    curl -L https://github.com/harness/drone/archive/refs/tags/${DRONE_SERVER_VERSION}.zip -o /tmp/drone-${DRONE_SERVER_VERSION}.zip && \
    unzip /tmp/drone-${DRONE_SERVER_VERSION}.zip -d /src && \
    rm -f /tmp/drone-${DRONE_SERVER_VERSION}.zip && \
    cd /src/drone-* && \
    go mod download && \
    export CGO_CFLAGS="-g -O2 -Wno-return-local-addr" && \
    go build -tags "nolimit" github.com/drone/drone/cmd/drone-server

FROM antonhub/debian:testing
ENV FIRST_PARTY="true"
# set maintainer label
LABEL MAINTAINER="Anton Chen <contact@antonchen.com>"

WORKDIR /app

ENV GODEBUG=netdns=cgo \
XDG_CACHE_HOME=/data \
DRONE_DATABASE_DRIVER=sqlite3 \
DRONE_DATABASE_DATASOURCE=/data/database.sqlite \
DRONE_RUNNER_OS=linux \
DRONE_RUNNER_ARCH=amd64

COPY --from=Builder /src/drone-*/drone-server /app/

# copy local files
COPY root/ /
RUN find /etc/s6-overlay -name run|xargs chmod 755

# ports and volumes
EXPOSE 8080
VOLUME /data
