FROM openresty/openresty:1.19.3.2-2-bionic

# install dependencies
RUN luarocks install lua-resty-session \
    && luarocks install lua-resty-http \
    && luarocks install lua-resty-jwt \
    && luarocks install lua-resty-openidc

# create directories for default writable paths
RUN mkdir -p /var/run/openresty

# create non-root user
RUN useradd -u 1000 nginx \
    && chown -R nginx:nginx \
      /var/run/openresty \
      /usr/local/openresty/nginx/conf \
      /usr/local/openresty/nginx/logs

USER 1000

# default config
COPY config/ /usr/local/openresty/nginx/conf/

COPY entrypoint.sh /entrypoint.sh

WORKDIR /usr/local/openresty

# default ports (can be changed at runtime)
EXPOSE 8080 10443

CMD ["/entrypoint.sh"]
