#!/bin/sh
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
