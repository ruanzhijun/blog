---
title: go-client
date: 2024-11-20 12:58:04
cover: /images/go-client/cover.jpg
tags:
  - go
categories:
  - 技术文章
---

开发桌面客户端软件一直是程序员的常见任务之一，而Go语言凭借其简洁、高效以及丰富的第三方库，越来越多地被用于开发各类应用程序。今天我们将结合Go语言和HTML，使用开源项目 Sciter 的 Go 绑定库 go-sciter，为大家展示如何用最少的开发精力构建一个跨平台的桌面客户端。

## 什么是Sciter？

Sciter 是一个支持多平台的嵌入式HTML/CSS/脚本引擎，适用于构建本地桌面应用程序，且它的性能非常好。通过 go-sciter，我们可以用Go语言来调用Sciter引擎，进而使用HTML、CSS和JavaScript创建用户界面，并与Go的后端逻辑交互。

## 为什么选择Sciter？

+   **轻量级：** Sciter非常轻量，适合需要快速构建的桌面应用。
+   **跨平台：** 支持Windows、macOS和Linux操作系统。
+   **无需第三方浏览器依赖：** 与Electron不同，Sciter不需要依赖外部的浏览器引擎，极大减少了应用程序的体积。
+   **使用现代的前端技术：** 支持HTML5、CSS3和JavaScript，前端开发者可以快速上手。

## 准备工作

### 1\. 安装Go‌：‌

我们默认认为你已经安装了Go。如果没有安装，可以从 Go官网 下载并安装。安装完成后，执行以下命令确认Go是否正确安装：

```go
go version
```

**注意**  
因为是cgo开发，因此 WIndows 用户还需要安装 `mingw64-gcc`。

### 2\. 安装Sciter SDK

前往 Sciter官网 下载Sciter SDK，选择适合你操作系统的版本（Windows、macOS或Linux）。解压后将 bin 目录中的动态库文件（dll、so或dylib）放到系统的环境变量中，或者与可执行文件一起存放，具体请看 Sciter 官方文档。

**注意事项**  
由于 go-sciter 这两年没有及时更新，其实最新的 Sciter SDK 并不适合使用，因此你需要下载 `4.4.8` 版本的 Sciter SDK，太新的不行。

### 3\. 安装go-sciter

通过Go命令安装 go-sciter 包：

```go
go get github.com/sciter-sdk/go-sciter
```

## 开始编写客户端程序

为了方便举例，我以当前随手写的一个桌面应用为例，展开说明。

简单说明一下，这个项目的功能是：自动提交网站的 URL 到 Google 推送服务器。下面不是一个完整的项目代码，因为还涉及到数据库操作，网站Sitemap的扒取等等，因此只列出了重要的部分。

首先创建一个项目，我们暂且取名为 `gosciter` 吧。创建项目的过程不赘述。

将 sciter.dll 或者 `libsciter.dylib`(MacOS用户) 放到项目根目录下。

如果需要用到 sqlite 数据库，也需要拷贝 sciter-sqlite.dll 或者 sciter-sqlite.dylib 过来。我的项目用到了，因此这个文件也复制过来了。

### 编写 main.go

```go
package main

import (
	"embed"
	"encoding/json"
	"fmt"
	"github.com/ncruces/zenity"
	"github.com/sciter-sdk/go-sciter"
	"github.com/sciter-sdk/go-sciter/window"
	"github.com/skratchdot/open-golang/open"
	"log"
	"os"
	"strconv"
	"strings"
	"time"
)

// 为了让生成的可执行文件包含了界面文件，直接把views文件夹嵌入到可执行文件中

//go:embed all:views
var views embed.FS

// 定义一个Map类型的数据结构
type Map map[string]interface{}

func main() {
	w, err := window.New(sciter.SW_TITLEBAR|sciter.SW_RESIZEABLE|sciter.SW_CONTROLS|sciter.SW_MAIN|sciter.SW_ENABLE_DEBUG, &sciter.Rect{
		Left:   100,
		Top:    50,
		Right:  1100,
		Bottom: 660,
	})
	if err != nil {
		log.Fatal(err)
	}

  // 定义一个回调函数，用于处理加载资源，home 是自定义的Scheme
	w.SetCallback(&sciter.CallbackHandler{
		OnLoadData: func(params *sciter.ScnLoadData) int {
			if strings.HasPrefix(params.Uri(), "home://") {
				fileData, err := views.ReadFile(params.Uri()[7:])
				if err == nil {
					w.DataReady(params.Uri()[7:], fileData)
				}
			}
			return 0
		},
	})

  // 这里定义一些与前端交互的函数
	w.DefineFunction("openUrl", openUrl)
	w.DefineFunction("getIndexingTasks", getIndexingTasks)
	w.DefineFunction("getIndexingTask", getIndexingTask)
	w.DefineFunction("getIndexingUrls", getIndexingUrls)
	w.DefineFunction("openAccountJson", openAccountJson)
	w.DefineFunction("loadIndexingSitemap", loadIndexingSitemap)
	w.DefineFunction("createGoogleIndexing", createGoogleIndexing)
	w.DefineFunction("startGoogleIndexing", startGoogleIndexing)
	w.DefineFunction("stopGoogleIndexing", stopGoogleIndexing)
	w.DefineFunction("deleteGoogleIndexing", deleteGoogleIndexing)

  // 加载主页面
	mainView, err := views.ReadFile("views/main.html")
	if err != nil {
		fmt.Print("nofile", err)
		os.Exit(0)
	}
	w.LoadHtml(string(mainView), "")

	w.SetTitle("谷歌推送")
	w.Show()
	w.Run()
}


func openUrl(args ...*sciter.Value) *sciter.Value {
	link := args[0].String()
	_ = open.Run(link)

	return nil
}

func getIndexingTasks(args ...*sciter.Value) *sciter.Value {
	//tasks := service.GetIndexingTasks()
  var task = []Map{}
	// 返回Json格式
	return jsonValue(tasks)
}

func getIndexingTask(args ...*sciter.Value) *sciter.Value {
	index, _ := strconv.Atoi(args[0].String())
	//task := service.GetIndexingTask(index)
  task := Map{}
	// 返回Json格式
	return jsonValue(task)
}

func getIndexingUrls(args ...*sciter.Value) *sciter.Value {
	index, _ := strconv.Atoi(args[0].String())
	page, _ := strconv.Atoi(args[1].String())
	if page < 1 {
		page = 1
	}
	//urls, totalPage := service.GetIndexingUrls(index, page)
  urls := []string{}
  totalPage := 0
	// 返回Json格式
	return jsonValue(Map{"urls": urls, "page": page, "totalPage": totalPage})
}

func openAccountJson(args ...*sciter.Value) *sciter.Value {
	accountPath, err := zenity.SelectFile(zenity.Title("选择Account Json文件"), zenity.FileFilter{
		Name:     "Json file",
		Patterns: []string{"*.json"},
		CaseFold: false,
	})
	if err != nil || accountPath == "" {
		fmt.Println(err)
		return nil
	}

	return sciter.NewValue(accountPath)
}

func createGoogleIndexing(args ...*sciter.Value) *sciter.Value {
	accountPath := args[0].String()
	domain := args[1].String()
	tmpNum := args[2].String()
	dailyNum, _ := strconv.Atoi(tmpNum)

	if dailyNum == 0 {
		dailyNum = 200
	}
	if !strings.HasPrefix(domain, "http") {
		return sciter.NewValue("网址填写错误")
	}
	// err := service.CreateIndexing(accountPath, domain, dailyNum)
	// if err != nil {
	// 	return sciter.NewValue(err.Error())
	// }

	return nil
}

func loadIndexingSitemap(args ...*sciter.Value) *sciter.Value {
	index, _ := strconv.Atoi(args[0].String())

	// err := service.LoadIndexingSitemap(index, false)
	// if err != nil {
	// 	return sciter.NewValue(err.Error())
	// }

	return nil
}

func startGoogleIndexing(args ...*sciter.Value) *sciter.Value {
	index, _ := strconv.Atoi(args[0].String())

	// err := service.StartGoogleIndexing(index)

	// if err != nil {
	// 	return sciter.NewValue(err.Error())
	// }

	return nil
}

func stopGoogleIndexing(args ...*sciter.Value) *sciter.Value {
	index, _ := strconv.Atoi(args[0].String())

	//service.StopGoogleIndexing(index)

	return nil
}

func deleteGoogleIndexing(args ...*sciter.Value) *sciter.Value {
	index, _ := strconv.Atoi(args[0].String())

	// 需要先stop
	// service.StopGoogleIndexing(index)
	// // 最后删除
	// service.DeleteIndexingTask(index)

	return nil
}

func jsonValue(val interface{}) *sciter.Value {
	buf, err := json.Marshal(val)
	if err != nil {
		return nil
	}
	return sciter.NewValue(string(buf))
}
```

### 编写 views/main.html

主页面没有什么特别之处，只是使用了自定义的scheme `home://`

```html
<html resizeable>
<head>
    <style src="home://views/style.css" />
    <meta charSet="utf-8" />
</head>
<body>
<div class="layout">
    <div class="aside">
        <h1 class="soft-title"><a href="home://views/main.html">谷歌<br/>推送助手</a></h1>
        <div class="aside-menus">
            <a href="home://views/task.html" class="menu-item">推送任务</a>
            <a href="home://views/help.html" class="menu-item">使用教程</a>
        </div>
    </div>
    <div class="container">
        <div class="home">
            <div>欢迎使用 谷歌推送助手</div>
            <div class="start-control">
                <a href="home://views/task.html" class="start-btn">开始使用</a>
            </div>
        </div>
    </div>
</div>

</body>
</html>
```

### 编写 views/task.html

主要的任务界面，这里则进行了列表渲染，上下翻页，以及按钮操作等处理。

```html
<html resizeable>
<head>
    <style src="home://views/style.css" />
    <meta charSet="utf-8" />
</head>
<body>
<div class="layout">
    <div class="aside">
        <h1 class="soft-title"><a href="home://views/main.html">谷歌<br/>推送助手</a></h1>
        <div class="aside-menus">
            <a href="home://views/task.html" class="menu-item active">推送任务</a>
            <a href="home://views/help.html" class="menu-item">使用教程</a>
        </div>
    </div>
    <div class="container">
        <div class="task-head">
            <button #newTask>新建任务</button>
        </div>
        <table class="task-list" #taskList>
                <colgroup>
                    <col width="30%">
                    <col width="15%">
                    <col width="15%">
                    <col width="15%">
                    <col width="30%">
                </colgroup>
                <thead>
                    <tr>
                        <th>站点域名</th>
                        <th>URL数量</th>
                        <th>已推送/每日推送</th>
                        <th>状态</th>
                        <th>操作</th>
                    </tr>
                </thead>
                <tbody>
                <tr>
                    <td colspan="5">加载中</td>
                </tr>
                </tbody>
            </table>
    </div>
    <form class="control-form" #taslForm>
            <div class="form-header">
                <a class="form-close" #resultClose>关闭</a>
                <h3>创建/编辑任务</h3>
            </div>
        <div class="form-content">
            <div class="form-item">
                <div class="form-label">网址或Sitemap地址：</div>
                <div class="input-block">
                    <input(domain) class="layui-input" type="text" placeholder="http://或https://开头的网站地址或Sitemap地址" />
                    <div class="text-muted">说明：如果填写了Sitemap地址，将自动获取Sitemap中的所有URL推送，<br/>否则将抓取推送网址下的所有链接。</div>
                </div>
            </div>
            <div class="form-item">
                <div class="form-label">选择AccountJson：</div>
                <div class="input-block text-left">
                    <div>
                        <button #selectAccountJson>选择.json文件</button>
                        <span #accountJson></span>
                    </div>
                    <div class="text-muted">说明：需要上传谷歌账号的json文件，用于授权。</div>
                </div>
            </div>
            <div class="form-item">
                <div class="form-label">每天推送数量：</div>
                <div class="input-block">
                    <input(daily_num) class="layui-input" type="text" placeholder="默认200" />
                    <div class="text-muted">说明：请根据你的接口限制，填写每天推送的量。</div>
                </div>
            </div>
            <div>
                <button type="default" #formClose>返回</button>
                <button type="default" #taskSubmit>提交</button>
            </div>
        </div>
    </form>

        <div class="result-list" #resultList>
            <div class="form-header">
                <a class="form-close" #resultClose>关闭</a>
                <h3>查看结果</h3>
            </div>
            <div class="form-content">
                <table>
                    <colgroup>
                        <col width="40%">
                        <col width="60%">
                    </colgroup>
                    <tbody>
                    <tr>
                        <td>网站网站</td>
                        <td #resultDomain></td>
                    </tr>
                    <tr>
                        <td>每日推送数量</td>
                        <td #resultDailyNum>0条</td>
                    </tr>
                    <tr>
                        <td>执行状态</td>
                        <td #resultStatus>waiting</td>
                    </tr>
                    <tr>
                        <td>已发现URL</td>
                        <td #resultUrlCount>0条</td>
                    </tr>
                    <tr>
                        <td>已推送</td>
                        <td #resultDailyFinished>0条</td>
                    </tr>
                    <tr>
                        <td>推送结果</td>
                        <td class="text-left" #resultResult>
                            /* <div><span>https://www.anqicms.com</span><span>失败</span></div> */
                        </td>
                    </tr>
                    <tr>
                        <td></td>
                        <td>
                            <div>
                                <span class="pate-item">页码：<span #resultPage>1</span>/<span #resultTotalPage>1</span></span>
                                <button #resultPrev>上一页</button>
                                <button #resultNext>下一页</button>
                            </div>
                        </td>
                    </tr>
                    </tbody>
                </table>
            </div>
        </div>
</div>

</body>
</html>

<script type="text/tiscript">
    function syncTasks() {
        let res = view.getIndexingTasks()
        let result = JSON.parse(res)
        // 重置 #taskList
        let tb = $(#taskList>tbody)
        tb.html = ""
        if (!result) {
            return;
        }
        for (let i = 0; i < result.length; i++) {
            let task = result[i];
            let tr = new Element(#tr)
            tr.append(new Element(#td, task.domain))
            tr.append(new Element(#td, task.url_count + ""))
            tr.append(new Element(#td, task.daily_finished + "/" + task.daily_num))
            tr.append(new Element(#td, task.status + ""))
            let td = new Element(#td)
            td.@#class = "control-btns"
            td.attributes["id"] = "task-" + task.id

            addControlBtn(td, "结果", "task-result")
            if (task.status == "running") {
                addControlBtn(td, "停止", "task-stop")
            } else {
                addControlBtn(td, "启动", "task-start")
            }
            if (task.status != "running") {
                addControlBtn(td, "编辑", "task-edit")
                addControlBtn(td, "删除", "task-delete")
            }

            tr.append(td)
            tb.append(tr)
        }
    }
    function addControlBtn(el, str, cls) {
        let bt = new Element(#button, str)
        bt.@#class = cls
        el.append(bt)
    }
    self.on("click",".task-start", function() {
        let id = this.$p(td).attributes['id'].replace("task-", "")
        let result = view.startGoogleIndexing(id)
        //view.msgbox(#alert, result || "启动成功");
    });
    self.on("click",".task-stop", function() {
        let id = this.$p(td).attributes['id'].replace("task-", "")
        let result = view.stopGoogleIndexing(id)
        //view.msgbox(#alert, result || "停止成功");
    });
    self.on("click",".task-edit", function() {
        let id = this.$p(td).attributes['id'].replace("task-", "")
        showEditWindow(id)
    });
    self.on("click",".task-result", function() {
        let id = this.$p(td).attributes['id'].replace("task-", "")
        stdout.println(this.$p(td).attributes['id'])
        showResultWindow(id, 1)
    });
    self.on("click",".task-delete", function() {
        let id = this.$p(td).attributes['id'].replace("task-", "")
        let result = view.deleteGoogleIndexing(id)
        //view.msgbox(#alert, result || "删除成功");
    });
    // 新建任务
    event click $(#newTask){
        showEditWindow("-1")
    }

    function showEditWindow(id) {
        let res = view.getIndexingTask(id);
        let result = JSON.parse(res) || {};
        // 回填表单
        $(#taslForm).value=result;
        $(#taslForm).@.addClass("active");
    }

    // 表单
    let accountPath = '';
    event click $(#selectAccountJson){
        let filePath = view.openAccountJson()
        self#accountJson.text = filePath
        accountPath = filePath;
    }
    event click $(#formClose){
        $(#taslForm).@.removeClass("active");
    }

    event click $(#taskSubmit){
        // 第一步，先保存授权信息
        // 第二步，抓取Sitemap
        // 第三步，开始推送
        let result = view.createGoogleIndexing(accountPath, $(#taslForm).value.domain, $(#taslForm).value.daily_num)
        stdout.println(result)
        view.msgbox(#alert, result || "保存成功");
        if (!result) {
            $(#taslForm).@.removeClass("active");
        }
        // 同步结果
        syncTasks();
    }

    let curId = 0;
    let curPage = 1;
    let totalPage = 1;
    function showResultWindow(id, curp) {
        curId = id;
        let res = view.getIndexingTask(curId);
        let result = JSON.parse(res) || {};

        $(#resultList).@.addClass("active");

        $(#resultDomain).text = result.domain;
        $(#resultDailyNum).text = result.daily_num + "条";
        $(#resultStatus).text = result.status;
        $(#resultUrlCount).text = result.url_count + "条";
        $(#resultDailyFinished).text = "累计：" + result.total_finished + "条" + " / 今日：" + result.daily_finished + "条" + (result.daily_finished >= result.daily_num ? ' / 今日已完成' : '');
        
        let res2 = view.getIndexingUrls(curId, curp)
        let result2 = JSON.parse(res2) || {};

        $(#resultPage).text = result2.page + "";
        $(#resultTotalPage).text = result2.totalPage + "";
        curPage = result2.page
        totalPage = result2.totalPage

        $(#resultResult).html = '';

        for (let val in result2.urls) {
            $(#resultResult).append("<div class='urls-item'><span class='item-url'>" + val.url + "</span>&nbsp;&nbsp;<span class='item-status' title='"+(val.msg || (val.status == 0 ? '未开始' :''))+"'>" + (val.status == 0 ? '-' : val.status != 200 ? "<span class='status-error'>"+val.status+"</span>" : val.status)+"</span></div>")
        }

    }

    event click $(#resultPrev) {
        if(curPage <= 1) {
            curPage = 1;
            return;
        }
        curPage = curPage - 1;
        showResultWindow(curId, curPage);
    }

    event click $(#resultNext) {
        if(curPage >= totalPage) {
            curPage = totalPage;
            return;
        }
        curPage = curPage + 1;
        showResultWindow(curId, curPage);
    }

    event click $(.item-status) {
        let title = this.attributes['title'];
        if (title) {
            view.msgbox(#error, title);
        }
    }

    event click $(#resultClose){
        $(#resultList).@.removeClass("active");
        $(#taslForm).@.removeClass("active");
    }
     // 进来的时候先执行一遍
    syncTasks();
    // 加载tasklist,2秒钟刷新一次
    self.timer(2000ms, function() {
        syncTasks();
        return true;
    });
</script>
```

### 使用帮助页面 views/help.html

使用帮助页面也是简简单单的HTML页面。这里只用到了一处的JS代码，用于调起系统浏览器，打开帮助文档页面。

```html
<html resizeable>
<head>
    <style src="home://views/style.css" />
    <meta charSet="utf-8" />
</head>
<body>
<div class="layout">
    <div class="aside">
        <h1 class="soft-title"><a href="home://views/main.html">谷歌<br/>推送助手</a></h1>
        <div class="aside-menus">
            <a href="home://views/task.html" class="menu-item">推送任务</a>
            <a href="home://views/help.html" class="menu-item active">使用教程</a>
        </div>
    </div>
    <div class="container">
      <div class="help-container">
          <div><a #helpLink>访问使用帮助页面</a></div>
          <div class="help-tips">注意：一定要认真阅读帮助页面，每一个操作步骤都要细心按照教程执行，注意截图中的红字，否则容易出错。</div>
      </div>
    </div>
</div>

</body>
</html>
<script type="text/tiscript">
  event click $(#helpLink){
    view.openUrl("https://www.anqicms.com/google-indexing-help.html")
  }
</script>
```