# location_provider 实现记录

## 概述

将 Java `LocationProvider` 接口及其位置服务逻辑迁移到 HarmonyOS 仓颉实现。

- **implementation_kind**: network（系统定位服务 API）
- **源码**: `LocationProvider.java` — 定义 `requestLocation()`, `getLocation()`, `setLocation()` 三个方法

## 实现文件

| 文件 | 说明 |
|------|------|
| `models/LocationCoord.cj` | 坐标数据模型，对应 Java `LocationCoordProto`，包含 `latitude`/`longitude` (Float64) |
| `services/LocationProviderService.cj` | `LocationProvider` 接口定义 + `LocationProviderService` 实现类 |

## 关键 API 调用

- `GeoLocationManager.isLocationEnabled()` — 检查定位开关是否开启
- `GeoLocationManager.getCurrentLocation(SingleLocationRequest)` — 通过系统 LocationKit 获取当前位置
- `SingleLocationRequest(LocatingPriority.PriorityLocatingSpeed, 10000)` — 快速定位策略，10 秒超时
- 异常处理使用 `BusinessException`（catch 后返回缓存坐标）

## 调用链

```
上层调用 → LocationProvider.requestLocation()
         → GeoLocationManager.isLocationEnabled()
         → GeoLocationManager.getCurrentLocation(SingleLocationRequest)
         → Location → LocationCoord 转换
         → 缓存更新 + 返回
```

## 包结构

由于仓颉 cjpm 要求子目录 package 名称与目录路径一致：
- `models/` → `package ohos_app_cangjie_entry.models`
- `services/` → `package ohos_app_cangjie_entry.services`（import models.*）

## 编译陷阱

1. 子目录的 package 声明必须包含完整路径前缀（如 `ohos_app_cangjie_entry.models`）
2. 同时定义无参 `init()` 和带默认值命名参数 `init(latitude!: Float64 = 0.0, ...)` 会导致构造函数歧义，只保留带默认值的即可

## 已知限制

- 位置权限 (`ohos.permission.APPROXIMATELY_LOCATION`) 需要在 `module.json5` 中声明，属于 app group 的配置范畴
- `requestLocation()` 为同步调用（HarmonyOS GeoLocationManager.getCurrentLocation 是同步 API），与 Java 的 RxJava `Single<>` 异步模式不同

## cangjie-kb MCP 查询记录

- **MCP 不可用**：当前会话无 cangjie-kb 工具
- 替代方案：使用 `<core.src_root>/reference/docs_cangjie/zh-cn/application-dev/reference/LocationKit/cj-apis-geo_location_manager.md` 和 `cj-location-guidelines.md`
- syntax_error.md：文件不存在（首个 feature）
