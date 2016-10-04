FROM tap-base-binary:binary-jessie

WORKDIR /root/

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y openssl && mkdir -m 0775 -p /libs

COPY target/openresty /opt/openresty

COPY target/lua-resty-*/lib/resty/*.lua /opt/openresty/lualib/resty/
COPY libs/*.lua /libs/

ENV PATH=/opt/openresty/nginx/sbin:$PATH
ENV NB_USER vcap
ENV NB_UID 1000
RUN useradd -m -s /usr/sbin/nologin -d /nonexistent -N -u $NB_UID $NB_USER

EXPOSE 8080

ENTRYPOINT ["nginx", "-p", "/root"]

CMD ["-c", "conf/nginx.conf"]
