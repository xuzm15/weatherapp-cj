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
    /** 将已持久化的 Open-Meteo JSON 解析为 `DaysForecastProto`（与 `fetchWeatherForecast` 同源解析）。 */
    func parseForecastJson(body: String): Option<DaysForecastProto>
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

    public func parseForecastJson(body: String): Option<DaysForecastProto> {
        parseOpenMeteoJson(body, this.temperatureUnit, this.speedUnit, this.pressureUnit)
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

private let OPEN_METEO_PAST_DAYS: Int64 = 6
private let OPEN_METEO_FORECAST_DAYS: Int64 = 10

/**
 * 对齐 Android `OpenMeteoClient` 请求参数（JSON 替代 flatbuffers；含 minutely_15、hourly、daily 全量字段）。
 */
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
    let pd = "${OPEN_METEO_PAST_DAYS}"
    let fd = "${OPEN_METEO_FORECAST_DAYS}"
    return OPEN_METEO_BASE + "?latitude=" + latS + "&longitude=" + lonS +
        "&timezone=auto&temperature_unit=" + tempParam + "&wind_speed_unit=" + windParam +
        "&past_days=" + pd + "&forecast_days=" + fd +
        "&current=weather_code,temperature_2m,apparent_temperature,wind_speed_10m,surface_pressure" +
        "&minutely_15=weather_code,temperature_2m,apparent_temperature,wind_speed_10m" +
        "&hourly=weather_code,temperature_2m,apparent_temperature,wind_speed_10m,precipitation_probability,uv_index,pressure_msl,is_day" +
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset"
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

private func parseDatePrefixFromIso(iso: String): String {
    if (iso.size >= 10) {
        return substringBytes(iso, 0, 10)
    }
    return ""
}

private func parseHourOfDayFromIso(iso: String): Int64 {
    match (iso.indexOf("T")) {
        case Some(ti) =>
            let start = ti + 1
            if (start + 2 <= iso.size) {
                let hh = substringBytes(iso, start, start + 2)
                return parseInt64Digits(hh)
            }
            return 12
        case None => 12
    }
}

private func findIndexInStringArray(arr: Array<String>, needle: String): Int64 {
    var i: Int64 = 0
    while (i < arr.size) {
        if (arr[i] == needle) {
            return i
        }
        i += 1
    }
    return -1
}

private func findLastLexicographicLe(times: Array<String>, needle: String): Int64 {
    var best: Int64 = -1
    var i: Int64 = 0
    while (i < times.size) {
        if (times[i] <= needle) {
            best = i
        }
        i += 1
    }
    if (best >= 0) {
        return best
    }
    if (times.size > 0) {
        return times.size - 1
    }
    return 0
}

private func abs64(v: Int64): Int64 {
    if (v < 0) {
        return -v
    }
    v
}

private func nthFloat(arr: Array<Float64>, n: Int64): Option<Float64> {
    if (n < 0 || n >= arr.size) {
        return None
    }
    Some(arr[n])
}

private func roundToInt64(v: Float64): Int64 {
    Int64(v + (if (v >= 0.0) {
        0.5
    } else {
        -0.5
    }))
}

private func computeDayNightHighLow(
    hourlyTemps: Array<Float64>,
    isDayFlags: Array<Float64>,
    hourIdx: Int64,
    hourOfDay: Int64
): (Int64, Int64, Bool, Bool) {
    let inStart = hourIdx - hourOfDay - 1
    var maxDay: Float64 = -1e9
    var minNight: Float64 = 1e9
    var foundDay = false
    var foundNight = false
    var i: Int64 = inStart
    while (i < inStart + 24 && i < hourlyTemps.size && i >= 0) {
        let tv = hourlyTemps[i]
        let isDay = if (i < isDayFlags.size) {
            isDayFlags[i] >= 0.5
        } else {
            false
        }
        if (isDay) {
            foundDay = true
            if (tv > maxDay) {
                maxDay = tv
            }
        } else {
            foundNight = true
            if (tv < minNight) {
                minNight = tv
            }
        }
        i += 1
    }
    let dayR = if (foundDay) {
        roundToInt64(maxDay)
    } else {
        0
    }
    let nightR = if (foundNight) {
        roundToInt64(minNight)
    } else {
        0
    }
    (dayR, nightR, foundDay, foundNight)
}

private func findDailyIndexForDatePrefix(dailyTimes: Array<String>, datePrefix: String): Int64 {
    if (datePrefix.isEmpty()) {
        return OPEN_METEO_PAST_DAYS
    }
    var i: Int64 = 0
    while (i < dailyTimes.size) {
        if (dailyTimes[i].size >= 10 && substringBytes(dailyTimes[i], 0, 10) == datePrefix) {
            return i
        }
        i += 1
    }
    return OPEN_METEO_PAST_DAYS
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
    let minutelyOpt = extractObjectAfterKey(body, "minutely_15")

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
    let minutely = match (minutelyOpt) {
        case Some(m) => m
        case None => ""
    }

    if (current.isEmpty() && hourly.isEmpty()) {
        return None
    }

    let hourlyTimeInner = extractArrayInner(hourly, "time")
    let hTimes = splitJsonQuotedStrings(hourlyTimeInner)

    var timeStr = extractQuotedIn(current, "time")
    let hourIdx: Int64 = if (!timeStr.isEmpty()) {
        let ix = findIndexInStringArray(hTimes, timeStr)
        if (ix >= 0) {
            ix
        } else {
            findLastLexicographicLe(hTimes, timeStr)
        }
    } else if (hTimes.size > 0) {
        let hi = hTimes.size / 2
        timeStr = hTimes[hi]
        hi
    } else {
        0
    }

    let datePrefix = parseDatePrefixFromIso(timeStr)
    let hourOfDay = parseHourOfDayFromIso(timeStr)

    let mTimeInner = extractArrayInner(minutely, "time")
    let mTimes = splitJsonQuotedStrings(mTimeInner)
    let minIdx: Int64 = if (!timeStr.isEmpty() && mTimes.size > 0) {
        let ix = findIndexInStringArray(mTimes, timeStr)
        if (ix >= 0) {
            ix
        } else {
            findLastLexicographicLe(mTimes, timeStr)
        }
    } else {
        if (mTimes.size > 0) {
            mTimes.size - 1
        } else {
            0
        }
    }

    let tempStr = extractJsonNumberTokenIn(current, "temperature_2m")
    let windStr = extractJsonNumberTokenIn(current, "wind_speed_10m")
    let pressStr = extractJsonNumberTokenIn(current, "surface_pressure")
    let apparStr = extractJsonNumberTokenIn(current, "apparent_temperature")
    let wcStr = extractJsonNumberTokenIn(current, "weather_code")

    let mTempInner = extractArrayInner(minutely, "temperature_2m")
    let mTempArr = splitCsvFloats(mTempInner)
    let mAppInner = extractArrayInner(minutely, "apparent_temperature")
    let mAppArr = splitCsvFloats(mAppInner)
    let mWindInner = extractArrayInner(minutely, "wind_speed_10m")
    let mWindArr = splitCsvFloats(mWindInner)
    let mWcInner = extractArrayInner(minutely, "weather_code")
    let mWcArr = splitCsvFloats(mWcInner)

    let tempF = match (nthFloat(mTempArr, minIdx)) {
        case Some(v) => v
        case None => match (parseFloat64Loose(tempStr)) {
            case Some(v) => v
            case None => 0.0
        }
    }

    let apparentF = match (nthFloat(mAppArr, minIdx)) {
        case Some(v) => v
        case None => match (parseFloat64Loose(apparStr)) {
            case Some(v) => v
            case None => tempF
        }
    }

    let windF = match (nthFloat(mWindArr, minIdx)) {
        case Some(v) => v
        case None => match (parseFloat64Loose(windStr)) {
            case Some(v) => v
            case None => 0.0
        }
    }

    let wc: Int64 = match (nthFloat(mWcArr, minIdx)) {
        case Some(v) => roundToInt64(v)
        case None => parseInt64Digits(wcStr)
    }

    let isDayInner = extractArrayInner(hourly, "is_day")
    let isDayArr = splitCsvFloats(isDayInner)
    let isDayForIcon = match (nthFloat(isDayArr, hourIdx)) {
        case Some(v) => v >= 0.5
        case None => true
    }

    let iconOpt = getIconIdByCode(wc, isDayForIcon)
    let iconName = match (iconOpt) {
        case Some(s) => s
        case None => ""
    }
    let resOpt = getResIdByCode(wc)
    let resName = match (resOpt) {
        case Some(s) => s
        case None => ""
    }

    let curRounded = roundToInt64(tempF)
    let apparentRounded = roundToInt64(apparentF)

    let currentTemp = TemperatureProto("", curRounded, iconName, tUnit)
    let apparentTemp = TemperatureProto("", apparentRounded, iconName, tUnit)

    let dailyMaxInner = extractArrayInner(daily, "temperature_2m_max")
    let dailyMinInner = extractArrayInner(daily, "temperature_2m_min")
    let dailyTimeInner = extractArrayInner(daily, "time")
    let maxArr = splitCsvFloats(dailyMaxInner)
    let minArr = splitCsvFloats(dailyMinInner)
    let dateArr = splitJsonQuotedStrings(dailyTimeInner)

    let hTempInner = extractArrayInner(hourly, "temperature_2m")
    let hTemps = splitCsvFloats(hTempInner)
    let (dayHighV, nightLowV, okDay, okNight) = computeDayNightHighLow(hTemps, isDayArr, hourIdx, hourOfDay)

    let dayIdxToday = findDailyIndexForDatePrefix(dateArr, datePrefix)

    var dayHigh: Int64 = dayHighV
    var nightLow: Int64 = nightLowV
    if (!okDay && dayIdxToday >= 0 && dayIdxToday < maxArr.size) {
        dayHigh = roundToInt64(maxArr[dayIdxToday])
    }
    if (!okNight && dayIdxToday >= 0 && dayIdxToday < minArr.size) {
        nightLow = roundToInt64(minArr[dayIdxToday])
    }
    if (dayIdxToday < 0 || dayIdxToday >= maxArr.size || dayIdxToday >= minArr.size) {
        if (maxArr.size > 0) {
            dayHigh = roundToInt64(maxArr[0])
        }
        if (minArr.size > 0) {
            nightLow = roundToInt64(minArr[0])
        }
    }

    let dayHighTemp = TemperatureProto("", dayHigh, iconName, tUnit)
    let nightLowTemp = TemperatureProto("", nightLow, iconName, tUnit)

    let pressureInner = extractArrayInner(hourly, "pressure_msl")
    let pressArr = splitCsvFloats(pressureInner)
    let pressHpaF = match (nthFloat(pressArr, hourIdx)) {
        case Some(v) => v
        case None => match (parseFloat64Loose(pressStr)) {
            case Some(v) => v
            case None => 0.0
        }
    }

    let pressDisplay = convertPressure(pressHpaF, PressureUnit.HPA, pUnit)
    let pressRounded = roundToInt64(pressDisplay)

    let prevPressF = match (nthFloat(pressArr, hourIdx - 24)) {
        case Some(v) => v
        case None => pressHpaF
    }
    let prevPressDisplay = convertPressure(prevPressF, PressureUnit.HPA, pUnit)
    let diffPress = roundToInt64(pressDisplay) - roundToInt64(prevPressDisplay)
    let pressInd = ChangeIndicator.getIndicatorIcon(diffPress)

    let windRounded = roundToInt64(windF)
    let prevWindF = match (nthFloat(mWindArr, minIdx - 24)) {
        case Some(v) => v
        case None => windF
    }
    let diffWind = windRounded - roundToInt64(prevWindF)
    let windInd = ChangeIndicator.getIndicatorIcon(diffWind)

    let precipInner = extractArrayInner(hourly, "precipitation_probability")
    let precipArr = splitCsvFloats(precipInner)
    let currPrecipF = match (nthFloat(precipArr, hourIdx)) {
        case Some(v) => v
        case None => 0.0
    }
    let prevPrecipF = match (nthFloat(precipArr, hourIdx - 24)) {
        case Some(v) => v
        case None => currPrecipF
    }
    let currPrecip = roundToInt64(currPrecipF)
    let diffPrecip = currPrecip - roundToInt64(prevPrecipF)
    let precipInd = ChangeIndicator.getIndicatorIcon(diffPrecip)

    let uvInner = extractArrayInner(hourly, "uv_index")
    let uvArr = splitCsvFloats(uvInner)
    let uvF = match (nthFloat(uvArr, hourIdx)) {
        case Some(v) => v
        case None => 0.0
    }
    let uvIdx = roundToInt64(uvF)

    let windProto = WindSpeedProto(windRounded, abs64(diffWind), windInd, sUnit)
    let pressureProto = PressureProto(pressRounded, abs64(diffPress), pressInd, pUnit)
    let precipProto = PrecipitationChanceProto("", currPrecip, abs64(diffPrecip), precipInd)

    let sunriseInner = extractArrayInner(daily, "sunrise")
    let sunsetInner = extractArrayInner(daily, "sunset")
    let sunriseArr = splitJsonQuotedStrings(sunriseInner)
    let sunsetArr = splitJsonQuotedStrings(sunsetInner)

    let srIdx = if (dayIdxToday >= 0 && dayIdxToday < sunriseArr.size) {
        dayIdxToday
    } else {
        OPEN_METEO_PAST_DAYS
    }
    let ssIdx = if (dayIdxToday >= 0 && dayIdxToday < sunsetArr.size) {
        dayIdxToday
    } else {
        OPEN_METEO_PAST_DAYS
    }

    let sunrise = if (srIdx >= 0 && srIdx < sunriseArr.size) {
        SunriseSunsetProto(hourLabelFromIso(sunriseArr[srIdx]), 0, 0, false)
    } else {
        SunriseSunsetProto("—", 0, 0, false)
    }
    let sunset = if (ssIdx >= 0 && ssIdx < sunsetArr.size) {
        SunriseSunsetProto(hourLabelFromIso(sunsetArr[ssIdx]), 0, 0, false)
    } else {
        SunriseSunsetProto("—", 0, 0, false)
    }

    let hourlyWcInner = extractArrayInner(hourly, "weather_code")
    let hWcArr = splitCsvFloats(hourlyWcInner)

    let hourlyList = ArrayList<TemperatureItem>()
    var hi: Int64 = hourIdx
    let hiEnd = hourIdx + 24
    while (hi < hiEnd && hi < hTemps.size) {
        let tv = hTemps[hi]
        let tr = roundToInt64(tv)
        let lab = if (hi < hTimes.size) {
            hourLabelFromIso(hTimes[hi])
        } else {
            "+${hi}h"
        }
        let wcc = match (nthFloat(hWcArr, hi)) {
            case Some(v) => roundToInt64(v)
            case None => wc
        }
        let wIsDay = match (nthFloat(isDayArr, hi)) {
            case Some(v) => v >= 0.5
            case None => isDayForIcon
        }
        let hIcon = match (getIconIdByCode(wcc, wIsDay)) {
            case Some(s) => s
            case None => iconName
        }
        hourlyList.add(TemperatureItem(lab, tr, hIcon))
        hi += 1
    }

    let hourlyPrecipList = ArrayList<PrecipitationChanceProto>()
    var pi: Int64 = hourIdx
    let piEnd = hourIdx + 24
    while (pi < piEnd && pi < hTimes.size && pi < precipArr.size) {
        let tlab = hourLabelFromIso(hTimes[pi])
        let pct = roundToInt64(match (nthFloat(precipArr, pi)) {
            case Some(v) => v
            case None => 0.0
        })
        hourlyPrecipList.add(PrecipitationChanceProto(tlab, pct, 0, precipInd))
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
        uvIdx,
        hourlyList.toArray(),
        hourlyPrecipList.toArray()
    )

    let outlook = ArrayList<DailyOutlook>()
    let startO = if (dayIdxToday >= 0) {
        dayIdxToday
    } else {
        0
    }
    var di: Int64 = startO
    let outlookEnd = startO + 7
    while (di < outlookEnd && di < dateArr.size && di < maxArr.size && di < minArr.size) {
        let dIso = dateArr[di]
        let mx = maxArr[di]
        let mn = minArr[di]
        let mxR = roundToInt64(mx)
        let mnR = roundToInt64(mn)
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
