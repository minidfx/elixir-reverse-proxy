# Couloir42ReverseProxy

The goal of the project is to be able to create a reverse proxy with SSL termination by implementating the [elixir-reverse-proxy](https://github.com/tallarium/reverse_proxy_plug) plug and with **the opportunity** to disable the forwarding requests if needed, adding an authentication, etc.

## Quick start

Update the **docker-compose.yml** with your preferences.

Then you have to set your **EMAIL** as the environment variable and the **UPSTREAMS** for generating the SSL certificates and forwarding the requests to your internal backends.

For instance, the current **docker-compose.yml** file contains 2 upstreams configuration separated by a comma: `<domain>=<upstream-host>,<domain>=<upstream-host>,...`

### Example

```docker
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

```bash
docker-compose up
```

Have fun!

## SSL

By default, **a self-signed certificate is used** for securing the communication but a background process will try to generate an SSL certificate for the given domains.

**IMPORTANT**: You custom domains MUST be reachable to successfully generate the certificates for your domains.

For generating the certificate, [certbot](https://certbot.eff.org) is used.

## Basic authentication (optional)

You have the opportunity to protect some domains by adding the **PASSWORDS** environment variable too: `<domain>=<password-encoded-in-base64>,<domain>=<password-encoded-in-base64>,...`

**TIPS**: You can encode the passwords using the following command:

```bash
echo -n "username:password" | base64
```