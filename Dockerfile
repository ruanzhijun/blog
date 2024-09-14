FROM nginx:1.26.2-alpine
WORKDIR /srv/app
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./public ./public
