FROM tap-base-binary:binary-jessie

WORKDIR /root/

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y openssl

COPY target/openresty /opt/openresty

COPY target/lua-resty-*/lib/resty/*.lua /opt/openresty/lualib/resty/

ENV PATH=/opt/openresty/nginx/sbin:$PATH

VOLUME ["/root/conf", "/root/logs", "/root/libs", "/etc/krb5.conf", "/var/krb5kdc/cacert.pem", "/tmp"]

EXPOSE 8080

ENTRYPOINT ["nginx", "-p", "/root"]

CMD ["-c", "conf/nginx.conf"]
