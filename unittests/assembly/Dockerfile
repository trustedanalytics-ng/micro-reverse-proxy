FROM alpine
ADD target/lua-5.3.3/src/lua /usr/local/bin/
ADD target/lua-5.3.3/src/luac /usr/local/include/
ADD target/lua-5.3.3/src/lua.hpp /usr/local/include/
ADD target/lua-5.3.3/src/lua*.h /usr/local/include/ 
ADD target/lua-5.3.3/src/liblua.a /usr/local/lib/ 
ADD target/luaunit/luaunit.lua /luaunit/

RUN apk update && \
    apk add readline 
