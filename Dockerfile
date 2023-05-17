FROM openresty/openresty:1.21.4.1-7-bionic

# update all packages
RUN apt-get update && apt-get upgrade -y

# install dependencies
RUN luarocks install lua-resty-session \
    && luarocks install lua-resty-http \
    && luarocks install lua-resty-jwt \
    && luarocks install lua-resty-openidc 1.7.4

# create directories for default writable paths and certs
RUN mkdir -p /var/run/openresty /certs

# create non-root user
RUN useradd -u 1000 nginx \
    && chown -R nginx:nginx \
      /var/run/openresty \
      /usr/local/openresty/nginx/conf \
      /usr/local/openresty/nginx/logs \
      /certs

USER 1000

# generate self-signed cert
RUN openssl req -x509 -newkey rsa:2048 -nodes -keyout /certs/tlskey.key -out /certs/tlscert.crt -days 365 -subj '/CN=localhost'

# add default configuration files
COPY config/ /usr/local/openresty/nginx/conf/

COPY entrypoint.sh /entrypoint.sh

WORKDIR /usr/local/openresty/nginx

# default ports
EXPOSE 8080 10443

CMD ["/entrypoint.sh"]
