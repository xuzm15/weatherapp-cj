package ohos_app_cangjie_entry.services

import ohos_app_cangjie_entry.foundation.AppConfig
import ohos_app_cangjie_entry.models.LocationCoord
import kit.ArkData.{ Preferences, PreferencesValueType }
import kit.PerformanceAnalysisKit.Hilog
import std.core.StringBuilder

private let PDSR_TAG: String = "ProtoDataStoreRepo"

/** 与 `SettingsFragment` 一致，保证设置读写同一套键。 */
private let K_LANG: String = "pref_language"
private let K_TEMP: String = "pref_temperature_unit"
private let K_WIND: String = "pref_wind_speed_unit"
private let K_PRESS: String = "pref_pressure_unit"

private let K_PDSR_FULL: String = "pdsr_datastore_proto_json"
private let K_PDSR_FORECAST: String = "pdsr_forecast_json"
private let K_PDSR_LOCATION: String = "pdsr_location_coord_json"

private func substringBytes(s: String, start: Int64, end: Int64): String {
    if (start < 0 || end > s.size || start >= end) {
        return ""
    }
    return s[start..end]
}

private func floatToString(v: Float64): String {
    return "${v}"
}

private func extractQuoted(body: String, key: String): String {
    let needle = "\"" + key + "\":\""
    match (body.indexOf(needle)) {
        case Some(i) =>
            let start = i + needle.size
            match (body.indexOf("\"", start)) {
                case Some(j) => substringBytes(body, start, j)
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

private func extractJsonNumberToken(body: String, key: String): String {
    let needle = "\"" + key + "\":"
    match (body.indexOf(needle)) {
        case Some(i) =>
            var j = i + needle.size
            while (j < body.size) {
                let bi = Int64(body[j])
                if (bi == 32 || bi == 10 || bi == 13) {
                    j += 1
                    continue
                } else {
                    break
                }
            }
            var k = j
            while (k < body.size) {
                let bi = Int64(body[k])
                if ((bi >= 48 && bi <= 57) || bi == 46 || bi == 45) {
                    k += 1
                    continue
                } else {
                    break
                }
            }
            return substringBytes(body, j, k)
        case None => ""
    }
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

private func quoteJsonString(s: String): String {
    let raw = s.toArray()
    var sb = StringBuilder()
    sb.append("\"")
    var i: Int64 = 0
    while (i < raw.size) {
        let bi = Int64(raw[i])
        if (bi == 92) {
            sb.append("\\\\")
        } else if (bi == 34) {
            sb.append("\\\"")
        } else if (bi == 10) {
            sb.append("\\n")
        } else if (bi == 13) {
            sb.append("\\r")
        } else {
            sb.append(String.fromUtf8([raw[i]]))
        }
        i += 1
    }
    sb.append("\"")
    return sb.toString()
}

private func coordToJson(c: LocationCoord): String {
    return "{\"latitude\":" + floatToString(c.latitude) + ",\"longitude\":" + floatToString(c.longitude) + "}"
}

private func defaultSettingsJson(): String {
    return "{\"language\":\"en\",\"temperatureUnit\":\"celsius\",\"windSpeedUnit\":\"kmh\",\"pressureUnit\":\"hpa\"}"
}

private func buildSettingsObjectJson(lang: String, temp: String, wind: String, press: String): String {
    return "{\"language\":\"" + lang + "\",\"temperatureUnit\":\"" + temp + "\",\"windSpeedUnit\":\"" + wind +
        "\",\"pressureUnit\":\"" + press + "\"}"
}

/**
 * 对应 Android `ProtoDataStoreRepository`：Jetpack DataStore + Protobuf 在鸿蒙侧以
 * `AppConfig.settingsPreferences`（Preferences）+ JSON 字符串实现；无 RxJava Flow，均为同步读写。
 */
public class ProtoDataStoreRepository {
    public static let INSTANCE: ProtoDataStoreRepository = ProtoDataStoreRepository()

    private init() {}

    private func readPrefString(prefs: Preferences, key: String, default: String): String {
        match (prefs.get(key, PreferencesValueType.StringData(default))) {
            case StringData(s) => s
            case _ => default
        }
    }

    private func flushPrefs(prefs: Preferences): Unit {
        try {
            prefs.flush()
        } catch (e: Exception) {
            Hilog.error(1, PDSR_TAG, "preferences flush failed: ${e.message}")
        }
    }

    /** 读取 `SettingsProto` 等价 JSON（与 `pref_*` 键一致）。 */
    public func getSettings(): String {
        match (AppConfig.settingsPreferences) {
            case Some(prefs) =>
                let lang = this.readPrefString(prefs, K_LANG, "en")
                let temp = this.readPrefString(prefs, K_TEMP, "celsius")
                let wind = this.readPrefString(prefs, K_WIND, "kmh")
                let press = this.readPrefString(prefs, K_PRESS, "hpa")
                return buildSettingsObjectJson(lang, temp, wind, press)
            case None =>
                Hilog.error(1, PDSR_TAG, "getSettings: preferences not initialized")
                return defaultSettingsJson()
        }
    }

    /** 写入设置 JSON，并同步到与 `SettingsFragment` 相同的 `pref_*` 键。 */
    public func saveSettings(json: String): Unit {
        let lang = extractQuoted(json, "language")
        let temp = extractQuoted(json, "temperatureUnit")
        let wind = extractQuoted(json, "windSpeedUnit")
        let press = extractQuoted(json, "pressureUnit")
        var vLang: String = lang
        if (vLang.isEmpty()) {
            vLang = "en"
        }
        var vTemp: String = temp
        if (vTemp.isEmpty()) {
            vTemp = "celsius"
        }
        var vWind: String = wind
        if (vWind.isEmpty()) {
            vWind = "kmh"
        }
        var vPress: String = press
        if (vPress.isEmpty()) {
            vPress = "hpa"
        }
        match (AppConfig.settingsPreferences) {
            case Some(prefs) =>
                prefs.put(K_LANG, PreferencesValueType.StringData(vLang))
                prefs.put(K_TEMP, PreferencesValueType.StringData(vTemp))
                prefs.put(K_WIND, PreferencesValueType.StringData(vWind))
                prefs.put(K_PRESS, PreferencesValueType.StringData(vPress))
                this.flushPrefs(prefs)
            case None => Hilog.error(1, PDSR_TAG, "saveSettings: preferences not initialized")
        }
    }

    /** 多日预报等原始 JSON（对齐 Android `DaysForecastProto` 持久化）。 */
    public func getForecast(): String {
        match (AppConfig.settingsPreferences) {
            case Some(prefs) => this.readPrefString(prefs, K_PDSR_FORECAST, "")
            case None =>
                Hilog.error(1, PDSR_TAG, "getForecast: preferences not initialized")
                return ""
        }
    }

    public func saveForecast(json: String): Unit {
        match (AppConfig.settingsPreferences) {
            case Some(prefs) =>
                prefs.put(K_PDSR_FORECAST, PreferencesValueType.StringData(json))
                this.flushPrefs(prefs)
            case None => Hilog.error(1, PDSR_TAG, "saveForecast: preferences not initialized")
        }
    }

    public func getLocationCoord(): LocationCoord {
        match (AppConfig.settingsPreferences) {
            case Some(prefs) =>
                let raw = this.readPrefString(prefs, K_PDSR_LOCATION, "")
                if (raw.isEmpty()) {
                    return LocationCoord()
                }
                let latStr = extractJsonNumberToken(raw, "latitude")
                let lonStr = extractJsonNumberToken(raw, "longitude")
                match (parseFloat64Loose(latStr)) {
                    case Some(lat) =>
                        match (parseFloat64Loose(lonStr)) {
                            case Some(lon) => LocationCoord(latitude: lat, longitude: lon)
                            case None => LocationCoord()
                        }
                    case None => LocationCoord()
                }
            case None =>
                Hilog.error(1, PDSR_TAG, "getLocationCoord: preferences not initialized")
                return LocationCoord()
        }
    }

    public func saveLocationCoord(coord: LocationCoord): Unit {
        let raw = coordToJson(coord)
        match (AppConfig.settingsPreferences) {
            case Some(prefs) =>
                prefs.put(K_PDSR_LOCATION, PreferencesValueType.StringData(raw))
                this.flushPrefs(prefs)
            case None => Hilog.error(1, PDSR_TAG, "saveLocationCoord: preferences not initialized")
        }
    }

    private func buildCompositeSnapshot(): String {
        let ss = this.getSettings()
        let fc = this.getForecast()
        let lc = this.getLocationCoord()
        return "{\"settings\":" + ss + ",\"forecast\":" + quoteJsonString(fc) + ",\"location\":" + coordToJson(lc) + "}"
    }

    /** 完整快照（`DataStoreProto` 等价）：显式写入或从分项组装。 */
    public func getDataStoreProto(): String {
        match (AppConfig.settingsPreferences) {
            case Some(prefs) =>
                let blob = this.readPrefString(prefs, K_PDSR_FULL, "")
                if (!blob.isEmpty()) {
                    return blob
                }
            case None => ()
        }
        return this.buildCompositeSnapshot()
    }

    public func saveDataStoreProto(snapshot: String): Unit {
        match (AppConfig.settingsPreferences) {
            case Some(prefs) =>
                prefs.put(K_PDSR_FULL, PreferencesValueType.StringData(snapshot))
                this.flushPrefs(prefs)
            case None => Hilog.error(1, PDSR_TAG, "saveDataStoreProto: preferences not initialized")
        }
    }
}
