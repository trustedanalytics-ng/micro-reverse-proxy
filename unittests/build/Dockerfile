FROM alpine

WORKDIR /root/

RUN apk update && \
    apk add wget alpine-sdk && \
    apk add readline && \
    mkdir scripts
RUN apk add readline-dev

ADD build.sh scripts/

CMD ["/root/scripts/build.sh", "/target"]
