package ohos_app_cangjie_entry.models

/**
 * 小时温度预报条目（对应 Android `TemperatureProto`：time、temperature、imgIdWeatherCode）。
 * 鸿蒙侧图标由调用方解析为资源路径或 URL 字符串后填入 `weatherIconName`。
 * 字段使用 `public var`，以便 `ForEach`/`@Component` 宏展开后可在 UI 闭包中读取。
 */
public class TemperatureItem <: ToString {
    public var time: String
    public var temperature: Int64
    public var weatherIconName: String

    public init(time: String, temperature: Int64, weatherIconName: String) {
        this.time = time
        this.temperature = temperature
        this.weatherIconName = weatherIconName
    }

    public func toString(): String {
        return "TemperatureItem(time=${time}, temperature=${temperature}, weatherIconName=${weatherIconName})"
    }
}
