#!/bin/bash
TARGET_DIR_NAME=$1
LUA_LIB_DIR=$2
OPEN_RESTY_SOURCE="openresty-1.9.15.1"

if [ ! -f ${TARGET_DIR_NAME}/${OPEN_RESTY_SOURCE}.tar.gz ] 
then
  wget -P ${TARGET_DIR_NAME} https://openresty.org/download/${OPEN_RESTY_SOURCE}.tar.gz && /
  tar xvf ${TARGET_DIR_NAME}/${OPEN_RESTY_SOURCE}.tar.gz -C ${TARGET_DIR_NAME} 
fi

if [ ! -f ${LUA_LIB_DIR}/lua-resty-hmac ]
then
  git clone https://github.com/jkeys089/lua-resty-hmac.git ${LUA_LIB_DIR}/lua-resty-hmac
fi 

if [ ! -f ${LUA_LIB_DIR}/lua-resty-jwt ]
then
  git clone https://github.com/SkyLothar/lua-resty-jwt.git ${LUA_LIB_DIR}/lua-resty-jwt
fi

if [ ! -f ${LUA_LIB_DIR}/lua-resty-rsa ]
then
  git clone https://github.com/doujiang24/lua-resty-rsa.git ${LUA_LIB_DIR}/lua-resty-rsa 
fi

cd ${TARGET_DIR_NAME}/${OPEN_RESTY_SOURCE}
./configure --prefix=/opt/openresty \
            --with-pcre-jit \
            --with-ipv6 \
            --with-debug \
            -j2 
make
make install
