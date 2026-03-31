# weather_client

## 实现要点

- **契约文件**：`services/WeatherClient.cj`（`package ohos_app_cangjie_entry.services`）。
- **对齐 Android**：`fetchWeatherForecast`、`get/set` 温度/风速/气压单位与 `WeatherClient.java` 一致。
- **RxJava 替代**：`fetchWeatherForecast` 返回 `GeoSingle<String>`（与同目录 `GeoLocationClient` 一致），`get()` 时执行获取；载荷为多日预报 **JSON 字符串**，对应 Android `DaysForecastProto` 在本工程中的序列化/持久化形态（参见 `ProtoDataStoreRepository.getForecast` / `saveForecast` 注释）。
- **单位类型**：`TemperatureUnit`、`SpeedUnit`、`PressureUnit` 使用 `models/UnitConverter.cj` 中枚举，与 Android Proto 枚举语义对齐。

## 已知限制

- 本轮仅交付 **interface**；具体网络请求与解析应在实现类（例如未来的 `WeatherClientService.cj`）中完成，并 `WeatherClient` 接口。

## 编译

- `IOS2CJ_WORKFLOW_CONFIG=<workflow.config> bash <core>/src/scripts/build.sh cangjie` — 通过（2026-03-31）。
