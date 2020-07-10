FROM ubuntu:20.04 as base
WORKDIR /srv/app
RUN sed -i s@/archive.ubuntu.com/@/mirrors.ustc.edu.cn/@g /etc/apt/sources.list
RUN apt-get clean && apt-get update && apt-get install -y --no-install-recommends wget python2 make g++ tzdata
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN echo 'Asia/Shanghai' > /etc/timezone
RUN cd /usr/local && wget -O node-v14.5.0-linux-x64.tar.gz --no-check-certificate https://nodejs.org/dist/v14.5.0/node-v14.5.0-linux-x64.tar.gz
RUN cd /usr/local && tar zxvf node-v14.5.0-linux-x64.tar.gz && mv node-v14.5.0-linux-x64 nodejs
RUN cd /usr/bin && ln -s /usr/local/nodejs/bin/node node && ln -s /usr/local/nodejs/bin/npm npm && chmod 777 /usr/bin/node /usr/bin/npm
RUN npm i --production --registry https://registry.npm.taobao.org -g npm node-gyp
COPY ./ ./
RUN npm i --production --registry https://registry.npm.taobao.org && npm run build

FROM nginx:1.18.0-alpine
WORKDIR /srv/app
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY --from=base /srv/app/public ./public
