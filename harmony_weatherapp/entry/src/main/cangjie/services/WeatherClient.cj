package ohos_app_cangjie_entry.services

import ohos_app_cangjie_entry.models.*
import kit.NetworkKit.*
import kit.PerformanceAnalysisKit.Hilog
import ohos.business_exception.BusinessException
import std.collection.ArrayList
import std.collection.HashMap
import std.core.Option
import std.sync.Mutex

private let OPEN_METEO_TAG: String = "OpenMeteoWeather"
private let OPEN_METEO_BASE: String = "https://api.open-meteo.com/v1/forecast"
private let OPEN_METEO_UA: String = "WeatherAppHarmony/1.0 (HarmonyOS; Cangjie; Open-Meteo)"

/**
 * 对齐 Android `WeatherClient`：`fetchWeatherForecast` 返回惰性 `GeoSingle`（`get()` 阻塞直至 HTTP 完成）。
 */
public interface WeatherClient {
    func fetchWeatherForecast(latitude: Float64, longitude: Float64): GeoSingle<DaysForecastProto>
    func getTemperatureUnit(): TemperatureUnit
    func getSpeedUnit(): SpeedUnit
    func getPressureUnit(): PressureUnit
    func setTemperatureUnit(unit: TemperatureUnit): Unit
    func setSpeedUnit(unit: SpeedUnit): Unit
    func setPressureUnit(unit: PressureUnit): Unit
}

/**
 * Open-Meteo JSON API 实现：使用 `kit.NetworkKit` 同步阻塞 HTTP GET，解析 JSON 并填充 `DaysForecastProto`。
 */
public class OpenMeteoWeatherClient <: WeatherClient {
    private var temperatureUnit: TemperatureUnit = TemperatureUnit.Celsius
    private var speedUnit: SpeedUnit = SpeedUnit.KMH
    private var pressureUnit: PressureUnit = PressureUnit.HPA

    public init() {}

    public func getTemperatureUnit(): TemperatureUnit {
        this.temperatureUnit
    }

    public func getSpeedUnit(): SpeedUnit {
        this.speedUnit
    }

    public func getPressureUnit(): PressureUnit {
        this.pressureUnit
    }

    public func setTemperatureUnit(unit: TemperatureUnit): Unit {
        this.temperatureUnit = unit
    }

    public func setSpeedUnit(unit: SpeedUnit): Unit {
        this.speedUnit = unit
    }

    public func setPressureUnit(unit: PressureUnit): Unit {
        this.pressureUnit = unit
    }

    public func fetchWeatherForecast(latitude: Float64, longitude: Float64): GeoSingle<DaysForecastProto> {
        GeoSingle<DaysForecastProto>({
            =>
                let url = buildOpenMeteoUrl(latitude, longitude, this.temperatureUnit, this.speedUnit)
                let (errOpt, body) = httpGetBlockingOpenMeteo(url)
                match (errOpt) {
                    case Some(e) =>
                        Hilog.error(1, OPEN_METEO_TAG, "http error: ${e.message}")
                    case None => ()
                }
                if (body.isEmpty()) {
                    Hilog.error(1, OPEN_METEO_TAG, "empty response body")
                    return emptyDaysForecast("")
                }
                match (parseOpenMeteoJson(body, this.temperatureUnit, this.speedUnit, this.pressureUnit)) {
                    case Some(df) => df
                    case None =>
                        Hilog.error(1, OPEN_METEO_TAG, "json parse failed")
                        emptyDaysForecast(body)
                }
        })
    }
}

private func buildOpenMeteoUrl(
    latitude: Float64,
    longitude: Float64,
    tUnit: TemperatureUnit,
    sUnit: SpeedUnit
): String {
    let tempParam = match (tUnit) {
        case Celsius => "celsius"
        case Fahrenheit => "fahrenheit"
    }
    let windParam = match (sUnit) {
        case MS => "ms"
        case KMH => "kmh"
        case MPH => "mph"
    }
    let latS = "${latitude}"
    let lonS = "${longitude}"
    return OPEN_METEO_BASE + "?latitude=" + latS + "&longitude=" + lonS +
        "&current=temperature_2m,wind_speed_10m,surface_pressure,weather_code" +
        "&daily=temperature_2m_max,temperature_2m_min&hourly=temperature_2m&forecast_days=7" +
        "&timezone=auto&temperature_unit=" + tempParam + "&wind_speed_unit=" + windParam
}

private class HttpSyncBoxOm {
    var errOpt: Option<BusinessException> = None
    var body: String = ""
    var done: Bool = false
}

private func httpGetBlockingOpenMeteo(url: String): (Option<BusinessException>, String) {
    let mutex = Mutex()
    mutex.lock()
    let cond = mutex.condition()
    mutex.unlock()

    let box = HttpSyncBoxOm()
    let client = createHttp()
    let opts = HttpRequestOptions(
        expectDataType: Some(HttpDataType.StringValue)
    )
    let headers = HashMap<String, String>()
    headers["User-Agent"] = OPEN_METEO_UA
    opts.header = headers

    client.request(url, opts, { e, resp =>
        mutex.lock()
        box.errOpt = e
        match (resp) {
            case Some(r) =>
                match (r.result) {
                    case StringData(s) => box.body = s
                    case ArrayData(_) => box.body = ""
                    case _ => box.body = ""
                }
            case None => ()
        }
        box.done = true
        cond.notifyAll()
        mutex.unlock()
    })

    mutex.lock()
    while (!box.done) {
        cond.wait()
    }
    let eo = box.errOpt
    let bd = box.body
    mutex.unlock()
    client.destroy()
    return (eo, bd)
}

private func substringBytes(s: String, start: Int64, end: Int64): String {
    if (start < 0 || end > s.size || start >= end) {
        return ""
    }
    return s[start..end]
}

private func extractBalancedJsonObject(body: String, start: Int64): Option<(String, Int64)> {
    if (start >= body.size || Int64(body[start]) != 123) {
        return None
    }
    var depth: Int64 = 0
    var p = start
    while (p < body.size) {
        let bi = Int64(body[p])
        if (bi == 123) {
            depth += 1
        } else if (bi == 125) {
            depth -= 1
            if (depth == 0) {
                return Some((substringBytes(body, start, p + 1), p + 1))
            }
        }
        p += 1
    }
    return None
}

private func extractObjectAfterKey(body: String, key: String): Option<String> {
    let needle = "\"" + key + "\":"
    match (body.indexOf(needle)) {
        case Some(i) =>
            var pos = i + needle.size
            while (pos < body.size) {
                let bi = Int64(body[pos])
                if (bi == 32 || bi == 10 || bi == 13 || bi == 9) {
                    pos += 1
                    continue
                } else {
                    break
                }
            }
            if (pos >= body.size || Int64(body[pos]) != 123) {
                return None
            }
            match (extractBalancedJsonObject(body, pos)) {
                case Some((obj, _)) => Some(obj)
                case None => None
            }
        case None => None
    }
}

private func extractJsonNumberTokenIn(scope: String, key: String): String {
    let needle = "\"" + key + "\":"
    match (scope.indexOf(needle)) {
        case Some(i) =>
            var j = i + needle.size
            while (j < scope.size) {
                let bi = Int64(scope[j])
                if (bi == 32 || bi == 10 || bi == 13) {
                    j += 1
                    continue
                } else {
                    break
                }
            }
            if (j < scope.size && Int64(scope[j]) == 91) {
                j += 1
                while (j < scope.size) {
                    let bi = Int64(scope[j])
                    if (bi == 32 || bi == 10 || bi == 13) {
                        j += 1
                        continue
                    } else {
                        break
                    }
                }
            }
            var k = j
            while (k < scope.size) {
                let bi = Int64(scope[k])
                if ((bi >= 48 && bi <= 57) || bi == 46 || bi == 45) {
                    k += 1
                    continue
                } else {
                    break
                }
            }
            substringBytes(scope, j, k)
        case None => ""
    }
}

private func extractQuotedIn(scope: String, key: String): String {
    let needle = "\"" + key + "\":\""
    match (scope.indexOf(needle)) {
        case Some(i) =>
            let start = i + needle.size
            match (scope.indexOf("\"", start)) {
                case Some(j) => substringBytes(scope, start, j)
                case None => ""
            }
        case None => ""
    }
}

private func parseInt64Digits(s: String): Int64 {
    if (s.isEmpty()) {
        return 0
    }
    let raw = s.toArray()
    var i: Int64 = 0
    var neg = false
    if (i < raw.size && Int64(raw[i]) == 45) {
        neg = true
        i += 1
    }
    var r: Int64 = 0
    while (i < raw.size) {
        let d = Int64(raw[i]) - 48
        if (d < 0 || d > 9) {
            break
        }
        r = r * 10 + d
        i += 1
    }
    if (neg) {
        return -r
    }
    return r
}

private func pow10Float(n: Int64): Float64 {
    var r: Float64 = 1.0
    var i: Int64 = 0
    while (i < n) {
        r = r * 10.0
        i += 1
    }
    return r
}

private func parseFloat64Loose(s: String): Option<Float64> {
    let t = s.trimAscii()
    if (t.isEmpty()) {
        return None
    }
    var neg = false
    var start: Int64 = 0
    if (t.size > 0 && Int64(t[0]) == 45) {
        neg = true
        start = 1
    }
    match (t.indexOf(".")) {
        case Some(dot) =>
            let intPart = substringBytes(t, start, dot)
            let fracPart = substringBytes(t, dot + 1, t.size)
            let ip = parseInt64Digits(intPart)
            let fp = parseInt64Digits(fracPart)
            let scale = pow10Float(fracPart.size)
            var v = Float64(ip) + Float64(fp) / scale
            if (neg) {
                v = -v
            }
            return Some(v)
        case None =>
            let ip = parseInt64Digits(substringBytes(t, start, t.size))
            var v = Float64(ip)
            if (neg) {
                v = -v
            }
            return Some(v)
    }
}

private func splitCsvFloats(inner: String): Array<Float64> {
    let out = ArrayList<Float64>()
    var start: Int64 = 0
    var p: Int64 = 0
    while (p <= inner.size) {
        let atEnd: Bool = p == inner.size
        let bi: Int64 = if (atEnd) {
            44
        } else {
            Int64(inner[p])
        }
        if (atEnd || bi == 44) {
            let token: String = substringBytes(inner, start, p).trimAscii()
            if (!token.isEmpty()) {
                match (parseFloat64Loose(token)) {
                    case Some(v) => out.add(v)
                    case None => ()
                }
            }
            start = p + 1
        }
        p += 1
    }
    return out.toArray()
}

private func extractArrayInner(scope: String, arrayKey: String): String {
    let needle = "\"" + arrayKey + "\":["
    match (scope.indexOf(needle)) {
        case Some(i) =>
            let start = i + needle.size
            match (scope.indexOf("]", start)) {
                case Some(end) => substringBytes(scope, start, end)
                case None => ""
            }
        case None => ""
    }
}

private func splitJsonQuotedStrings(inner: String): Array<String> {
    let list = ArrayList<String>()
    var i: Int64 = 0
    let t = inner.trimAscii()
    while (i < t.size) {
        while (i < t.size) {
            let bi = Int64(t[i])
            if (bi == 32 || bi == 10 || bi == 13 || bi == 44) {
                i += 1
                continue
            } else {
                break
            }
        }
        if (i >= t.size) {
            break
        }
        if (Int64(t[i]) != 34) {
            i += 1
            continue
        }
        let start = i + 1
        match (t.indexOf("\"", start)) {
            case Some(j) =>
                list.add(substringBytes(t, start, j))
                i = j + 1
            case None => break
        }
    }
    return list.toArray()
}

private func hourLabelFromIso(iso: String): String {
    match (iso.indexOf("T")) {
        case Some(i) =>
            let rest = substringBytes(iso, i + 1, iso.size)
            match (rest.indexOf(":")) {
                case Some(j) =>
                    let hh = substringBytes(rest, 0, j)
                    let mm = if (j + 3 <= rest.size) {
                        substringBytes(rest, j + 1, j + 3)
                    } else {
                        substringBytes(rest, j + 1, rest.size)
                    }
                    hh + ":" + mm
                case None => iso
            }
        case None => iso
    }
}

private func replaceFirstTWithSpace(s: String): String {
    match (s.indexOf("T")) {
        case Some(i) => substringBytes(s, 0, i) + " " + substringBytes(s, i + 1, s.size)
        case None => s
    }
}

private func parseOpenMeteoJson(
    body: String,
    tUnit: TemperatureUnit,
    sUnit: SpeedUnit,
    pUnit: PressureUnit
): Option<DaysForecastProto> {
    let currentOpt = extractObjectAfterKey(body, "current")
    let dailyOpt = extractObjectAfterKey(body, "daily")
    let hourlyOpt = extractObjectAfterKey(body, "hourly")
    match (currentOpt) {
        case Some(current) => ()
        case None => return None
    }
    let current = match (currentOpt) {
        case Some(c) => c
        case None => ""
    }
    let daily = match (dailyOpt) {
        case Some(d) => d
        case None => ""
    }
    let hourly = match (hourlyOpt) {
        case Some(h) => h
        case None => ""
    }

    let tempStr = extractJsonNumberTokenIn(current, "temperature_2m")
    let windStr = extractJsonNumberTokenIn(current, "wind_speed_10m")
    let pressStr = extractJsonNumberTokenIn(current, "surface_pressure")
    let wcStr = extractJsonNumberTokenIn(current, "weather_code")
    let timeStr = extractQuotedIn(current, "time")

    let tempF = match (parseFloat64Loose(tempStr)) {
        case Some(v) => v
        case None => 0.0
    }
    let windF = match (parseFloat64Loose(windStr)) {
        case Some(v) => v
        case None => 0.0
    }
    let pressHpaF = match (parseFloat64Loose(pressStr)) {
        case Some(v) => v
        case None => 0.0
    }
    let wc = parseInt64Digits(wcStr)

    let iconOpt = getIconIdByCode(wc, true)
    let iconName = match (iconOpt) {
        case Some(s) => s
        case None => ""
    }
    let resOpt = getResIdByCode(wc)
    let resName = match (resOpt) {
        case Some(s) => s
        case None => ""
    }

    let curRounded: Int64 = Int64(tempF + (if (tempF >= 0.0) {
        0.5
    } else {
        -0.5
    }))

    let currentTemp = TemperatureProto("", curRounded, iconName, tUnit)
    let apparentTemp = TemperatureProto("", curRounded, iconName, tUnit)

    let dailyMaxInner = extractArrayInner(daily, "temperature_2m_max")
    let dailyMinInner = extractArrayInner(daily, "temperature_2m_min")
    let dailyTimeInner = extractArrayInner(daily, "time")
    let maxArr = splitCsvFloats(dailyMaxInner)
    let minArr = splitCsvFloats(dailyMinInner)
    let dateArr = splitJsonQuotedStrings(dailyTimeInner)

    var dayHigh: Int64 = curRounded
    var nightLow: Int64 = curRounded
    if (maxArr.size > 0) {
        let v = maxArr[0]
        dayHigh = Int64(v + (if (v >= 0.0) {
            0.5
        } else {
            -0.5
        }))
    }
    if (minArr.size > 0) {
        let v = minArr[0]
        nightLow = Int64(v + (if (v >= 0.0) {
            0.5
        } else {
            -0.5
        }))
    }

    let dayHighTemp = TemperatureProto("", dayHigh, iconName, tUnit)
    let nightLowTemp = TemperatureProto("", nightLow, iconName, tUnit)

    let pressDisplay = convertPressure(pressHpaF, PressureUnit.HPA, pUnit)
    let pressRounded: Int64 = Int64(pressDisplay + (if (pressDisplay >= 0.0) {
        0.5
    } else {
        -0.5
    }))

    let windRounded: Int64 = Int64(windF + (if (windF >= 0.0) {
        0.5
    } else {
        -0.5
    }))

    let windInd = ChangeIndicator.getIndicatorIcon(0)
    let pressInd = ChangeIndicator.getIndicatorIcon(0)
    let precipInd = ChangeIndicator.getIndicatorIcon(0)

    let windProto = WindSpeedProto(windRounded, 0, windInd, sUnit)
    let pressureProto = PressureProto(pressRounded, 0, pressInd, pUnit)
    let precipProto = PrecipitationChanceProto("", 0, 0, precipInd)

    let sunrise = SunriseSunsetProto("—", 0, 0, false)
    let sunset = SunriseSunsetProto("—", 0, 0, false)

    let hourlyTempInner = extractArrayInner(hourly, "temperature_2m")
    let hourlyTimeInner = extractArrayInner(hourly, "time")
    let hTemps = splitCsvFloats(hourlyTempInner)
    let hTimes = splitJsonQuotedStrings(hourlyTimeInner)

    let hourlyList = ArrayList<TemperatureItem>()
    var hi: Int64 = 0
    while (hi < 24 && hi < hTemps.size) {
        let tv = hTemps[hi]
        let tr: Int64 = Int64(tv + (if (tv >= 0.0) {
            0.5
        } else {
            -0.5
        }))
        let lab = if (hi < hTimes.size) {
            hourLabelFromIso(hTimes[hi])
        } else {
            "+${hi}h"
        }
        hourlyList.add(TemperatureItem(lab, tr, iconName))
        hi += 1
    }

    let hourlyPrecipList = ArrayList<PrecipitationChanceProto>()
    var pi: Int64 = 0
    while (pi < 24 && pi < hTimes.size) {
        let tlab = hourLabelFromIso(hTimes[pi])
        hourlyPrecipList.add(PrecipitationChanceProto(tlab, 0, 0, precipInd))
        pi += 1
    }

    let lastUpdate = if (!timeStr.isEmpty()) {
        replaceFirstTWithSpace(timeStr)
    } else {
        ""
    }

    let today = DayForecastProto(
        currentTemp,
        apparentTemp,
        dayHighTemp,
        nightLowTemp,
        iconName,
        resName,
        lastUpdate,
        sunrise,
        sunset,
        windProto,
        precipProto,
        pressureProto,
        0,
        hourlyList.toArray(),
        hourlyPrecipList.toArray()
    )

    let outlook = ArrayList<DailyOutlook>()
    var di: Int64 = 0
    while (di < dateArr.size && di < maxArr.size && di < minArr.size) {
        let dIso = dateArr[di]
        let mx = maxArr[di]
        let mn = minArr[di]
        let mxR: Int64 = Int64(mx + (if (mx >= 0.0) {
            0.5
        } else {
            -0.5
        }))
        let mnR: Int64 = Int64(mn + (if (mn >= 0.0) {
            0.5
        } else {
            -0.5
        }))
        outlook.add(DailyOutlook(dIso, mxR, mnR))
        di += 1
    }

    Some(DaysForecastProto(today, outlook.toArray(), body))
}

private func emptyDaysForecast(raw: String): DaysForecastProto {
    let tUnit = TemperatureUnit.Celsius
    let sUnit = SpeedUnit.KMH
    let pUnit = PressureUnit.HPA
    let z = TemperatureProto("", 0, "", tUnit)
    let w = WindSpeedProto(0, 0, ChangeIndicator.getIndicatorIcon(0), sUnit)
    let pr = PressureProto(0, 0, ChangeIndicator.getIndicatorIcon(0), pUnit)
    let pc = PrecipitationChanceProto("", 0, 0, ChangeIndicator.getIndicatorIcon(0))
    let ss = SunriseSunsetProto("—", 0, 0, false)
    let day = DayForecastProto(z, z, z, z, "", "", "", ss, ss, w, pc, pr, 0, Array<TemperatureItem>(), Array<PrecipitationChanceProto>())
    DaysForecastProto(day, Array<DailyOutlook>(), raw)
}
