FROM openresty/openresty:1.19.3.2-2-bionic-amd64

# install dependencies
RUN ["luarocks", "install", "lua-resty-session"]
RUN ["luarocks", "install", "lua-resty-http"]
RUN ["luarocks", "install", "lua-resty-jwt"]
RUN ["luarocks", "install", "lua-resty-openidc"]

RUN apt install -y python3-pip
