package ohos_app_cangjie_entry.models

/**
 * WMO 天气代码映射：描述文案与昼夜图标资源名（对齐 Android `WeatherCode`）。
 * 表项按 `code` 升序，供二分查找。
 */
public class WeatherCodeEntry {
    public let code: Int64
    public let description: String
    public let dayIcon: String
    public let nightIcon: String

    public init(code: Int64, description: String, dayIcon: String, nightIcon: String) {
        this.code = code
        this.description = description
        this.dayIcon = dayIcon
        this.nightIcon = nightIcon
    }
}

private class WeatherCodeRow {
    let code: Int64
    let stringName: String
    let description: String
    let dayIcon: String
    let nightIcon: String

    public init(
        code: Int64,
        stringName: String,
        description: String,
        dayIcon: String,
        nightIcon: String
    ) {
        this.code = code
        this.stringName = stringName
        this.description = description
        this.dayIcon = dayIcon
        this.nightIcon = nightIcon
    }
}

private let WEATHER_CODE_ROWS: Array<WeatherCodeRow> = [
    WeatherCodeRow(0, "clear_sky", "Clear Sky", "ic_clear_day", "ic_clear_night"),
    WeatherCodeRow(1, "mainly_clear", "Mainly Clear", "ic_cloudy_2_day", "ic_cloudy_2_night"),
    WeatherCodeRow(2, "partly_cloudy", "Partly Cloudy", "ic_cloudy_2_day", "ic_cloudy_2_night"),
    WeatherCodeRow(3, "overcast", "Overcast", "ic_cloudy", "ic_cloudy"),
    WeatherCodeRow(45, "fog", "Fog", "ic_fog", "ic_fog"),
    WeatherCodeRow(48, "ice_fog", "Ice Fog", "ic_ice_fog", "ic_ice_fog"),
    WeatherCodeRow(51, "light_drizzle", "Light Drizzle", "ic_drizzle_1_day", "ic_drizzle_1_night"),
    WeatherCodeRow(53, "drizzle", "Drizzle", "ic_drizzle_2_day", "ic_drizzle_2_night"),
    WeatherCodeRow(55, "heavy_drizzle", "Heavy Drizzle", "ic_drizzle_3_day", "ic_drizzle_3_night"),
    WeatherCodeRow(
        56,
        "light_freezing_drizzle",
        "Light Freezing Drizzle",
        "ic_drizzle_and_snow_1_day",
        "ic_drizzle_and_snow_1_night"
    ),
    WeatherCodeRow(
        57,
        "freezing_drizzle",
        "Freezing Drizzle",
        "ic_drizzle_and_snow_3_day",
        "ic_drizzle_and_snow_3_night"
    ),
    WeatherCodeRow(61, "light_rain", "Light Rain", "ic_rainy_1_day", "ic_rainy_1_night"),
    WeatherCodeRow(63, "rain", "Rain", "ic_rainy_2_day", "ic_rainy_2_night"),
    WeatherCodeRow(65, "heavy_rain", "Heavy Rain", "ic_rainy_3", "ic_rainy_3"),
    WeatherCodeRow(
        66,
        "light_freezing_rain",
        "Light Freezing Rain",
        "ic_rainy_and_snow_1_day",
        "ic_rainy_and_snow_1_night"
    ),
    WeatherCodeRow(67, "freezing_rain", "Freezing Rain", "ic_rainy_and_snow_3", "ic_rainy_and_snow_3"),
    WeatherCodeRow(71, "light_snow", "Light Snow", "ic_snowy_1_day", "ic_snowy_1_night"),
    WeatherCodeRow(73, "snow", "Snow", "ic_snowy_2_day", "ic_snowy_2_night"),
    WeatherCodeRow(75, "heavy_snow", "Heavy Snow", "ic_snowy_3", "ic_snowy_3"),
    WeatherCodeRow(77, "snow_grains", "Snow Grains", "ic_hail", "ic_hail"),
    WeatherCodeRow(80, "light_showers", "Light Showers", "ic_showers_1", "ic_showers_1"),
    WeatherCodeRow(81, "showers", "Showers", "ic_showers_2", "ic_showers_2"),
    WeatherCodeRow(82, "heavy_showers", "Heavy Showers", "ic_showers_3", "ic_showers_3"),
    WeatherCodeRow(
        85,
        "light_snow_showers",
        "Light Snow Showers",
        "ic_showers_and_snow_1",
        "ic_showers_and_snow_1"
    ),
    WeatherCodeRow(
        86,
        "snow_showers",
        "Snow Showers",
        "ic_showers_and_snow_3",
        "ic_showers_and_snow_3"
    ),
    WeatherCodeRow(95, "thunderstorm", "Thunderstorm", "ic_thunderstorms", "ic_thunderstorms"),
    WeatherCodeRow(
        96,
        "light_thunderstorm_hail",
        "Light T-storm w/ hail",
        "ic_thunderstorms_and_hail",
        "ic_thunderstorms_and_hail"
    ),
    WeatherCodeRow(
        99,
        "thunderstorm_hail",
        "T-storm w/ hail",
        "ic_thunderstorms_and_hail_heavy",
        "ic_thunderstorms_and_hail_heavy"
    )
]

private func searchWeatherCodeRow(code: Int64): Option<WeatherCodeRow> {
    var left: Int64 = 0
    var right: Int64 = WEATHER_CODE_ROWS.size - 1
    while (left <= right) {
        let mid: Int64 = left + (right - left) / 2
        let midRow = WEATHER_CODE_ROWS[mid]
        let midCode = midRow.code
        if (code > midCode) {
            left = mid + 1
        } else if (code < midCode) {
            right = mid - 1
        } else {
            return Some(midRow)
        }
    }
    return None
}

private func rowToEntry(r: WeatherCodeRow): WeatherCodeEntry {
    WeatherCodeEntry(r.code, r.description, r.dayIcon, r.nightIcon)
}

/** 按 WMO 代码二分查找；命中返回条目，否则 `None`。 */
public func searchByCode(code: Int64): Option<WeatherCodeEntry> {
    match (searchWeatherCodeRow(code)) {
        case Some(r) => Some(rowToEntry(r))
        case None => None
    }
}

/**
 * 对齐 Android `getResIdByCode`：此处返回字符串资源名（如 `clear_sky`），供 `$r('app.string.xxx')` 等解析。
 */
public func getResIdByCode(code: Int64): Option<String> {
    match (searchWeatherCodeRow(code)) {
        case Some(r) => Some(r.stringName)
        case None => None
    }
}

/**
 * 对齐 Android `getIconIdByCode`：返回 drawable 资源名字符串（无扩展名，与 Android `R.drawable` 基名一致）。
 */
public func getIconIdByCode(code: Int64, isDay: Bool): Option<String> {
    match (searchWeatherCodeRow(code)) {
        case Some(r) => Some(if (isDay) {
            r.dayIcon
        } else {
            r.nightIcon
        })
        case None => None
    }
}
