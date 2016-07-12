FROM tap-base-binary:binary-jessie

WORKDIR /root/

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y wget libreadline-dev libncurses5-dev libpcre3-dev libssl-dev perl make build-essential && \
    mkdir scripts

ADD build.sh scripts/

VOLUME /opt 
CMD ["scripts/build.sh", "/opt"]
