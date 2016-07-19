Tap-auth-proxy.

# DESCRIPTION
Reverse proxy for hiding unsecured web applications. Solution based on [openresty](https://openresty.org) project.


# BUILDING
Building docker image containing openresty with required lua libraries:
```
 https://github.com/SkyLothar/lua-resty-jwt (JWT functions)
 https://github.com/doujiang24/lua-resty-rsa (RSA encryption functions)
```

Docker image is build in two steps:

*  First, prepare environment for compiling openresty. (Binaries goes to target dir.)
```
docker build -t openresty_build:2.0 -f build/Dockerfile .
docker run --rm --volume="$PWD/target:/opt" --volume="$PWD/target:/target" -t openresty_build:2.0
```
Second, build image with openresty binaries
```
docker build -t openresty:2.0 -f assembly/Dockerfile .
```

# PROXY CONFIGURATION
Environment variables:
*  JWT_PUBLIC_KEY - uaa public key ('-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqh...\n-----END PUBLIC KEY-----')
*  JWT_PUBLIC_KEY_FILE - uaa public key file location
*  USER_ID - uaa user id authorized for access to guarded application

Shared volumes:
*  /root/conf - nginx configuration, place to put nginx.conf
*  /root/logs - directory for nginx error, access logs
*  /root/libs - directory for tap-auth module code
*  /etc/krb5.conf - kerberos client configuratin
*  /var/krb5kdc/cacert.pem
*  /tmp - directory that holds obtained kerberos credentials

# HOW TO RUN PROXY?
```
docker run -e JWT_PUBLIC_KEY=$'-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0m59l2u9iDnMbrXHfqkO\nrn2dVQ3vfBJqcDuFUK03d+1PZGbVlNCqnkpIJ8syFppW8ljnWweP7+LiWpRoz0I7\nfYb3d8TjhV86Y997Fl4DBrxgM6KTJOuE/uxnoDhZQ14LgOU2ckXjOzOdTsnGMKQB\nLCl0vpcXBtFLMaSbpv1ozi8h7DJyVZ6EnFQZUWGdgTMhDrmqevfx95U/16c5WBDO\nkqwIn7Glry9n9Suxygbf8g5AzpWcusZgDLIIZ7JTUldBb8qU2a0Dl4mvLZOn4wPo\njfj9Cw2QICsc5+Pwf21fP+hzf+1WSRHbnYv8uanRO0gZ8ekGaghM/2H6gqJbo2nI\nJwIDAQAB\n-----END PUBLIC KEY-----' -e USER_ID='dfde9e8c-b527-4bba-9331-66045df87af3' --volume="$PWD/conf:/root/conf" --volume="$PWD/logs/:/root/logs" --volume="$PWD/libs:/libs" --volume="$PWD/tmp:/tmp" --volume="/etc/krb5.conf:/etc/krb5.conf" --volume="/var/krb5kdc/cacert.pem:/var/krb5kdc/cacert.pem" --net=poligonnet --ip 172.18.0.6 --dns=172.17.0.1 -h nginx.localnet --name "nginx" -p 8081:8080 -d -t  openresty:2.0
```
or
```
docker run -e JWT_PUBLIC_KEY_FILE='/tmp/key.pem' -e USER_ID='dfde9e8c-b527-4bba-9331-66045df87af3' --volume="$PWD/conf:/root/conf" --volume="$PWD/logs/:/root/logs" --volume="$PWD/libs:/libs" --volume="$PWD/tmp:/tmp" --volume="/etc/krb5.conf:/etc/krb5.conf" --volume="/var/krb5kdc/cacert.pem:/var/krb5kdc/cacert.pem" --net=poligonnet --ip 172.18.0.6 --dns=172.17.0.1 -h nginx.localnet --name "nginx" -p 8081:8080 -d -t  openresty:2.0
```

curl -H "Authorization: Bearer `uaac context jojo | grep access_token | sed -e 's/access_token\:\ //' | sed -e 's/^[ \t]*//'`" -X GET http://nginx.localnet:8080
wscat -H "Authorization: Bearer `uaac context jojo | grep access_token | sed -e 's/access_token\:\ //' | sed -e 's/^[ \t]*//'`" -c ws://nginx.localnet:8080/websockets/