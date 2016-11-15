FROM tapimages.us.enableiot.com:8080/tap-base-binary:binary-jessie

WORKDIR /root/

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y wget libreadline-dev libncurses5-dev libpcre3-dev libssl-dev perl make build-essential git && \
    mkdir scripts

ADD build.sh scripts/

VOLUME ["/opt", "/target"]
CMD ["scripts/build.sh", "/opt", "/target"]
