[![Build Status](https://app.travis-ci.com/minidfx/elixir-reverse-proxy.svg?branch=main)](https://app.travis-ci.com/minidfx/elixir-reverse-proxy)
[![Last Updated](https://img.shields.io/github/last-commit/minidfx/elixir-reverse-proxy.svg)](https://github.com/minidfx/elixir-reverse-proxy/commits/master)

# Couloir42ReverseProxy

This is standalone reverse proxy dockerized implementing the [elixir-reverse-proxy](https://github.com/tallarium/reverse_proxy_plug) plug. The goal of the project is to be able to easily configure domains for automatically generating/renewing the SSL certificates using cerbot. Optionaly you can protect your upstreams using the basic authentication.

## Quick start

Update the **docker-compose.yml** with your preferences.

Then you have to set your **EMAIL** as the environment variable and the **UPSTREAMS** for generating the SSL certificates and forwarding the requests to your internal backends.

For instance, the current **docker-compose.yml** file contains 2 upstreams configuration separated by a comma: `<domain>=<upstream-host>,<domain>=<upstream-host>,...`

### Example

```yaml
version: "3.9"
services:
  proxy:
    build: .
    image: minidfx/reverse-proxy:alpha
    ports:
      - 80:80
      - 443:443
    environment:
      - PASSWORDS=foo.localhost=dXNlcm5hbWU6cGFzc3dvcmQ= # protect the foo.localhost domain with following the username 'username' and the password 'password'.
      - UPSTREAMS=foo.localhost=http://www.example.com,bar.localhost=http://www.perdu.com
      - STAGING=<true|false> # Set to true for test purpose
      - EMAIL=<your-email>
```

Then run it by executing the following command

```shell
docker-compose up
```

Have fun!

## SSL

By default, **a self-signed certificate is used** for securing the communication but a background process will try to generate an SSL certificate for the given domains.

**IMPORTANT**: Your custom domains MUST be reachable to successfully generate the certificates for your domains.

For generating the certificate, [certbot](https://certbot.eff.org) is used.

## Basic authentication (optional)

You have the opportunity to protect some domains by adding the **PASSWORDS** environment variable too: `<domain>=<password-encoded-in-base64>,<domain>=<password-encoded-in-base64>,...`

**TIPS**: You can encode the passwords using the following command:

```shell
echo -n "username:password" | base64
```

TODO

- Add telemetry for monitoring the reverse proxy
- Support websocket
