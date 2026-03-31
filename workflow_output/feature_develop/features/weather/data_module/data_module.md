# Data Module（`data_module`）

## 实现说明

- **目标**：替代 Android `DataModule`（Dagger `@Module` / `@Singleton`），在鸿蒙侧用手动 **Service Locator** + **进程内单例** 表达相同依赖图。
- **源码**：`<target_cangjie_root>/services/DataModule.cj`（`package ohos_app_cangjie_entry.services`）。

## 依赖映射

| Android `@Provides` | 仓颉实现 |
|---------------------|----------|
| `WeatherClient` | `OpenMeteoWeatherClient`（惰性） |
| `GeoLocationClient` | `GeoNamesClient`（惰性） |
| `LocationProvider` | `FusedLocationProviderService`（惰性） |
| `NetworkChecker` | `ConnectionNetworkProvider`（惰性） |
| `WeatherForecastRepository` | `WeatherForecastRepository(lp, wc, gc)`（惰性；在持锁路径内通过 `*Locked()` 组装，避免嵌套加锁死锁） |

## 用法

在需要与 Hilt 注入等价实例处调用 `DataModule.provideRepository()`、`provideWeatherClient()` 等；首次调用时创建并缓存，后续调用返回同一实例。

## 已知限制

- 未接入路由/DI 框架；若页面仍自行 `new` 服务，会存在第二套实例——后续可逐步改为统一从 `DataModule` 获取。
