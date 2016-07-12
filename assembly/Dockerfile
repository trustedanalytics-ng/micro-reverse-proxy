FROM tap-base-binary:binary-jessie

WORKDIR /root/

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y openssl

COPY target/openresty /opt/openresty

ENV PATH=/opt/openresty/nginx/sbin:$PATH

VOLUME ["/root/conf", "/root/logs", "/root/libs"]

EXPOSE 8080

ENTRYPOINT ["nginx", "-p", "/root"]

CMD ["-c", "conf/nginx.conf"]
