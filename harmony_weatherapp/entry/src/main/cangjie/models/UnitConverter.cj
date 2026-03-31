package ohos_app_cangjie_entry.models

/** 温度单位（对齐 Android TemperatureUnitProto：CELSIUS / FAHRENHEIT）。 */
public enum TemperatureUnit {
    | Celsius
    | Fahrenheit
}

/** 风速单位（对齐 Android SpeedUnitProto：MS / KMH / MPH）。 */
public enum SpeedUnit {
    | MS
    | KMH
    | MPH
}

/** 气压单位（对齐 Android PressureUnitProto：HPA / MMHG / INHG）。 */
public enum PressureUnit {
    | HPA
    | MMHG
    | INHG
}

private let KMH_TO_MS: Float64 = 1.0 / 3.6
private let MPH_TO_MS: Float64 = 1609.344 / 3600.0

/** 标准大气：1013.25 hPa = 760 mmHg = 29.9213 inHg */
private let HPA_PER_MMHG: Float64 = 1013.25 / 760.0
private let HPA_PER_INHG: Float64 = 1013.25 / 29.9213

private func temperatureToCelsius(temp: Float64, fromUnit: TemperatureUnit): Float64 {
    match (fromUnit) {
        case Celsius => temp
        case Fahrenheit => (temp - 32.0) * 5.0 / 9.0
    }
}

private func celsiusToTemperature(celsius: Float64, toUnit: TemperatureUnit): Float64 {
    match (toUnit) {
        case Celsius => celsius
        case Fahrenheit => celsius * 9.0 / 5.0 + 32.0
    }
}

/** 摄氏 ↔ 华氏温度转换。 */
public func convertTemperature(
    temp: Float64,
    fromUnit: TemperatureUnit,
    toUnit: TemperatureUnit
): Float64 {
    celsiusToTemperature(temperatureToCelsius(temp, fromUnit), toUnit)
}

private func speedToMetersPerSecond(speed: Float64, fromUnit: SpeedUnit): Float64 {
    match (fromUnit) {
        case MS => speed
        case KMH => speed * KMH_TO_MS
        case MPH => speed * MPH_TO_MS
    }
}

private func metersPerSecondToSpeed(ms: Float64, toUnit: SpeedUnit): Float64 {
    match (toUnit) {
        case MS => ms
        case KMH => ms / KMH_TO_MS
        case MPH => ms / MPH_TO_MS
    }
}

/** m/s、km/h、mph 之间风速转换。 */
public func convertSpeed(speed: Float64, fromUnit: SpeedUnit, toUnit: SpeedUnit): Float64 {
    metersPerSecondToSpeed(speedToMetersPerSecond(speed, fromUnit), toUnit)
}

private func pressureToHpa(pressure: Float64, fromUnit: PressureUnit): Float64 {
    match (fromUnit) {
        case HPA => pressure
        case MMHG => pressure * HPA_PER_MMHG
        case INHG => pressure * HPA_PER_INHG
    }
}

private func hpaToPressure(hpa: Float64, toUnit: PressureUnit): Float64 {
    match (toUnit) {
        case HPA => hpa
        case MMHG => hpa / HPA_PER_MMHG
        case INHG => hpa / HPA_PER_INHG
    }
}

/** hPa、mmHg、inHg 之间气压转换。 */
public func convertPressure(
    pressure: Float64,
    fromUnit: PressureUnit,
    toUnit: PressureUnit
): Float64 {
    hpaToPressure(pressureToHpa(pressure, fromUnit), toUnit)
}
