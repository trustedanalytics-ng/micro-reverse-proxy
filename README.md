docker build -t openresty_build:1.0 -f build/Dockerfile .
docker run --rm --volume="$PWD/target:/opt" -t openresty_build:1.0

docker build -t openresty:1.0 -f assembly/Dockerfile .
docker run --env-file ./env.list --volume="$PWD/conf:/root/conf" --volume="$PWD/logs/:/root/logs" --volume="$PWD/libs:/libs" --name "nginx" -p 8081:8080 -d -t  openresty:1.0
