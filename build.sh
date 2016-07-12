#!/bin/bash
TARGET_DIR_NAME=$1
OPEN_RESTY_SOURCE="openresty-1.9.15.1"

if [ ! -f ${TARGET_DIR_NAME}/${OPEN_RESTY_SOURCE}.tar.gz ] 
then
  wget -P ${TARGET_DIR_NAME} https://openresty.org/download/${OPEN_RESTY_SOURCE}.tar.gz && /
  tar xvf ${TARGET_DIR_NAME}/${OPEN_RESTY_SOURCE}.tar.gz -C ${TARGET_DIR_NAME} 
fi

cd ${TARGET_DIR_NAME}/${OPEN_RESTY_SOURCE}
./configure --prefix=/opt/openresty \
            --with-pcre-jit \
            --with-ipv6 \
            --with-debug \
            -j2 
make
make install
