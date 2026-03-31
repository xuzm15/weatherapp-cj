# weather_client

## 实现概要

- **`services/WeatherClient.cj`**：定义 `WeatherClient` 接口；`OpenMeteoWeatherClient` 使用 `kit.NetworkKit` 的 `createHttp()` + `HttpRequestOptions` + `request()` 发起 **HTTP GET**，通过 `Mutex` + `condition` 将异步回调转为阻塞式 `get()`（与 `GeoLocationClientService` / `GeoNamesClientService` 一致）。
- **请求 URL**：`https://api.open-meteo.com/v1/forecast`，参数包含 `latitude` / `longitude`、`current`、`daily`、`hourly`、`forecast_days=7`、`timezone=auto`，以及根据当前设置附加的 `temperature_unit`、`wind_speed_unit`。
- **JSON 解析**：从 `current` / `daily` / `hourly` 对象中提取数值与数组，构建 `DaysForecastProto`；气压由 API 的 hPa 经 `convertPressure` 转换为用户 `PressureUnit`；天气图标与资源名通过 `WeatherCode.getIconIdByCode` / `getResIdByCode`。
- **`models/WeatherForecastProto.cj`**：对齐 Android 侧 `DaysForecastProto` / `DayForecastProto` / `TemperatureProto` 等核心字段，供 UI 与持久化消费。

## 已知限制

- 当前 Open-Meteo 请求未包含降水概率、UV 等扩展字段；对应 `DayForecastProto` 中降水与 `uvIndex` 以占位值填充。
- 日出/日落未从 API 拉取时显示为占位符「—」。

## 编译

在 output worktree 根目录执行：

`IOS2CJ_WORKFLOW_CONFIG=<workflow.config> bash <core.src_root>/scripts/build.sh cangjie`

本轮构建结果：**通过**。
