#!/bin/sh
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
LUA_SOURCE="lua-5.3.3"
if [ ! -f ${TARGET_DIR_NAME}/luaunit ]
then
  git clone https://github.com/bluebird75/luaunit.git ${TARGET_DIR_NAME}/luaunit
fi 
if [ ! -f ${TARGET_DIR_NAME}/${LUA_SOURCE}.tar.gz ] 
then
  wget -P ${TARGET_DIR_NAME} http://www.lua.org/ftp/${LUA_SOURCE}.tar.gz && /
  tar xvf ${TARGET_DIR_NAME}/${LUA_SOURCE}.tar.gz -C ${TARGET_DIR_NAME} 
fi
cd ${TARGET_DIR_NAME}/${LUA_SOURCE}
make linux test
