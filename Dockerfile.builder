# Building Tool and SPIRE Server / SPIRE Agent
# Build stage
ARG goversion
ARG PLATFORM

FROM --platform=${PLATFORM} golang:${goversion}-alpine as spire-builder
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && \
    apk add build-base file bash clang lld pkgconfig git make
ENV CGO_ENABLED=0
RUN go env -w GO111MODULE=on && \
    go env -w GOPROXY="https://goproxy.cn|direct" && \
    go env -w GOSUMDB="sum.golang.google.cn"
