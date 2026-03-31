package ohos_app_cangjie_entry.services

import ohos_app_cangjie_entry.models.PlaceInfo
import kit.NetworkKit.*
import kit.PerformanceAnalysisKit.Hilog
import ohos.business_exception.BusinessException
import std.collection.ArrayList
import std.collection.HashMap
import std.core.Option
import std.core.StringBuilder
import std.sync.Mutex

private let NOMINATIM_USER_AGENT: String =
    "WeatherAppHarmony/1.0 (HarmonyOS; Cangjie; Nominatim; contact: dev@local)"

/**
 * 与 Java `Locale` 对应的轻量封装（仓颉侧无 java.util.Locale，使用 BCP-47 语言标签）。
 */
public class GeoLocale {
    public let languageTag: String

    public init(languageTag: String) {
        this.languageTag = languageTag
    }
}

/**
 * 对应 RxJava `Single<T>`：惰性执行，`get()` 阻塞直至 HTTP 完成。
 */
public class GeoSingle<T> {
    private let supplier: () -> T

    public init(supplier: () -> T) {
        this.supplier = supplier
    }

    public func get(): T {
        return this.supplier()
    }
}

/**
 * 地理位置查询契约（对齐 Java `GeoLocationClient`）。
 */
public interface GeoLocationClient {
    func fetchNearestPlaceInfo(latitude: Float64, longitude: Float64): GeoSingle<PlaceInfo>
    func searchLocation(query: String): GeoSingle<Array<PlaceInfo>>
    func getLocale(): GeoLocale
    func setLocale(locale: GeoLocale): Unit
}

public class GeoLocationClientService <: GeoLocationClient {
    private static let TAG: String = "GeoLocationClient"

    private var locale: GeoLocale = GeoLocale("zh-CN")

    public init() {}

    public func getLocale(): GeoLocale {
        return this.locale
    }

    public func setLocale(locale: GeoLocale): Unit {
        this.locale = locale
    }

    public func fetchNearestPlaceInfo(latitude: Float64, longitude: Float64): GeoSingle<PlaceInfo> {
        GeoSingle<PlaceInfo>({
            =>
                let url =
                    "https://nominatim.openstreetmap.org/reverse?format=json&lat=" + floatToString(latitude) +
                        "&lon=" + floatToString(longitude) + "&accept-language=" + percentEncode(this.locale.languageTag)
                let (_, body) = httpGetBlocking(url, this.locale.languageTag)
                if (body.isEmpty()) {
                    Hilog.warn(1, TAG, "reverse geocode empty body")
                    return emptyPlace(this.locale.languageTag)
                }
                return parsePlaceFromNominatimJson(body, this.locale.languageTag)
        })
    }

    public func searchLocation(query: String): GeoSingle<Array<PlaceInfo>> {
        GeoSingle<Array<PlaceInfo>>({
            =>
                if (query.trimAscii().isEmpty()) {
                    return Array<PlaceInfo>()
                }
                let q = percentEncode(query.trimAscii())
                let url =
                    "https://nominatim.openstreetmap.org/search?format=json&addressdetails=1&limit=8&q=" + q +
                        "&accept-language=" + percentEncode(this.locale.languageTag)
                let (_, body) = httpGetBlocking(url, this.locale.languageTag)
                if (body.isEmpty()) {
                    return Array<PlaceInfo>()
                }
                return parseSearchArray(body, this.locale.languageTag)
        })
    }
}

private func emptyPlace(lang: String): PlaceInfo {
    PlaceInfo("", "", "", lang, "", "0", "0")
}

private func floatToString(v: Float64): String {
    return "${v}"
}

private func hexNibble(n: Int64): String {
    let digits = "0123456789ABCDEF"
    if (n < 0 || n > 15) {
        return "0"
    }
    let runes = digits.toRuneArray()
    return String([runes[n]])
}

private func percentEncode(s: String): String {
    let raw = s.toArray()
    var sb = StringBuilder()
    var i: Int64 = 0
    while (i < raw.size) {
        let b = raw[i]
        let bi = Int64(b)
        if ((bi >= 48 && bi <= 57) || (bi >= 65 && bi <= 90) || (bi >= 97 && bi <= 122) || bi == 45 || bi == 46 ||
            bi == 95 || bi == 126) {
            sb.appendFromUtf8([b])
        } else {
            let hi = (bi >> 4) & 15
            let lo = bi & 15
            sb.append("%")
            sb.append(hexNibble(hi))
            sb.append(hexNibble(lo))
        }
        i += 1
    }
    return sb.toString()
}

private func substringBytes(s: String, start: Int64, end: Int64): String {
    if (start < 0 || end > s.size || start >= end) {
        return ""
    }
    return s[start..end]
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

private func extractLatLonFromObject(obj: String): (String, String) {
    let lat = extractQuoted(obj, "lat")
    let lon = extractQuoted(obj, "lon")
    if (!lat.isEmpty() && !lon.isEmpty()) {
        return (lat, lon)
    }
    return (extractUnquotedNumber(obj, "lat"), extractUnquotedNumber(obj, "lon"))
}

private func extractUnquotedNumber(body: String, key: String): String {
    let needle = "\"" + key + "\":"
    match (body.indexOf(needle)) {
        case Some(i) =>
            var j = i + needle.size
            while (j < body.size) {
                let bi = Int64(body[j])
                if (bi == 32) {
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

private func parsePlaceFromNominatimJson(body: String, lang: String): PlaceInfo {
    let display = extractQuoted(body, "display_name")
    let toponym = if (!display.isEmpty()) {
        display
    } else {
        extractQuoted(body, "name")
    }
    let country = extractQuoted(body, "country")
    let countryCode = extractQuoted(body, "country_code").toAsciiLower()
    let admin = extractQuoted(body, "state")
    let admin2 = extractQuoted(body, "region")
    let adminPick = if (!admin.isEmpty()) {
        admin
    } else {
        admin2
    }
    let (latS, lonS) = extractLatLonFromObject(body)
    if (latS.isEmpty() || lonS.isEmpty()) {
        Hilog.warn(1, "GeoLocationClient", "missing lat/lon in nominatim json")
    }
    return PlaceInfo(toponym, country, countryCode, lang, adminPick, latS, lonS)
}

private class HttpSyncBox {
    var errOpt: Option<BusinessException> = None
    var body: String = ""
    var done: Bool = false
}

private func parseSearchArray(body: String, lang: String): Array<PlaceInfo> {
    var trimmed = body.trimAscii()
    if (!trimmed.startsWith("[") || !trimmed.endsWith("]")) {
        return Array<PlaceInfo>()
    }
    let inner = substringBytes(trimmed, 1, trimmed.size - 1).trimAscii()
    if (inner.isEmpty()) {
        return Array<PlaceInfo>()
    }
    let parts = inner.split(",{\"place_id\":", removeEmpty: false)
    let list = ArrayList<PlaceInfo>()
    var idx: Int64 = 0
    while (idx < parts.size) {
        var chunk = parts[idx]
        if (idx > 0) {
            chunk = "{\"place_id\":" + chunk
        }
        idx += 1
        var c = chunk.trimAscii()
        if (c.endsWith(",")) {
            c = c.removeSuffix(",").trimAscii()
        }
        if (c.endsWith("]")) {
            c = c.removeSuffix("]").trimAscii()
        }
        if (c.isEmpty()) {
            continue
        }
        let p = parsePlaceFromNominatimJson(c, lang)
        list.add(p)
    }
    return list.toArray()
}

private func httpGetBlocking(url: String, acceptLanguage: String): (Option<BusinessException>, String) {
    let mutex = Mutex()
    mutex.lock()
    let cond = mutex.condition()
    mutex.unlock()

    let box = HttpSyncBox()
    let client = createHttp()
    let opts = HttpRequestOptions(
        expectDataType: Some(HttpDataType.StringValue)
    )
    let headers = HashMap<String, String>()
    headers["User-Agent"] = NOMINATIM_USER_AGENT
    headers["Accept-Language"] = acceptLanguage
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
