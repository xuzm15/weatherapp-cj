# geo_names_client

## 实现概要

- **类型**: `implementation_kind: network`
- **仓颉文件**（相对 `<target_cangjie_root>`）: `services/GeoNamesClientService.cj`
- **类**: `GeoNamesClient` 实现 `GeoLocationClient`（定义见 `services/GeoLocationClientService.cj`），与 Java `GeoNamesClient` 对齐。

## HTTP 与 API

- **Base URL**: `http://api.geonames.org`
- **用户名**: `my_weather_app`（与 Android 源码一致）
- **fetchNearestPlaceInfo**: `GET /findNearbyPlaceNameJSON`，参数 `lat`、`lng`、`style=FULL`、`cities=cities1000`、`lang`、`username`；解析响应 `geonames[0]` 为 `PlaceInfo`。
- **searchLocation**: `GET /searchJSON`，参数 `q`、`style=LONG`、`maxRows=15`、`fuzzy=0.8`、`lang`、`username`；解析 `geonames[]` 为 `Array<PlaceInfo>`。
- **HTTP 栈**: `kit.NetworkKit`（`createHttp`、`HttpRequestOptions`、`HttpDataType.StringValue`），同步封装沿用 `GeoLocationClient` 的 `HttpSyncBox` + `Mutex`/`condition` 模式（见 `syntax_error.md` 异步捕获说明）。
- **Locale**: `getLocale` / `setLocale` 使用 `GeoLocale`；请求中的 `lang` 取自 `languageTag` 的主语言段（如 `zh-CN` → `zh`）。

## 解析逻辑

- 无外部 JSON 库：对响应体做轻量字符串解析（`extractQuoted`、`alternateNames` 中首个 `"lang"`、`extractBalancedJsonObject` 匹配花括号）。
- `PlaceInfo` 字段映射：`name` → `toponymName`，以及 `countryName`、`countryCode`、`adminName1`、`lat`、`lng`；语言优先从 `alternateNames[0].lang` 取，否则 `en`。

## 已知限制

- 依赖 GeoNames 公网与账号配额；错误 HTTP 时当前返回空 `PlaceInfo` 或空列表并打日志，与阻塞式 `GeoSingle.get()` 契约一致。
- **MCP**: 本会话无 cangjie-kb 工具，实现依据 `syntax_error.md`、`GeoLocationClientService.cj` 与 Android `GeoNamesClient.java`。
