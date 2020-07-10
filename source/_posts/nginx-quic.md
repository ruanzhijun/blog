---
title: nginx原生支持quic
date: 2020-07-10 12:21:30
cover: /images/nginx-quic/quic.png
coverWidth: 2000
coverHeight: 1747
tags:
 - nginx
 - quic
categories: 
 - 运维相关
---

2020 年 6 月 10 日 Nginx 官方博客发文 <a href="https://www.nginx.com/blog/introducing-technology-preview-nginx-support-for-quic-http-3/" target="_blank">Introducing a Technology Preview of NGINX Support for QUIC and HTTP/3</a>，同时对外发布了 <a href="https://hg.nginx.org/nginx-quic/shortlog/quic" target="_blank">支持 QUIC 版 Nginx 的代码</a> 和 <a href="https://quic.nginx.org/readme.html" target="_blank">部署说明</a>，从此体验 QUIC 又多了一个选择，马上体验一下。

## 准备工作
+ 由于 openssl 暂时还不支持 quic，所以这个版本的 ssl 库需要用 boringssl
+ 编译 boringssl，需要的基础设施就更多了，需要最新版的 go，libunwind (centos 7 可以 yum，centos 8 只能编译)，cmake版本要3.0+，cmake是用来编译 boringssl 的，libunwind 是 boringssl 的依赖库
+ boringssl 是不支持 ocsp，如果一向玩 openssl 的同学转过来想要认证自己的证书的话，还要打个让 boringssl 支持 ocsp 的补丁

## 开始编译
编译过程总体来说还是挺顺畅的，之前看到的教程说有报错的都修复了

## 修改配置
为了可以使用 quic，需要修改 nginx 一些才配置可以生效
```nginx
# http3 reuseport，这个就是开启 nginx quic 功能的，并且 reuseport 只可以声明一次
# 即：如果你有n个站点都想上 quic，那么你只需要在某一个站点加了这个 reuseport 就可以了，加多了会报错
listen 443 ssl http2;
listen 443 http3 reuseport;
listen [::]:443 ssl http2;
listen [::]:443 http3 reuseport;

# TLS 一定要有 1.3，其他随意
ssl_protocols TLSv1.3;

# 开启 0-RTT
ssl_early_data on;

# 加header，告诉浏览器，这个站点提供 quic 服务，可以尝试连接
add_header alt-svc 'quic=":443"; ma=2592000; v="46,43",h3-27=":443"; ma=2592000,h3-25=":443"; ma=2592000,h3-T050=":443"; ma=2592000,h3-Q050=":443"; ma=2592000,h3-Q049=":443"; ma=2592000,h3-Q048=":443"; ma=2592000,h3-Q046=":443"; ma=2592000,h3-Q043=":443"; ma=2592000';
```

## 测试
有一个网址，是可以帮你测试你的站点是否支持 quic 服务的，<a href="https://http3check.net" target="_blank">https://http3check.net</a>，当你看到下图这样的字样的时候，就证明你的 quic 服务已经搭建成功
但是，我一直看不到【0-RTT】的字样，原因目前还没找到
![](/images/nginx-quic/quic-check-result.png)

## 浏览器
目前支持 quic 的浏览器也很少，而且都是实验性功能，没有明确开放出来的，要自己手动开启，以 Chrome 85 为例，浏览器地址栏输入：<a href="chrome://flags/" target="_blank">chrome://flags/</a> 回车，依次搜 quic/TLS 1.3/TLS 1.3 Early Data ，分别开启 enable 并重启浏览器，然后你的浏览器就支持 quic 了

Chrome 的用户，还可以安装一个插件：<a href="https://chrome.google.com/webstore/detail/http2-and-spdy-indicator/mpbpobfflnpcgagjijhmgnchggcjblin" target="_blank">HTTP/2 and SPDY indicator</a>，当你访问的网站支持 quic 时候，会显示出绿色的闪电

## 结语
坑终于踩完，我把这次体验的成果写成 <a href="https://github.com/share-group/shell/blob/master/install-nginx-quic.sh" target="blank">一个 shell 脚本</a>

但是我这个 quic 服务不是很稳定，试用 <a href="https://http3check.net" target="_blank">https://http3check.net</a> 测试的时候，一下成功，一下不成功，而且始终都没有出现 0-RTT