Reverse proxy that can hide unsecured TAP apps.

Building docker image.

docker build -t openresty_build:2.0 -f build/Dockerfile .
docker run --rm --volume="$PWD/target:/opt" --volume="$PWD/target:/target" -t openresty_build:2.0
docker build -t openresty:2.0 -f assembly/Dockerfile .

Runing proxy.

docker run -e JWT_PUBLIC_KEY=$'-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0m59l2u9iDnMbrXHfqkO\nrn2dVQ3vfBJqcDuFUK03d+1PZGbVlNCqnkpIJ8syFppW8ljnWweP7+LiWpRoz0I7\nfYb3d8TjhV86Y997Fl4DBrxgM6KTJOuE/uxnoDhZQ14LgOU2ckXjOzOdTsnGMKQB\nLCl0vpcXBtFLMaSbpv1ozi8h7DJyVZ6EnFQZUWGdgTMhDrmqevfx95U/16c5WBDO\nkqwIn7Glry9n9Suxygbf8g5AzpWcusZgDLIIZ7JTUldBb8qU2a0Dl4mvLZOn4wPo\njfj9Cw2QICsc5+Pwf21fP+hzf+1WSRHbnYv8uanRO0gZ8ekGaghM/2H6gqJbo2nI\nJwIDAQAB\n-----END PUBLIC KEY-----' -e USER_ID='dfde9e8c-b527-4bba-9331-66045df87af3' --volume="$PWD/conf:/root/conf" --volume="$PWD/logs/:/root/logs" --volume="$PWD/libs:/libs" --volume="$PWD/tmp:/tmp" --volume="/etc/krb5.conf:/etc/krb5.conf" --volume="/var/krb5kdc/cacert.pem:/var/krb5kdc/cacert.pem" --net=poligonnet --ip 172.18.0.6 --dns=172.17.0.1 -h nginx.localnet --name "nginx" -p 8081:8080 -d -t  openresty:2.0

or

docker run -e JWT_PUBLIC_KEY_FILE='/tmp/key.pem' -e USER_ID='dfde9e8c-b527-4bba-9331-66045df87af3' --volume="$PWD/conf:/root/conf" --volume="$PWD/logs/:/root/logs" --volume="$PWD/libs:/libs" --volume="$PWD/tmp:/tmp" --volume="/etc/krb5.conf:/etc/krb5.conf" --volume="/var/krb5kdc/cacert.pem:/var/krb5kdc/cacert.pem" --net=poligonnet --ip 172.18.0.6 --dns=172.17.0.1 -h nginx.localnet --name "nginx" -p 8081:8080 -d -t  openresty:2.0
