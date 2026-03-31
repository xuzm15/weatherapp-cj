# geo_location_client

## 实现概要

- **文件**: `services/GeoLocationClientService.cj`
- **契约**:
  - `GeoLocationClient`：`fetchNearestPlaceInfo` / `searchLocation` / `getLocale` / `setLocale`
  - `GeoSingle<T>`：对应 Java `Single<T>`，通过 `get()` 阻塞直至网络返回（内部 `HttpRequest` 回调 + `Mutex`/`Condition` 同步）
  - `GeoLocale`：BCP-47 语言标签（替代 `java.util.Locale`）

## 平台 API 说明

- 当前 Cangjie SDK 中 `GeoLocationManager`（`ohos.geo_location_manager`）仅暴露 `getCurrentLocation` / `isLocationEnabled`，**未提供** `getAddressesFromLocation` 等反向地理编码绑定。
- 实现采用 **HTTPS 访问 OpenStreetMap Nominatim**（`reverse` / `search`），需 `ohos.permission.INTERNET`，请求头包含 `User-Agent` 与 `Accept-Language`（随 `GeoLocale`）。

## 数据映射

- Nominatim JSON 中的 `display_name`、`country`、`country_code`、`state`/`region`、`lat`/`lon` 映射到已有 `PlaceInfo` 七个字段。

## 已知限制

- 依赖公网 Nominatim；离线、限流或策略变更时结果可能为空（此时记录 Hilog 并返回空字段或空列表）。
- 地点搜索 JSON 按 `,{"place_id":` 切分结果对象，与 Nominatim 响应格式强相关。

## cangjie-kb

- 本会话未接入 cangjie-kb MCP；已对照本机 SDK 声明文件与仓库内 `LocationKit` 文档。
