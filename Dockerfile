# Builder
FROM --platform=$BUILDPLATFORM whatwewant/builder-go:v1.22-1 as builder

WORKDIR /build

COPY go.mod ./

COPY go.sum ./

RUN go mod download

COPY . .

ARG TARGETOS

ARG TARGETARCH

RUN CGO_ENABLED=0 \
  GOOS=${TARGETOS} \
  GOARCH=${TARGETARCH} \
  go build \
  -trimpath \
  -ldflags '-w -s -buildid=' \
  -v -o gzcaas

# Server
FROM whatwewant/zmicro:v1.24

LABEL MAINTAINER="Zero<tobewhatwewant@gmail.com>"

LABEL org.opencontainers.image.source="https://github.com/go-zoox/gzcaas"

RUN zmicro update -a && apt update -y

RUN zmicro package install rsync

RUN zmicro package install ossfs

RUN zmicro package install kubectl

RUN zmicro package install helm

# RUN zmicro fn pm::npm i -g zx

ENV MODE=production

RUN zmicro plugin install eunomia@v1.20.38

COPY entrypoint.sh /entrypoint.sh

COPY --from=builder /build/gzcaas /bin

# Remove the origin entrypoint
# ENTRYPOINT []
# CMD /entrypoint.sh

ENV TZ=Asia/Shanghai HOME=/root

CMD gzcaas server
