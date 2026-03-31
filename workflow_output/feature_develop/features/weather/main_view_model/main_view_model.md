# main_view_model

## 实现概要

- 新增 `services/MainViewModel.cj`：`ohos_app_cangjie_entry.services.MainViewModel`，对齐 Android `MainViewModel` 的职责，无 `LiveData`/RxJava；状态用 `models.Resource`（源码中以 `UiResource` 别名避免与 `std.core.Resource` 冲突）表示 `Success`/`Error`/`Loading`，并通过 `onDaysForecastChanged`、`onPlaceNameChanged` 通知 UI。
- `initData()`：从 Preferences 解析温/风速/气压单位并写入 `WeatherForecastRepository`；从 `ProtoDataStoreRepository` 恢复坐标；若有持久化预报 JSON 则经 `WeatherForecastRepository.parseForecastJson` 解析后 `Success`；随后 `requestLocationAsync` 触发 `fetchWeatherAndPlace`。
- `fetchWeatherAndPlace` / `fetchCurrentWeatherAndPlace`：在联网时通过 `GeoSingle.get()` 拉取预报与逆地理地名；断网返回英文错误文案（与工程内其他服务一致）。
- `changeTemperatureUnit` / `changeSpeedUnit` / `changePressureUnit`：在已有 `Success` 预报上就地换算（`convertTemperature`/`convertSpeed`/`convertPressure`），对齐 Android `updateUnit` 行为。
- `searchLocation`：回调式 `UiResource<Array<PlaceInfo>>`；`PlaceInfo` 字段在包外不可见，地名从 `toString()` 解析（与 `MainFragment` 一致）。

## 依赖补全

- `WeatherClient` / `OpenMeteoWeatherClient` 增加 `parseForecastJson`，供缓存 JSON 与网络响应同源解析。
- `WeatherForecastRepository` 增加 `parseForecastJson` 转发。

## 已知限制

- `getSavedSettings` / `getSavedLocationCoord` 等为回调式 API，非 Android `LiveData`。
- 无 Rx 订阅清理逻辑，`dispose()` 仅占位。
