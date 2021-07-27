FROM openresty/openresty:1.19.3.2-2-bionic-amd64

# install dependencies
RUN ["luarocks", "install", "lua-resty-session"]
RUN ["luarocks", "install", "lua-resty-http"]
RUN ["luarocks", "install", "lua-resty-jwt"]
RUN ["luarocks", "install", "lua-resty-openidc"]

RUN apt-get update
RUN apt install -y python3-pip git

ARG AUTH_SCRIPT_REPO=https://gitlab.digital.homeoffice.gov.uk/acp/kibana-rbac-generator.git
ARG AUTH_SCRIPT_REPO_TAG=master

RUN git clone --depth 1 --branch ${AUTH_SCRIPT_REPO_TAG} ${AUTH_SCRIPT_REPO}
