---
title: API接口限流就是这么简单
date: 2024-11-13 16:20:58
cover: /images/api-limit/cover.png
tags:
  - java
categories:
  - 技术文章
---

## 1\. 简介

访问速率限制是一种API访问限制的策略。它限制客户端在一定时间内调用 API 的次数。这有助于保护应用程序接口，防止无意或恶意的过度使用。

速率限制通常是通过跟踪 IP 地址或更具体的业务方式（如 API 密钥或访问令牌等方式）来应用于 API 的。作为 API 开发人员，当客户端达到限制时，我们有几种选择：

+   请求排队，直到剩余时间结束（这也是最常用的方式）
+   拒绝请求（HTTP 429 请求过多）

本篇文章将介绍一款开源的组件Bucket4j，该组件提供了强大的限流功能。基于基于令牌桶算法。既可用于独立的 JVM 应用程序，也可用于集群环境。它还通过 JCache（JSR107）规范支持内存或分布式缓存。

### 令牌桶算法

假设我们有一个 "桶"，其容量被定义为可容纳的令牌数量。每当消费者想要访问 API 端点时，就必须从桶中获取一个令牌。如果有令牌，我们就会从数据桶中移除令牌，并接受请求。反之，如果程序桶中没有令牌，我们就会拒绝请求。

在请求消耗令牌(token)的同时，我们也在以某种固定的速度补充令牌。

考虑一个速率限制为每分钟 100 个请求的应用程序接口。我们可以创建一个容量为 100 的水桶，每分钟填充 100 个令牌。如果我们在一分钟内收到 70 个请求，少于可用令牌的数量，那么在下一分钟开始时，我们只需再添加 30 个令牌，就能使水桶达到容量。另一方面，如果我们在 40 秒内用完了所有令牌，我们将等待 20 秒来重新装满令牌桶。

接下来将详细介绍在Spring Boot中如何使用Bucket4j实现限流。

## 2\. 实战案例

### 2.1 环境准备

#### 引入依赖

```xml
<dependency>
  <groupId>com.giffing.bucket4j.spring.boot.starter</groupId>
  <artifactId>bucket4j-spring-boot-starter</artifactId>
  <version>0.12.7</version>
</dependency>
<dependency>
  <groupId>com.bucket4j</groupId>
  <artifactId>bucket4j-redis</artifactId>
  <version>8.10.1</version>
</dependency>
<dependency>
  <groupId>redis.clients</groupId>
  <artifactId>jedis</artifactId>
</dependency>
<dependency>
  <groupId>io.micrometer</groupId>
  <artifactId>micrometer-core</artifactId>
</dependency>
```

接下来的案例是基于redis的，所以引入了jedis。你也可以是lettuce或者是redisson但是这2个貌似需要是webflux环境。

#### jedis配置

```less
@Bean
public JedisPool jedisPool(
    @Value("${spring.data.redis.port}") Integer port,
    @Value("${spring.data.redis.host}") String host,
    @Value("${spring.data.redis.password}") String password,
    @Value("${spring.data.redis.database}") Integer database
  ) {
  // buildPoolConfig方法自己进行配置吧
  final JedisPoolConfig poolConfig = buildPoolConfig();
  return new JedisPool(poolConfig, host, port, 60000, password, database);
}
```

以上基础环境就准备好了，接下来就可以进行规则配置。而规则的配置可以基于2中方式，基于配置文件和基于注解（AOP）。

#### 定义接口

```less
@RestController
@RequestMapping("/products")
public class ProductController {


  @GetMapping("/{id}")
  public Product getProduct(@PathVariable Integer id) {
    return new Product(id, "商品 - " + id, BigDecimal.valueOf(new Random().nextDouble(1000))) ;
  }
}
```

接下来我将基于上面的接口进行限流的配置。

### 2.2 基于配置文件

基于配置文件的规则配置底层实现是通过Filter。

```yaml
bucket4j:
  cache-to-use: redis-jedis
  filter-config-caching-enabled: true
  filters:
  - cache-name: product_cache_name
    id: product_filter
    # 配置请求url的规则；这里底层是通过正则表达式进行匹配的
    url: /products/.*
    rate-limits:
    - 
      #这里的cache-key非常关键；用于区分不同请求的情况；
      #比如，这里我会根据不同的请求id来现在访问速率
      #这里可以写spel表达式，这里调用的是HttpServletRequest#getParameter方法
      cache-key: getParameter("id")
      bandwidths:
      #配置桶的容量
      - capacity: 2
        # 时间
        time: 30
        # 单位
        unit: seconds
        # 填充速度；这会每隔30秒进行填充
        refill-speed: interval
```

#### 修改默认的限流提示

```rust
bucket4j:
  filters:
  - cache-name: product_cache_name
    http-content-type: 'application/json;charset=utf-8'
    http-response-body: '{"code": -1, "message": "请求太快了"}'
```

注意：你必须同时要设置content-type设置字符编码，否则会乱码。

#### 条件放行

你也可以通过如下属性进行有条件的放行；

```yaml
bucket4j:
  filters:
  - cache-name: product_cache_name
    rate-limits:
    - 
      skip-condition: 'getParameter("id").equals("6")'
```

当请求id的值为6时则跳过规则，直接方向。

以上是基于配置文件规则的应用，它还有很多其它的配置属性，详细查看官方文档

[github.com/MarcGiffing…](https://github.com/MarcGiffing/bucket4j-spring-boot-starter "https://github.com/MarcGiffing/bucket4j-spring-boot-starter")

接下来介绍基于注解的方式。

### 2.3 基于注解

通过"@RateLimiting"注解，AOP 可以拦截目标方法。这样，你就可以全面访问方法参数，轻松定义速率限制键或有条件地跳过速率限制。

#### 配置文件中配置规则

```yaml
bucket4j:
  methods:
  - name: storage_rate #在代码中会通过该名称引用
    cache-name: storage_cache_name
    rate-limit:
      bandwidths:
      - capacity: 2
        time: 30
        unit: seconds
        refill-speed: interval
```

#### 接口注解，配置限流

```less
@RateLimiting(
    name = "storage_rate", 
    cacheKey = "'storage-' + #id",
    skipCondition = "#name eq 'admin'",
    ratePerMethod = true,
    fallbackMethodName = "getStorageFallback"
  )
@GetMapping("/{id}")
public R<Storage> getStorage(@PathVariable Integer id, String name) {
  return R.success(new Storage(id, "SP001 - " + id, new Random().nextInt(10000))) ;
}
// 回退方法的签名必须与业务方法一致
public R<Storage> getStorageFallback(Integer id, String name) {
  return R.failure(String.format("请求id=%d,name=%s被限流", id, name)) ;
}
```

skipCondition：该属性定义了如果请求的name的值为admin则跳过，不限流。

@RateLimiting注解还可以应用到类中，这样该类中的所有方法都会被限流，如下示例：

```less
@Service
@RateLimiting(
    name = "storage_rate", 
    cacheKey = "getName",
    ratePerMethod = false
  )
public class StorageService {


  public Storage queryStorageById(Integer id) {
    return new Storage(id, "SP001 - " + id, new Random().nextInt(10000)) ;
  }
  
  @IgnoreRateLimiting
  public List<Storage> queryStorages() {
    return List.of(
        new Storage(1, "SP001 - " + 1, new Random().nextInt(10000)),
        new Storage(2, "SP002 - " + 2, new Random().nextInt(10000)),
        new Storage(3, "SP003 - " + 3, new Random().nextInt(10000))
      ) ;
  }
}
```

上面代码queryStorageById会被限流，而queryStorages方法被@IgnoreRateLimiting注解标准，所以不会被限流。