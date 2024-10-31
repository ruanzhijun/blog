---
title: Go语言中的context包到底解决了啥问题？
date: 2024-10-31 13:29:50
tags:
---

Go语言，自2009年发布以来，凭借其简洁、高效、并发能力强等特点，迅速在开发者社区获得了广泛的关注和应用，特别是在服务器端开发、云计算、容器技术和微服务架构等领域。例如，Docker 和 K8S 等知名的容器技术都是使用Go语言开发的。

# 为什么需要context包？

## 认识 goroutine

首先让我们来认识下 goroutine。

Go语言的高并发、高性能都来源于它的并发模型：goroutine，就是它，让开发者可以轻松地编写高吞吐量的应用程序，这在处理大量并发请求的服务器端开发中尤为重要。

goroutine是Go语言中的轻量级线程，或者称为协程。与操作系统级别的线程相比，goroutine的创建和销毁开销非常小，调度效率也很高，因此在Go语言中，可以轻松地创建成千上万个goroutine来处理并发任务。

使用goroutine非常简单，只需在函数调用前加上go关键字即可。例如：

```go
go func() {
    // 并发执行的代码
}()
```

## 并发编程的挑战

goroutine 虽然让并发编程变得非常方便，但也带来了新的挑战。

+   **超时控制**：许多操作（如网络请求、数据库查询等）都可能因为各种原因变得缓慢甚至无限期挂起。如果没有合适的超时控制机制，这些操作可能会导致计算机资源被长时间占用，影响系统的整体性能和响应速度。
+   **取消操作**：某些情况下，某些操作可能需要被取消。例如，当用户取消了一个正在进行的请求，或者当某个前置条件不再满足时，我们需要能够及时地取消正在进行的操作，以避免不必要的资源消耗。
+   **数据传递**：不同的goroutine之间可能需要共享和传递一些上下文信息。例如，在一个请求的处理过程中，我们可能需要在多个函数调用之间传递用户身份、请求ID等。这些信息需要能够安全地在多个goroutine之间传递和共享。

这些挑战在其它语言的并发编程模型中也是广泛存在的。

## 为什么需要context包

为了解决并发编程中的常见挑战，Go语言引入了context包。context包提供了一种统一的机制来管理请求的生命周期，传递取消信号，设置超时时间，并在不同的goroutine之间传递上下文信息。

+   **统一管理请求生命周期**：context包允许我们为每一个请求创建一个上下文对象（上下文通常就翻译为context），并在请求的整个生命周期中传递这个上下文对象。如此，我们就可以在请求结束时，及时释放所有相关的资源。
+   **传递取消信号**：context包提供了取消信号的传递机制。我们可以创建一个可以取消的上下文对象，并在需要取消操作时调用取消函数，通知所有相关的goroutine取消操作。当然这不是自动发生的，还需要我们编写代码进行判断。
+   **设置超时时间**：context包还提供了超时控制的机制。我们可以为操作设置超时时间，并在操作超时后自动取消操作。
+   **传递和共享数据**：context包还提供了一种安全的方式在不同的goroutine之间传递和共享上下文信息。我们可以将一些关键数据存储在上下文对象中，并在不同的函数调用中传递这个上下文对象，从而实现数据的安全共享。

# context包的使用方法

## HTTP请求处理中context应用

让我们先通过一个例子来感受下 context 包的强大能力。

在Go的net/http包中，每个HTTP请求都会自动携带一个context。我们可以通过req.Context()方法获取这个context，并在处理请求时使用它。以下是一个简单的示例。

```go
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

// 定义一个key类型，用于在context中存储和检索数据
type key string

const (
	userIDKey key = "userID"
)

// 定义一个向控制台输出日志的logger
var logger = log.New(os.Stdout, "INFO: ", log.Ldate|log.Ltime|log.Lshortfile)

func main() {
	http.HandleFunc("/hello", helloHandler)
	http.ListenAndServe(":8080", nil)
}

func helloHandler(w http.ResponseWriter, req *http.Request) {
	// 设置请求的超时为5秒
	ctx, cancel := context.WithTimeout(req.Context(), 5*time.Second)
	defer cancel()

	// 在context中存储一些共享数据，例如用户ID
	ctx = context.WithValue(ctx, userIDKey, "12345")

	// 模拟一些工作，将在goroutine中运行，通过channel通知完成
	done := make(chan struct{})
	go func() {
    // 从context取出用户ID，记录到日志中
		userID := ctx.Value(userIDKey).(string)
		logger.Println("开始处理：", userID)
		time.Sleep(3 * time.Second) // 模拟耗时操作
		close(done)
	}()

  // 通过select跟踪context超时或者工作完成
	select {
	case <-ctx.Done():
		// 请求被取消或超时
		http.Error(w, "Request canceled or timed out", http.StatusRequestTimeout)
	case <-done:
		// 操作完成，从context中取出用户ID，返回给调用方
		userID := ctx.Value(userIDKey).(string)
		fmt.Fprintf(w, "Hello, User ID: %s!\n", userID)
	}
}
```

在这个示例中，我们在HTTP处理器中使用 context.WithTimeout 设置了一个5秒的超时。如果请求在5秒内没有完成，context将自动取消，处理器会返回一个超时错误响应。如果操作在5秒内完成，则返回正常的响应。

在这个例子中，我们还使用了 context 来共享数据，在创建超时context之后，我们使用 context.WithValue 在context 中存储了用户ID。

```ini
ctx = context.WithValue(ctx, userIDKey, "12345")
```

在处理具体的工作时，我们使用 ctx.Value 从context中检索共享数据，打印正在处理的用户：

```css
userID := ctx.Value(userIDKey).(string)
logger.Println("开始处理：", userID)
```

在完成后，我们还是使用ctx.Value从context中检索共享数据，并将其包含在响应中：

```css
userID := ctx.Value(userIDKey).(string)
fmt.Fprintf(w, "Hello, User ID: %s!\n", userID)
```

## 基本的context用法

### 创建 context

在Go语言中，创建一个context对象是使用context包的第一步。

在上边的例子中，我们从http请求中获取了一个context，其实我们也完全可以自己创建一个新的context，有两种基本方法：

+   **context.Background()**

context.Background()返回一个空的context对象，通常用于整个应用程序的顶级context，或者在不确定应该使用哪个context的情况下使用。它是一个常见的根context，所有的派生context都会基于它。

+   **context.TODO()**

context.TODO()与context.Background()类似，但通常用于你还不确定要使用哪个context，或者代码还在开发过程中，未来可能会被替换为更具体的context。

### 传递context

我们可以在内嵌函数中直接使用有效范围之内的 contex t实例，不过更常见的传递方法是通过函数参数。

在Go语言中，context对象通常作为函数的第一个参数进行传递。这种方式确保了context在整个调用链中被正确传递和使用。代码如下：

```go
func doSomething(ctx context.Context) {
    // 在函数内部使用context
}

func main() {
    ctx := context.Background()
    doSomething(ctx)
}
```

### 取消context

context.WithCancel() 函数返回一个派生的context和一个取消函数。调用取消函数会取消这个派生的context，并通知所有使用这个context的goroutine进行清理操作。示例代码如下：

```scss
ctx, cancel := context.WithCancel(context.Background())

go func() {
    // 模拟一些工作
    time.Sleep(2 * time.Second)
    // 取消context
    cancel()
}()

select {
case <-ctx.Done():
    fmt.Println("操作被取消")
}
```

### 设置超时

上边http服务端处理的例子中我们已经提供了一种设置context超时的方法，另外还有一个设置context超时的方法：context.WithDeadline()，这个函数函数类似于context.WithTimeout()，但它允许你指定一个具体的时间点作为截止时间。代码示例如下：

```css
deadline := time.Now().Add(3 * time.Second)
ctx, cancel := context.WithDeadline(context.Background(), deadline)
defer cancel()  // 确保在不再需要时取消context

select {
case <-ctx.Done():
    fmt.Println("操作在截止时间前未完成")
}
```

# context的最佳实践

## 合理设置超时时间

超时时间设置的过长，请求都等着，可能会消耗过多的计算资源；设置的太小，频繁超时，又会给用户带来不好的使用体验。以下是一些最佳实践：

1.  **根据业务需求设置超时**：不同的业务场景对响应时间的要求不同。根据具体业务需求来设置超时时间，例如用户请求的超时可以设置得较短，而后台批量处理任务的超时可以设置得较长。
2.  **逐层缩短超时**：在多层级服务调用中，通常应该逐层缩短超时时间。比如，顶层请求的超时时间为10秒，调用的子服务可以设置为8秒，再调用的子服务可以设置为6秒，以确保在超时前有足够的时间处理和传递错误。
3.  **考虑网络延迟和重试机制**：在分布式系统中，网络延迟和重试机制会影响实际的处理时间。设置超时时应考虑这些因素，避免超时时间过短导致频繁的重试。

## 避免context的滥用

context包的主要目的是在请求的生命周期中传递取消信号、超时和共享数据，不要传递过多的业务数据，以下是一些建议：

1.  **不将context用于传递业务数据**：context应该只用于传递请求的控制信息（如取消信号、超时和trace信息），不应该用于传递业务数据。
2.  **不将context存储在结构体中**：context是临时性的，不应该存储在结构体中以避免内存泄漏和不必要的复杂性。
3.  **及时取消context**：使用context.WithCancel、context.WithTimeout或context.WithDeadline创建的context应该及时调用取消函数，以释放资源。
4.  **避免频繁创建context**：创建和取消context本身的开销相对较小，但频繁的创建和取消操作仍然会对性能产生一定影响，特别是在高并发场景下。在设计系统时，尽量减少不必要的context创建操作，可以复用已有的context，避免在每个函数调用中都创建新的context。

有的同学可能会有疑问：context.WithTimeout 或 context.WithDeadline 创建的context等着超时或者正常处理完成不就可以了吗？

其实 context.WithTimeout 和 context.WithDeadline，这两个函数内部也是通过 WithCancel 实现的，因此也会返回一个 cancel 函数。尽管当超时或截止日期到达时，context会自动“过期”，不过调用 cancel 函数仍然是一个好习惯，因为它可以立即停止任何依赖于此上下文的正在进行的操作，而不仅仅等待它们自然发现上下文已过期。

## 与其他包的结合使用

我们不仅可以在自己编写的代码中使用context，很多标准库也提供了context的支持，这样可以更好的管理请求和资源。上边的示例中已经演示了与net/http包结合，我们再看下database/sql的例子：

```go
package main

import (
    "context"
    "database/sql"
    "log"
    "time"

    _ "github.com/go-sql-driver/mysql"
)

func main() {
    db, err := sql.Open("mysql", "user:password@tcp(localhost:3306)/dbname")
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()

    // 创建一个带超时的 context
    ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
    defer cancel()

    // 查询数据库时，传入这个context
    rows, err := db.QueryContext(ctx, "SELECT * FROM users")
    if err != nil {
        log.Println("Query error:", err)
        return
    }
    defer rows.Close()

    for rows.Next() {
        var id int
        var name string
        if err := rows.Scan(&id, &name); err != nil {
            log.Println("Scan error:", err)
            return
        }
        log.Printf("User: %d, Name: %s\n", id, name)
    }

    if err := rows.Err(); err != nil {
        log.Println("Rows error:", err)
    }
}
```

通过结合使用context包和其他标准库，我们就可以更好地管理每个请求的生命周期和使用的各种资源，提高整个系统的稳定性和可维护性。

* * *
