FROM node:14.5.0-alpine as base
WORKDIR /srv/app
RUN echo https://mirrors.ustc.edu.cn/alpine/v3.12/main/ > /etc/apk/repositories
RUN echo https://mirrors.ustc.edu.cn/alpine/v3.12/community/ >> /etc/apk/repositories
RUN apk update && apk upgrade --available
RUN apk add --no-cache -U python2 make g++
COPY ./package.json ./package.json
RUN npm i --registry https://registry.npm.taobao.org

FROM node:14.5.0-alpine as build
WORKDIR /srv/app
COPY --from=base /srv/app/node_modules ./node_modules
COPY ./ ./
RUN npm i --production --registry https://registry.npm.taobao.org -g hexo && hexo g --debug

FROM nginx:1.18.0-alpine
WORKDIR /srv/app
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY --from=build /srv/app/public ./public
