# Couloir42ReverseProxy

The goal of the project is to be able to create a reverse proxy with SSL termination by implementating the [elixir-reverse-proxy](https://github.com/tallarium/reverse_proxy_plug) plug and with **the opportunity** to disable the forwarding requests if needed.

## Installation

The best way to use this reverse proxy is by using Docker. Clone this project a run the following command.

> docker-compose up

For test purpose, the command will proxy the requests made to https://foorbar.localhost to http://www.example.com.

## Configuration

To configure the domains and the server targets, the environment UPSTREAMS has to be configured.

For instance, the value for the **UPSTREAMS** environment variable with 

> foobar.localhost=http://www.example.com

 will proxy the requests to the domain **foobar.localhost** to **www.example.com** on the port **80**.

 If need more proxy, you can just set UPSTREAMS with additional servers using the separator **,**

 > foo.localhost=http://www.example.com,bar.localhost=http://www.perdu.com

## SSL

For test purpose a dummy certificate is used but you can set another certificate by replacing the files **priv/cert/cert.pem** and **priv/cert/key.pem**.

## TODO

Implement certbot for generating and renewing SSL certificates with the passing domain in the UPSTREAMS environnment variable.