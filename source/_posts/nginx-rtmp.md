---
title: nginx+rtmp搭建直播服务器
date: 2020-07-16 14:07:41
cover: /images/nginx-rtmp/rtmp.png
coverWidth: 1200
coverHeight: 630
tags:
 - nginx
 - rtmp
 - 直播
categories: 
 - 技术文章
---

最近有朋友入职直播公司，在闲聊的过程中，激起了对直播业务的兴趣，很想去了解一下是怎么实现的。经过一翻搜索，发现比较主流的是nginx+rtmp方案，今天就来学习一下这个是怎么实现的。

今天的目标就是搭建一个<a href="javascript:void(0)">可以推流/拉流</a>的服务器，实现一个直播业务最简单的闭环。

## 知识扫盲

我们先了解一下先关的知识：

**1.RTMP**
实时消息传输协议，Real Time Messaging Protocol，是 Adobe Systems 公司为 Flash 播放器和服务器之间音频、视频和数据传输开发的开放协议。协议基于 TCP，是一个协议族，包括 RTMP 基本协议及 RTMPT/RTMPS/RTMPE 等多种变种。RTMP 是一种设计用来进行实时数据通信的网络协议，主要用来在 Flash/AIR 平台和支持RTMP协议的流媒体/交互服务器之间进行音视频和数据通信。这种方式的实时性比较强，基本能保证延迟在1-2s内，是现在国内直播主要采用的方式之一；不过使用这种协议，就必须安装flash，而H5、IOS、Android并不能原生支持flash，因此这种协议能流行多久，就不得而知了，毕竟移动端才是现在的主流。

**2.HLS**
hls是Apple推出的直播协议，是通过视频流切片成文件片段来直播的。客户端首先会请求一个m3u8文件，里面会有不同码率的流，或者直接是ts文件列表，通过给出的ts文件地址去依次播放。在直播的时候，客户端会不断请求m3u8文件，检查ts列表是否有新的ts切片。这种方式的实时性较差，不过优势是H5、IOS、Android都原生支持。

**3.HTTP-FLV**
HTTP-FLV就是对RTMP协议的封装，相比于RTMP，它是一个开放的协议。因此他具备了RTMP的实时性和RTMP不具备的开发性，而且随着flv.js出现（感谢B站），使得浏览器在不依赖flash的情况下，播放flv视频，从而兼容了移动端，所以现在很多直播平台，尤其是手机直播平台，都会选择它

## 环境搭建

环境搭建的第一步，安装带有 nginx-rtmp-module 模块的nginx，这不是本文讨论的范畴，如果对 nginx 安装不熟悉的同学，请搜索相关文章，或者如果想方便的同学，可以直接使用 <a href="https://github.com/share-group/shell/blob/master/install-nginx-quic.sh" target="_blank">nginx-quic安装脚本</a> 进行安装，脚本里面已经整合了 nginx-http-flv-module 模块 (nginx-http-flv-module 是基于 nginx-rtmp-module 开发的，功能比它更多，运行更稳定)，在 centos 7 / 8 系列的系统是可以顺利安装的。

环境搭建的第二步，编辑 nginx 配置文件，让 nginx-rtmp-module 模块 on work。

我们先按照官方给的demo操作一下：
```nginx

#在 nginx.conf 文件新增 rtmp 模块
rtmp {
	server {
		listen 1935;
		application myapp {
			live on;
		}
	}
}

#在 nginx.conf 文件的 http 模块加入以下内容
server {
	listen 80;
	listen [::]:80;
	server_name live.ruanzhijun.cn;
	rewrite ^/(.*) https://$host/$1 permanent;
}

server {
	listen 443 ssl http2;
	listen 443 http3;
	listen [::]:443 ssl http2;
	listen [::]:443 http3;
	server_name live.ruanzhijun.cn;
	autoindex off;

	location /stat {
		rtmp_stat all;
		rtmp_stat_stylesheet stat.xsl;
	}

	location /stat.xsl {
		root /install/install/nginx-http-flv-module-1.2.7/;
	}

	location /control {
		rtmp_control all;
	}

	location /rtmp-publisher {
		root /install/install/nginx-http-flv-module-1.2.7/test;
	}

	location / {
		root /install/install/nginx-http-flv-module-1.2.7/test/www;
	}
}
```

重启 nginx，分别访问 <a href="https://live.ruanzhijun.cn/record.html" target="_blank">推流端</a>、<a href="https://live.ruanzhijun.cn" target="_blank">拉流端</a>，已经可以实现这边录像那边播放了，还可以看到<a href="https://live.ruanzhijun.cn/stat" target="_blank">数据统计</a>。

需要注意有两点：
1.上面的配置中 /install/nginx-rtmp-module-1.2.1 是我服务器的实际路径，请按照你实际的路径修改，其他可以照抄
2.demo上面的地址是localhost，我是把它换成 <a href="javascript:void(0)">live.ruanzhijun.cn</a> 的

![](/images/nginx-rtmp/record.png)
![](/images/nginx-rtmp/play.png)
![](/images/nginx-rtmp/stat.png)

好了，官方的demo就体验完了。但是官方的demo是基于flash实现的，flash已经过时了，有时间再研究一下这块。