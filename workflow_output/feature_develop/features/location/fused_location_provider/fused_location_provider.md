# fused_location_provider

## 实现要点

- **目标文件**：`services/FusedLocationProviderService.cj`（`FusedLocationProviderService <: LocationProviderService`）
- **默认坐标**：`DEFAULT_LAT` / `DEFAULT_LON` = 40.72 / -74.00（与 Android `DEFAULT_COORD` 一致）
- **权限**（对齐 Android FINE/COARSE）：
  - `ohos.permission.APPROXIMATELY_LOCATION`：未授予时直接返回默认坐标并写入缓存
  - `ohos.permission.LOCATION`：通过 `AbilityAccessCtrl.checkAccessToken` 判断；已授予则单次定位优先 `LocatingPriority.PriorityAccuracy`，否则 `PriorityLocatingSpeed`
- **定位开关**：`GeoLocationManager.isLocationEnabled()` 为 false 时走「最后已知」回退（缓存非零则用之，否则默认坐标）
- **当前位置**：优先用主策略 `getCurrentLocation(SingleLocationRequest)`，失败后再切换另一 `LocatingPriority`（GPS/网络组合由系统侧策略体现）
- **回退**：两次 `getCurrentLocation` 均失败后使用 `getLastKnownOrDefault()`（缓存 → 默认）
- **异步**：`requestLocationAsync` 在基类接口中声明；融合类覆写为在同步 `requestLocation()` 完成后调用回调（与 Java `Single` 异步交付语义一致）

## 接口变更

- `LocationProvider` / `LocationProviderService` 增加 `requestLocationAsync(onComplete: (LocationCoord) -> Unit)`；基类为 `open`，供融合实现覆写。

## 已知限制

- 鸿蒙侧未在工程中调用 `GeoLocationManager.getLastLocation()`（参考文档片段中链式指引存在，但本仓库参考文档未给出可编译签名）；「最后已知」以应用内缓存与默认坐标为准，与 Android `FusedLocationProviderClient.getLastLocation()` 在设备缓存层不完全等价。

## cangjie-kb MCP

- 本会话环境未挂载 cangjie-kb MCP；API 依据为仓库内 `reference/docs_cangjie/.../cj-apis-geo_location_manager.md` 与 `cj-request-user-authorization.md`（`checkAccessToken`）。
