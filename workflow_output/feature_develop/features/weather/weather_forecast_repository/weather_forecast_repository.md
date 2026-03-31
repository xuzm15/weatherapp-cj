# weather_forecast_repository

## 实现概要

- **文件**: `services/WeatherForecastRepository.cj`
- **角色**: Repository 门面，组合注入的 `LocationProvider`、`WeatherClient`、`GeoLocationClient`，并委托 `ProtoDataStoreRepository.INSTANCE` 做持久化；无独立业务分支逻辑。
- **代理映射**:
  - 天气与单位：`fetchWeatherForecast`、`getTemperatureUnit` / `getSpeedUnit` / `getPressureUnit`、`setTemperatureUnit` / `setSpeedUnit` / `setPressureUnit` → `WeatherClient`
  - 地理：`fetchNearestPlaceInfo`、`searchLocation`、`setLocale` → `GeoLocationClient`
  - DataStore：`getSettings`、`saveDataStore`（→ `saveDataStoreProto`）、`saveForecast`、`getDaysForecastResponse`（→ `getForecast`）、`saveLocationCoord` → `ProtoDataStoreRepository`
  - 定位：`getLocation`、`setLocation`、`requestLocation`、`requestLocationAsync` → `LocationProvider`

## 与 Android 差异

- `getSettings` / 预报与快照在鸿蒙侧为 **JSON 字符串**（`ProtoDataStoreRepository` 约定），非 Protobuf 对象。
- `requestLocation` 同步返回 `LocationCoord`；另提供 `requestLocationAsync` 以匹配 `LocationProvider` 鸿蒙接口。

## 已知限制

- 不缓存子服务引用以外的状态；调用方需自行注入合适的 `LocationProvider` 实现（如融合定位服务）。

## cangjie-kb

- 已调用 `search_cangjie_knowledge_base`（类与构造函数模式摘要）；本类为纯组合代理，无 ArkUI 宏。
