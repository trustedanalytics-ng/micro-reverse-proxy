# Tap-auth-proxy.
Reverse proxy for hiding/guard unsecured web applications. Solution based on [openresty](https://openresty.org) project.

## DESCRIPTION
Check user access and forward http/websockets requests to guarded web application.
Verification on the basis of JWT token, obtained from "Authorization:" header. Checks token signature, expiration time
and user_id (if user_id equals the value from USER_ID environment variable).

## BUILDING
Building docker image containing openresty with required lua libraries:
```
 https://github.com/SkyLothar/lua-resty-jwt (JWT functions)
 https://github.com/doujiang24/lua-resty-rsa (RSA encryption functions)
```

Before start building you have to get base image. Bellow you can find link to repo with scripts that facilitate that.:
```
https://github.com/intel-data/tapng-base-images/tree/master/binary/binary-jessie
```

Docker image is build in two steps:

* First, prepare environment for compiling openresty. (docker run starts compilation, binaries goes to target dir.)
```
docker build -t openresty_build:2.0 -f build/Dockerfile .
docker run --rm --volume="$PWD/target:/opt" --volume="$PWD/target:/target" -t openresty_build:2.0
```
* Second, build image with openresty binaries
```
docker build -t openresty:2.0 -f assembly/Dockerfile .
```

## PROXY CONFIGURATION
Environment variables:
*  JWT_PUBLIC_KEY - uaa public key (i.e.: '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqh...\n-----END PUBLIC KEY-----')
*  JWT_PUBLIC_KEY_FILE - uaa public key file location
*  USER_ID - uaa user id authorized for access to guarded application
*  NB_USER - user name that nginx processes run with (default: vcap)
*  NB_UID - user id that nginx processes run with (default: 1000)
*  OAUTH_CLIENT_ID - oauth client id
*  OAUTH_CLIENT_SECRET - oauth client secret
*  UAA_URL - uaa

Shared volumes:
*  /root/conf - nginx configuration, place to put nginx.conf
*  /root/logs - directory for nginx error, access logs
*  /libs - directory for tap-auth module code
*  /etc/krb5.conf - kerberos client configuratin
*  /var/krb5kdc/cacert.pem certificat used in pre-authentication phase
*  /tmp - directory that holds obtained kerberos credentials (krb5cc)

## HOW TO RUN PROXY?
on your local machine.
```
docker run -e JWT_PUBLIC_KEY=$'-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqh...\n-----END PUBLIC KEY-----' -e USER_ID='dfde9e8c-b527-4bba-9331-66045df87af3' --volume="$PWD/conf:/root/conf" --volume="$PWD/logs/:/root/logs" --volume="$PWD/libs:/libs" --volume="$PWD/tmp:/tmp" --volume="/etc/krb5.conf:/etc/krb5.conf" --volume="/var/krb5kdc/cacert.pem:/var/krb5kdc/cacert.pem" --net=poligonnet --ip 172.18.0.6 --dns=172.17.0.1 -h nginx.localnet --name "nginx" -p 8081:8080 -d -t  openresty:2.0
```
or
```
docker run -e JWT_PUBLIC_KEY_FILE='/tmp/key.pem' -e OAUTH_CLIENT_ID='nginx' -e OAUTH_CLIENT_SECRET='nginxsecret' -e USER_ID='abf116c7-e03b-4c94-a574-df537173b9d4' --volume="$PWD/conf:/root/conf" --volume="$PWD/logs/:/root/logs" --volume="$PWD/libs:/libs" --volume="$PWD/tmp:/tmp" --volume="/etc/krb5.conf:/etc/krb5.conf" --volume="/var/krb5kdc/cacert.pem:/var/krb5kdc/cacert.pem" --net=poligonnet --ip 172.18.0.6 --dns=172.17.0.1 -h nginx.localnet --name "nginx" -p 8081:8080 -d -t  openresty:2.01
```
For correctnes verification you can use this example commands:
```
curl -H "Authorization: Bearer `uaac context jojo | grep access_token | sed -e 's/access_token\:\ //' | sed -e 's/^[ \t]*//'`" -X GET http://nginx.localnet:8080
wscat -H "Authorization: Bearer `uaac context jojo | grep access_token | sed -e 's/access_token\:\ //' | sed -e 's/^[ \t]*//'`" -c ws://nginx.localnet:8080/websockets
```
