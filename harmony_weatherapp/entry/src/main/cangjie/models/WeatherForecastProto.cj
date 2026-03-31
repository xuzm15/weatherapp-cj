package ohos_app_cangjie_entry.models

/**
 * 对齐 Android `TemperatureProto`（time、取整温度、天气图标资源名、单位）。
 */
public class TemperatureProto {
    public var time: String
    public var temperature: Int64
    public var weatherIconName: String
    public var unit: TemperatureUnit

    public init(time: String, temperature: Int64, weatherIconName: String, unit: TemperatureUnit) {
        this.time = time
        this.temperature = temperature
        this.weatherIconName = weatherIconName
        this.unit = unit
    }

    public func toTemperatureItem(): TemperatureItem {
        TemperatureItem(this.time, this.temperature, this.weatherIconName)
    }
}

public class WindSpeedProto {
    public var current: Int64
    public var diff: Int64
    public var indicatorIcon: String
    public var unit: SpeedUnit

    public init(current: Int64, diff: Int64, indicatorIcon: String, unit: SpeedUnit) {
        this.current = current
        this.diff = diff
        this.indicatorIcon = indicatorIcon
        this.unit = unit
    }
}

public class PressureProto {
    public var current: Int64
    public var diff: Int64
    public var indicatorIcon: String
    public var unit: PressureUnit

    public init(current: Int64, diff: Int64, indicatorIcon: String, unit: PressureUnit) {
        this.current = current
        this.diff = diff
        this.indicatorIcon = indicatorIcon
        this.unit = unit
    }
}

public class PrecipitationChanceProto {
    public var time: String
    public var percent: Int64
    public var diff: Int64
    public var indicatorIcon: String

    public init(time: String, percent: Int64, diff: Int64, indicatorIcon: String) {
        this.time = time
        this.percent = percent
        this.diff = diff
        this.indicatorIcon = indicatorIcon
    }
}

public class SunriseSunsetProto {
    public var time: String
    public var hourDiff: Int64
    public var minuteDiff: Int64
    public var isFuture: Bool

    public init(time: String, hourDiff: Int64, minuteDiff: Int64, isFuture: Bool) {
        this.time = time
        this.hourDiff = hourDiff
        this.minuteDiff = minuteDiff
        this.isFuture = isFuture
    }
}

/**
 * 单日摘要（对齐 Android `DayForecastProto` 核心字段）。
 */
public class DayForecastProto {
    public var currentTemp: TemperatureProto
    public var apparentTemp: TemperatureProto
    public var dayHighTemp: TemperatureProto
    public var nightLowTemp: TemperatureProto
    public var weatherIconName: String
    public var weatherResourceName: String
    public var lastUpdateTime: String
    public var sunrise: SunriseSunsetProto
    public var sunset: SunriseSunsetProto
    public var wind: WindSpeedProto
    public var precipChance: PrecipitationChanceProto
    public var pressure: PressureProto
    public var uvIndex: Int64
    public var hourlyTemps: Array<TemperatureItem>
    public var hourlyPrecip: Array<PrecipitationChanceProto>

    public init(
        currentTemp: TemperatureProto,
        apparentTemp: TemperatureProto,
        dayHighTemp: TemperatureProto,
        nightLowTemp: TemperatureProto,
        weatherIconName: String,
        weatherResourceName: String,
        lastUpdateTime: String,
        sunrise: SunriseSunsetProto,
        sunset: SunriseSunsetProto,
        wind: WindSpeedProto,
        precipChance: PrecipitationChanceProto,
        pressure: PressureProto,
        uvIndex: Int64,
        hourlyTemps: Array<TemperatureItem>,
        hourlyPrecip: Array<PrecipitationChanceProto>
    ) {
        this.currentTemp = currentTemp
        this.apparentTemp = apparentTemp
        this.dayHighTemp = dayHighTemp
        this.nightLowTemp = nightLowTemp
        this.weatherIconName = weatherIconName
        this.weatherResourceName = weatherResourceName
        this.lastUpdateTime = lastUpdateTime
        this.sunrise = sunrise
        this.sunset = sunset
        this.wind = wind
        this.precipChance = precipChance
        this.pressure = pressure
        this.uvIndex = uvIndex
        this.hourlyTemps = hourlyTemps
        this.hourlyPrecip = hourlyPrecip
    }
}

public class DailyOutlook {
    public var dateIso: String
    public var maxTemp: Int64
    public var minTemp: Int64

    public init(dateIso: String, maxTemp: Int64, minTemp: Int64) {
        this.dateIso = dateIso
        this.maxTemp = maxTemp
        this.minTemp = minTemp
    }
}

/**
 * 多日预报（对齐 Android `DaysForecastProto`：今日卡片 + 7 日高低温）。
 */
public class DaysForecastProto {
    public var today: DayForecastProto
    public var dailyOutlook: Array<DailyOutlook>
    public var rawJson: String

    public init(today: DayForecastProto, dailyOutlook: Array<DailyOutlook>, rawJson: String) {
        this.today = today
        this.dailyOutlook = dailyOutlook
        this.rawJson = rawJson
    }
}
