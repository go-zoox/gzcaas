# Builder
FROM --platform=$BUILDPLATFORM whatwewant/builder-go:v1.20-1 as builder

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

RUN zmicro plugin install eunomia

RUN zmicro package install rsync

RUN zmicro package install ossfs

ENV MODE=production

COPY entrypoint.sh /entrypoint.sh

COPY --from=builder /build/gzcaas /bin

CMD /entrypoint.sh
