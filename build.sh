#!/bin/bash
# Copyright (c) 2017 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
