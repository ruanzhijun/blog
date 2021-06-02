FROM nginx:1.20.1-alpine
WORKDIR /srv/app
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./public ./public
