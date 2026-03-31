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

private let GEONAMES_USER_AGENT: String =
    "WeatherAppHarmony/1.0 (HarmonyOS; Cangjie; GeoNames; contact: dev@local)"

private let GEONAMES_BASE: String = "http://api.geonames.org"
private let GEONAMES_USERNAME: String = "my_weather_app"

/**
 * 对齐 Java `GeoNamesClient`：通过 GeoNames HTTP API 实现 `GeoLocationClient`。
 */
public class GeoNamesClient <: GeoLocationClient {
    private static let LOG_TAG: String = "GeoNamesClient"

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
                let lang = primaryLangFromTag(this.locale.languageTag)
                let url =
                    GEONAMES_BASE + "/findNearbyPlaceNameJSON?lat=" + floatToString(latitude) + "&lng=" +
                        floatToString(longitude) + "&style=FULL&cities=cities1000&lang=" + percentEncode(lang) +
                        "&username=" + GEONAMES_USERNAME
                let (_, body) = httpGetBlockingGeoNames(url, this.locale.languageTag)
                if (body.isEmpty()) {
                    Hilog.info(1, LOG_TAG, "findNearbyPlaceName empty body")
                    return emptyPlace(this.locale.languageTag)
                }
                match (extractFirstGeonameObject(body)) {
                    case Some(obj) => parsePlaceInfoJsonGeo(obj)
                    case None =>
                        Hilog.info(1, LOG_TAG, "findNearbyPlaceName: no geonames entry")
                        return emptyPlace(this.locale.languageTag)
                }
        })
    }

    public func searchLocation(query: String): GeoSingle<Array<PlaceInfo>> {
        GeoSingle<Array<PlaceInfo>>({
            =>
                if (query.trimAscii().isEmpty()) {
                    return Array<PlaceInfo>()
                }
                let lang = primaryLangFromTag(this.locale.languageTag)
                let q = percentEncode(query.trimAscii())
                let url =
                    GEONAMES_BASE + "/searchJSON?q=" + q + "&style=LONG&maxRows=15&fuzzy=0.8&lang=" +
                        percentEncode(lang) + "&username=" + GEONAMES_USERNAME
                let (_, body) = httpGetBlockingGeoNames(url, this.locale.languageTag)
                if (body.isEmpty()) {
                    return Array<PlaceInfo>()
                }
                return parseGeonamesArray(body)
        })
    }
}

private func emptyPlace(lang: String): PlaceInfo {
    PlaceInfo("", "", "", lang, "", "0", "0")
}

private func floatToString(v: Float64): String {
    return "${v}"
}

private func primaryLangFromTag(languageTag: String): String {
    let t = languageTag.trimAscii()
    if (t.isEmpty()) {
        return "en"
    }
    match (t.indexOf("-")) {
        case Some(i) =>
            if (i > 0) {
                return substringBytes(t, 0, i)
            } else {
                return t
            }
        case None => t
    }
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

private func extractLangFromAlternateNames(obj: String): String {
    let marker = "\"alternateNames\":["
    match (obj.indexOf(marker)) {
        case Some(i) =>
            let from = i + marker.size
            let rest = substringBytes(obj, from, obj.size)
            match (rest.indexOf("\"lang\":\"")) {
                case Some(j) =>
                    let start = j + 8
                    match (rest.indexOf("\"", start)) {
                        case Some(k) => substringBytes(rest, start, k)
                        case None => "en"
                    }
                case None => "en"
            }
        case None => "en"
    }
}

private func extractFirstGeonameObject(body: String): Option<String> {
    let key = "\"geonames\":["
    match (body.indexOf(key)) {
        case Some(i) =>
            var pos = i + key.size
            while (pos < body.size) {
                let bi = Int64(body[pos])
                if (bi == 32 || bi == 10 || bi == 13 || bi == 9) {
                    pos += 1
                    continue
                } else {
                    break
                }
            }
            if (pos >= body.size) {
                return None
            }
            if (Int64(body[pos]) == 93) {
                return None
            }
            match (extractBalancedJsonObject(body, pos)) {
                case Some((obj, _)) => Some(obj)
                case None => None
            }
        case None => None
    }
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

private func parsePlaceInfoJsonGeo(obj: String): PlaceInfo {
    let name = extractQuoted(obj, "name")
    let country = extractQuoted(obj, "countryName")
    let countryCode = extractQuoted(obj, "countryCode").toAsciiLower()
    let langAlt = extractLangFromAlternateNames(obj)
    let admin = extractQuoted(obj, "adminName1")
    let latS = extractQuoted(obj, "lat")
    let lngS = extractQuoted(obj, "lng")
    if (latS.isEmpty() || lngS.isEmpty()) {
        Hilog.info(1, "GeoNamesClient", "GeoNames object missing lat/lng")
    }
    return PlaceInfo(name, country, countryCode, langAlt, admin, latS, lngS)
}

private func parseGeonamesArray(body: String): Array<PlaceInfo> {
    let key = "\"geonames\":["
    match (body.indexOf(key)) {
        case Some(i) =>
            var pos = i + key.size
            let list = ArrayList<PlaceInfo>()
            while (pos < body.size) {
                while (pos < body.size) {
                    let bi = Int64(body[pos])
                    if (bi == 32 || bi == 10 || bi == 13 || bi == 9 || bi == 44) {
                        pos += 1
                        continue
                    } else {
                        break
                    }
                }
                if (pos >= body.size || Int64(body[pos]) == 93) {
                    break
                }
                match (extractBalancedJsonObject(body, pos)) {
                    case Some((obj, nextPos)) =>
                        list.add(parsePlaceInfoJsonGeo(obj))
                        pos = nextPos
                    case None => break
                }
            }
            return list.toArray()
        case None => Array<PlaceInfo>()
    }
}

private class HttpSyncBoxGeo {
    var errOpt: Option<BusinessException> = None
    var body: String = ""
    var done: Bool = false
}

private func httpGetBlockingGeoNames(url: String, acceptLanguage: String): (Option<BusinessException>, String) {
    let mutex = Mutex()
    mutex.lock()
    let cond = mutex.condition()
    mutex.unlock()

    let box = HttpSyncBoxGeo()
    let client = createHttp()
    let opts = HttpRequestOptions(
        expectDataType: Some(HttpDataType.StringValue)
    )
    let headers = HashMap<String, String>()
    headers["User-Agent"] = GEONAMES_USER_AGENT
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
