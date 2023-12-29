FROM alpine:3.19.0
RUN apk add \
    xz \
    curl \
    bash \
    make \
    file \
    jq \
    uuidgen \
    rsync

WORKDIR /src

ENV VERSION="0.1.0"
ENTRYPOINT ["/bin/sh", "-c"]