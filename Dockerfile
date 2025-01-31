FROM golang:1.16.0-alpine3.13 AS Builder

RUN sed -i 's/https:\/\/dl-cdn.alpinelinux.org/http:\/\/mirrors.tuna.tsinghua.edu.cn/' /etc/apk/repositories && \
    echo "Asia/Shanghai" > /etc/timezone

RUN apk add build-base git && \
    go env -w GO111MODULE=on && \
    go env -w GOPROXY=https://goproxy.cn,direct

ENV DRONE_VERSION 2.1.0

WORKDIR /src

# Build with online code
RUN apk add curl && curl -L https://github.com/drone/drone/archive/refs/tags/v${DRONE_VERSION}.tar.gz -o v${DRONE_VERSION}.tar.gz && \
    tar zxvf v${DRONE_VERSION}.tar.gz && rm v${DRONE_VERSION}.tar.gz
# OR with offline tarball
# ADD drone-1.10.1.tar.gz /src/

WORKDIR /src/drone-${DRONE_VERSION}

RUN go mod download

ENV CGO_CFLAGS="-g -O2 -Wno-return-local-addr"

RUN go build -ldflags "-extldflags \"-static\"" -tags="nolimit" github.com/drone/drone/cmd/drone-server



FROM alpine:3.13 AS Certs
RUN sed -i 's/https:\/\/dl-cdn.alpinelinux.org/http:\/\/mirrors.tuna.tsinghua.edu.cn/' /etc/apk/repositories && \
    echo "Asia/Shanghai" > /etc/timezone
RUN apk add -U --no-cache ca-certificates



FROM alpine:3.13
EXPOSE 80 443
VOLUME /data

RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf

ENV GODEBUG netdns=go
ENV XDG_CACHE_HOME /data
ENV DRONE_DATABASE_DRIVER sqlite3
ENV DRONE_DATABASE_DATASOURCE /data/database.sqlite
ENV DRONE_RUNNER_OS=linux
ENV DRONE_RUNNER_ARCH=amd64
ENV DRONE_SERVER_PORT=:80
ENV DRONE_SERVER_HOST=localhost
ENV DRONE_DATADOG_ENABLED=true
ENV DRONE_DATADOG_ENDPOINT=https://stats.drone.ci/api/v1/series

COPY --from=Certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=Builder /src/drone-2.1.0/drone-server /bin/drone-server
ENTRYPOINT ["/bin/drone-server"]