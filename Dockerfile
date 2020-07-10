FROM ubuntu:20.04 as base
WORKDIR /srv/app
RUN sed -i s@/archive.ubuntu.com/@/mirrors.ustc.edu.cn/@g /etc/apt/sources.list
RUN apt-get clean && apt-get update && apt-get install -y --no-install-recommends python2 make g++ tzdata
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN echo 'Asia/Shanghai' > /etc/timezone
RUN cd /usr/local && wget -O node-v12.18.2-linux-x64.tar.gz https://install.ruanzhijun.cn/node-v12.18.2-linux-x64.tar.gz && mv node-v12.18.2-linux-x64 nodejs
RUN cd /usr/bin && ln -s /usr/local/nodejs/bin/node node && ln -s /usr/local/nodejs/bin/npm npm && chmod 777 /usr/bin/node /usr/bin/npm
RUN npm i --production --registry https://registry.npm.taobao.org -g npm node-gyp
COPY ./package.json ./package.json
RUN npm i --production --registry https://registry.npm.taobao.org

FROM ubuntu:20.04 as build
WORKDIR /srv/app
COPY --from=base /usr/local/nodejs /usr/local/nodejs
RUN cd /usr/bin && ln -s /usr/local/nodejs/bin/node node && ln -s /usr/local/nodejs/bin/npm npm && chmod 777 /usr/bin/node /usr/bin/npm
COPY --from=base /srv/app/node_modules ./node_modules
COPY ./ ./
RUN npm i --production --registry https://registry.npm.taobao.org -g hexo && hexo g

FROM nginx:1.18.0-alpine
WORKDIR /srv/app
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY --from=build /srv/app/public ./public
