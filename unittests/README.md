1) Creating compilation environment. 
```
cd unittests
docker build -t lua_tests_build:0.01 -f build/Dockerfile .
```

2) Compiling lua interpreter.
```
docker run --rm --volume="$PWD/target:/target" -t lua_tests_build:0.01
```

3) Assemble docker image with lua interpreter
```
docker build -t lua_tests:alpine -f assembly/Dockerfile .
```

4) Running unit tests inside prepared docker container.
```
cd ..
docker run -e LUA_PATH='/libs/?.lua;/luaunit/?.lua;/tests/mocks/?.lua;;' --rm -v "$PWD/libs:/libs" -v "$PWD/tests:/tests"  -t lua_tests:alpine lua /tests/tap-auth-tests.lua
docker run -e LUA_PATH='/libs/?.lua;/luaunit/?.lua;/tests/mocks/?.lua;;' --rm -v "$PWD/libs:/libs" -v "$PWD/tests:/tests"  -t lua_tests:alpine lua /tests/session-manager-tests.lua
```