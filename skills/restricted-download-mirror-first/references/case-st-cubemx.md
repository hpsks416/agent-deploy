# 案例：ST STM32CubeMX（2026-11，实测）

## 结论速查

| 版本 | 匿名可下 | 说明 |
|---|---|---|
| ≤ 6.17.0 | ✅ | CloudFront `publish` 路径公开可下，HEAD 返回 200 |
| ≥ 6.18.0 / 6.18.1 | ❌ 403 | 改为登录后签名 URL；匿名访问旧规律路径一律 403 |

## 官方直链规律（≤6.17.0 可用）

```
http://www.st.com/cloudfront/publish/stm32cubemx-win-v6-<X-Y-Z>/<X.Y.Z>/en/stm32cubemx-win-v6-<X-Y-Z>.zip
```

- 6.17.0 实测：`Content-Length: 692761085`，`ETag: 6f8d96218a3748dd99cf6ff0ffff4dc6`（= 整文件 MD5）
- https 与 http 两个入口都存在；本机实测 https 常被重置，http 可返回 206 分片

## 失败证据（用于识别同类站点）

- 单线程下载：~0.5–1 MB 处 `curl: (56) Recv failure: Connection was reset`
- 32 路并发：直接触发 WAF，之后所有请求返回 **7351 字节**中文拦截页（`<title></title>`，`请求已被拦截`）
- 被封期间：带完整浏览器头 + Cookie 也返回 `567 / 7351`；显式 Range 分片、`-C -` 续传均无法推进
- 无头 Chrome 渲染页面：返回"请求已被拦截"（说明校验含 headless 特征）

## 镜像路线（国内命中）

- 主源：CSDN《2026 最新 STM32CubeMX 历史版本合集》（含 6.9.0→6.18.1，每版 5 个网盘 + 提取码）
  `https://blog.csdn.net/VeryDelicious/article/details/144962196`
  - 抓取法：curl 全文存本地 → 按 `【CubeMX 6.18.1】` 切片 → 取锚点文本 `文件名 提取码：xxxx` 与 `href`
  - 6.18.1 实测网盘：夸克/百度/城通/UC/迅雷；文件名统一为 `en.stm32cubemx-win-v6-18-1.zip`
  - 注意：该帖压缩包**有解压密码**，密码放在原文文末（正文 API 抓取拿不到明文）
- 死路（本机实测不可用）：FileHorse（fetch 失败）、Softpedia（Cloudflare Just a moment）、archive.org（fetch 失败）

## 最终结果

用户用百度网盘源自行下载成功：`https://pan.baidu.com/s/1OocxfVVsdSKSEjVDFZwsDQ?pwd=jvtb`（提取码 `jvtb`）。

## 教训（已升格为 R1/R2/R3）

1. 官网"点了没反应"多数不是浏览器问题，而是**登录墙 + 签名 URL + 反爬**三件套叠加。
2. 重试与并发只会加深封禁：**3 次拿不下就该换镜像**，而不是加并发或换 UA。
3. 不要用登录态账号跑脚本拉官方直链——封号成本远高于安装包。
