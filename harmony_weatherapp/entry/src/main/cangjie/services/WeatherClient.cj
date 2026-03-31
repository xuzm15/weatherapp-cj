package ohos_app_cangjie_entry.services

import ohos_app_cangjie_entry.models.PressureUnit
import ohos_app_cangjie_entry.models.SpeedUnit
import ohos_app_cangjie_entry.models.TemperatureUnit

/**
 * 天气数据获取契约（对齐 Android `WeatherClient`）。
 *
 * `fetchWeatherForecast` 返回与 `GeoLocationClient.fetchNearestPlaceInfo` 相同的惰性包装：
 * 调用 `get()` 时执行获取，结果为多日预报 JSON 字符串（对齐 Android `DaysForecastProto` 持久化/序列化形态）。
 */
public interface WeatherClient {
    func fetchWeatherForecast(latitude: Float64, longitude: Float64): GeoSingle<String>
    func getTemperatureUnit(): TemperatureUnit
    func getSpeedUnit(): SpeedUnit
    func getPressureUnit(): PressureUnit
    func setTemperatureUnit(unit: TemperatureUnit): Unit
    func setSpeedUnit(unit: SpeedUnit): Unit
    func setPressureUnit(unit: PressureUnit): Unit
}
