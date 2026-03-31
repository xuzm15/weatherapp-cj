package ohos_app_cangjie_entry.components

import ohos_app_cangjie_entry.foundation.AppConfig
import ohos_app_cangjie_entry.models.{LocationCoord, PlaceInfo}
import ohos_app_cangjie_entry.services.{FusedLocationProviderService, GeoNamesClient, GeoLocale, GeoSingle}
import kit.ArkUI.*
import kit.NetworkKit.*
import kit.ArkData.PreferencesValueType
import kit.PerformanceAnalysisKit.Hilog
import kit.AbilityKit.{AbilityAccessCtrl, BundleManager, BundleFlag, GrantStatus}
import ohos.business_exception.BusinessException
import ohos.arkui.state_management.*
import ohos.arkui.state_macro_manage.*
import std.collection.{ArrayList, HashMap}
import std.core.Option
import std.sync.Mutex
private let MAIN_TAG: String = "MainFragmentCJ"
private let OPEN_METEO_BASE: String = "https://api.open-meteo.com/v1/forecast"

private class HttpSyncBox {
    var errOpt: Option<BusinessException> = None
    var body: String = ""
    var done: Bool = false
}

private func substringBytes(s: String, start: Int64, end: Int64): String {
    if (start < 0 || end > s.size || start >= end) {
        return ""
    }
    return s[start..end]
}

private func httpGetBlocking(url: String): (Option<BusinessException>, String) {
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
    headers["User-Agent"] = "WeatherAppHarmony/1.0 (Cangjie; Open-Meteo)"
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
            if (j < body.size && Int64(body[j]) == 91) {
                j += 1
                while (j < body.size) {
                    let bi = Int64(body[j])
                    if (bi == 32 || bi == 10 || bi == 13) {
                        j += 1
                        continue
                    } else {
                        break
                    }
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

private func replaceFirstTWithSpace(s: String): String {
    match (s.indexOf("T")) {
        case Some(i) => substringBytes(s, 0, i) + " " + substringBytes(s, i + 1, s.size)
        case None => s
    }
}

private func wmoWeatherLabel(code: Int64): String {
    match (code) {
        case 0 => "晴朗"
        case 1 | 2 | 3 => "多云"
        case 45 | 48 => "雾"
        case 51 | 53 | 55 => "毛毛雨"
        case 61 | 63 | 65 => "雨"
        case 71 | 73 | 75 | 77 => "雪"
        case 80 | 81 | 82 => "阵雨"
        case 95 | 96 | 99 => "雷暴"
        case _ => "天气(${code})"
    }
}

/** PlaceInfo 字段在包外不可见，从 toString() 解析展示与坐标（与 models/PlaceInfo.cj 格式一致）。 */
private func extractBetweenPlaceInfo(s: String, startKey: String, endMarker: String): String {
    let needle = startKey + "="
    match (s.indexOf(needle)) {
        case Some(i) =>
            let from = i + needle.size
            match (s.indexOf(endMarker, from)) {
                case Some(j) => substringBytes(s, from, j)
                case None => ""
            }
        case None => ""
    }
}

private func placeLineFromPlaceInfoModel(p: PlaceInfo): String {
    let s = p.toString()
    let t = extractBetweenPlaceInfo(s, "toponymName", ", countryName=")
    let c = extractBetweenPlaceInfo(s, "countryName", ", countryCode=")
    if (!t.isEmpty() && !c.isEmpty()) {
        return t + ", " + c
    }
    if (!t.isEmpty()) {
        return t
    }
    let lat = extractBetweenPlaceInfo(s, "latitude", ", longitude=")
    let lon = extractBetweenPlaceInfo(s, "longitude", ")")
    return lat + ", " + lon
}

private func latLonStringsFromPlaceInfoModel(p: PlaceInfo): (String, String) {
    let s = p.toString()
    let lat = extractBetweenPlaceInfo(s, "latitude", ", longitude=")
    let lon = extractBetweenPlaceInfo(s, "longitude", ")")
    return (lat, lon)
}

/**
 * 主页天气容器：对应 Android MainFragment。
 */
@Component
public class MainFragment {
    private let fused: FusedLocationProviderService = FusedLocationProviderService()
    private let geo: GeoNamesClient = GeoNamesClient()

    @State
    var isRefreshing: Bool = false
    @State
    var mainDegree: String = "--"
    @State
    var feelsLike: String = ""
    @State
    var weatherMainText: String = ""
    @State
    var lastUpdateText: String = ""
    @State
    var dayNightText: String = ""
    @State
    var placeLine: String = ""
    @State
    var errorBanner: String = ""
    @State
    var showSearchOverlay: Bool = false
    @State
    var showSettingsOverlay: Bool = false
    @State
    var searchPlaceResults: Array<PlaceInfo> = Array<PlaceInfo>()
    @State
    var motionSwipeEnabled: Bool = true
    @State
    var headerCollapsedVp: Float64 = 0.0

    private var lastLat: Float64 = FusedLocationProviderService.DEFAULT_LAT
    private var lastLon: Float64 = FusedLocationProviderService.DEFAULT_LON
    private var lastForecastJson: String = ""

    private func hasLocationPermission(): Bool {
        try {
            let tokenID = BundleManager.getBundleInfoForSelf(BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).appInfo.accessTokenId
            let atManager = AbilityAccessCtrl.createAtManager()
            let coarse = atManager.checkAccessToken(tokenID, "ohos.permission.APPROXIMATELY_LOCATION") == GrantStatus.PermissionGranted
            let fine = atManager.checkAccessToken(tokenID, "ohos.permission.LOCATION") == GrantStatus.PermissionGranted
            return coarse || fine
        } catch (e: Exception) {
            Hilog.error(1, MAIN_TAG, "permission check: ${e.message}")
            return false
        }
    }

    private func toast(msg: String): Unit {
        getUIContext().getPromptAction().showToast(ShowToastOptions(message: msg))
    }

    private func fetchOpenMeteo(lat: Float64, lon: Float64): Unit {
        let url =
            OPEN_METEO_BASE + "?latitude=" + coordStr(lat) + "&longitude=" + coordStr(lon) +
                "&current=temperature_2m,apparent_temperature,weather_code,time&daily=temperature_2m_max,temperature_2m_min&timezone=auto"
        let (_, body) = httpGetBlocking(url)
        if (body.isEmpty()) {
            this.errorBanner = "天气数据为空"
            return
        }
        this.lastForecastJson = body
        let temp = extractJsonNumberToken(body, "temperature_2m")
        let app = extractJsonNumberToken(body, "apparent_temperature")
        let wcStr = extractJsonNumberToken(body, "weather_code")
        let timeStr = extractQuoted(body, "time")
        let wc = parseInt64Digits(wcStr)
        if (!temp.isEmpty()) {
            this.mainDegree = temp + "°"
        }
        if (!app.isEmpty()) {
            this.feelsLike = "体感 " + app + "°"
        }
        this.weatherMainText = wmoWeatherLabel(wc)
        if (!timeStr.isEmpty()) {
            this.lastUpdateText = "更新 " + replaceFirstTWithSpace(timeStr)
        }
        let dmax = extractJsonNumberToken(body, "temperature_2m_max")
        let dmin = extractJsonNumberToken(body, "temperature_2m_min")
        if (!dmax.isEmpty() && !dmin.isEmpty()) {
            this.dayNightText = "昼夜 " + dmax + "° / " + dmin + "°"
        } else {
            this.dayNightText = ""
        }
        this.errorBanner = ""
    }

    private func coordStr(v: Float64): String {
        return "${v}"
    }

    private func runFetchPipeline(): Unit {
        this.isRefreshing = true
        this.errorBanner = ""
        if (!this.hasLocationPermission()) {
            this.errorBanner = "未授予定位权限，使用默认坐标拉取天气"
        }
        this.fused.requestLocationAsync({ c =>
            this.lastLat = c.latitude
            this.lastLon = c.longitude
            let placeSingle: GeoSingle<PlaceInfo> = this.geo.fetchNearestPlaceInfo(c.latitude, c.longitude)
            let p = placeSingle.get()
            let line = placeLineFromPlaceInfoModel(p)
            this.placeLine = line
            this.fetchOpenMeteo(c.latitude, c.longitude)
            this.isRefreshing = false
        })
    }

    private func persistSnapshot(): Unit {
        match (AppConfig.settingsPreferences) {
            case Some(prefs) =>
                if (!this.placeLine.isEmpty()) {
                    prefs.put("main_last_place", PreferencesValueType.StringData(this.placeLine))
                }
                if (!this.lastForecastJson.isEmpty()) {
                    prefs.put("main_last_forecast_json", PreferencesValueType.StringData(this.lastForecastJson))
                }
                prefs.put(
                    "main_last_coord",
                    PreferencesValueType.StringData(coordStr(this.lastLat) + "," + coordStr(this.lastLon))
                )
                try {
                    prefs.flush()
                } catch (e: Exception) {
                    Hilog.error(1, MAIN_TAG, "preferences flush: ${e.message}")
                }
            case None => Hilog.info(1, MAIN_TAG, "settings store not ready; skip persist")
        }
    }

    private func runSearchMenuQuery(q: String): Unit {
        let t = q.trimAscii()
        if (t.isEmpty()) {
            this.toast("请输入城市或地址")
            return
        }
        let single = this.geo.searchLocation(t)
        let arr = single.get()
        this.searchPlaceResults = arr
        if (arr.size == 0) {
            this.toast("未找到结果")
        }
    }

    private func applyPlaceFromSearch(pi: PlaceInfo): Unit {
        let (latS, lonS) = latLonStringsFromPlaceInfoModel(pi)
        match (parseFloat64Loose(latS)) {
            case Some(lat) =>
                match (parseFloat64Loose(lonS)) {
                    case Some(lon) =>
                        this.lastLat = lat
                        this.lastLon = lon
                        let c = LocationCoord(latitude: lat, longitude: lon)
                        this.fused.setLocation(c)
                        this.placeLine = placeLineFromPlaceInfoModel(pi)
                        this.fetchOpenMeteo(lat, lon)
                        this.showSearchOverlay = false
                        this.searchPlaceResults = Array<PlaceInfo>()
                        this.toast("已切换位置")
                    case None => this.toast("坐标无效")
                }
            case None => this.toast("坐标无效")
        }
    }

    private func openSettingsWithMotion(): Unit {
        getUIContext().animateTo(AnimateParam(duration: 280, curve: Curve.EaseInOut), {
            =>
            this.motionSwipeEnabled = false
            this.headerCollapsedVp = 40.0
            this.showSettingsOverlay = true
        })
    }

    private func closeSettingsWithMotion(): Unit {
        getUIContext().animateTo(AnimateParam(duration: 280, curve: Curve.EaseInOut), {
            =>
            this.showSettingsOverlay = false
            this.headerCollapsedVp = 0.0
            this.motionSwipeEnabled = true
        })
    }

    private func localeTagFromLanguageCode(code: String): String {
        let c = code.trimAscii().toAsciiLower()
        if (c == "ru") {
            return "ru-RU"
        }
        return "en-US"
    }

    private func onSettingsLanguageChanged(code: String): Unit {
        let tag = this.localeTagFromLanguageCode(code)
        this.geo.setLocale(GeoLocale(tag))
        let single = this.geo.fetchNearestPlaceInfo(this.lastLat, this.lastLon)
        let p = single.get()
        this.placeLine = placeLineFromPlaceInfoModel(p)
    }

    private func onSettingsTemperatureChanged(code: String): Unit {
        this.toast("温度单位已更新为 " + code)
    }

    private func onSettingsWindSpeedChanged(code: String): Unit {
        this.toast("风速单位已更新为 " + code)
    }

    private func onSettingsPressureChanged(code: String): Unit {
        this.toast("气压单位已更新为 " + code)
    }

    protected override func aboutToAppear(): Unit {
        this.geo.setLocale(GeoLocale("zh-CN"))
        this.runFetchPipeline()
    }

    protected override func aboutToDisappear(): Unit {
        this.persistSnapshot()
    }

    @Builder
    func uiWeather(): Unit {
        Column(space: 8) {
            Text(this.placeLine)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .textAlign(TextAlign.Center)
                .width(100.percent)
            Text(this.mainDegree)
                .fontSize(44)
                .fontWeight(FontWeight.Bold)
                .textAlign(TextAlign.Center)
                .width(100.percent)
            Text(this.weatherMainText)
                .fontSize(16)
                .textAlign(TextAlign.Center)
                .width(100.percent)
            Text(this.feelsLike)
                .fontSize(14)
                .textAlign(TextAlign.Center)
                .width(100.percent)
            Text(this.dayNightText)
                .fontSize(14)
                .textAlign(TextAlign.Center)
                .width(100.percent)
            Text(this.lastUpdateText)
                .fontSize(12)
                .fontColor(0xFF888888)
                .textAlign(TextAlign.Center)
                .width(100.percent)
            if (!this.errorBanner.isEmpty()) {
                Text(this.errorBanner)
                    .fontSize(12)
                    .fontColor(0xFFFF6600)
                    .textAlign(TextAlign.Center)
                    .width(100.percent)
            }
        }.width(100.percent).padding(16)
    }

    @Builder
    func uiToolbar(): Unit {
        Row(space: 12) {
            Button("搜索")
                .onClick({ _ =>
                    this.searchPlaceResults = Array<PlaceInfo>()
                    this.showSearchOverlay = true
                })
            Button("设置")
                .onClick({ _ =>
                    this.openSettingsWithMotion()
                })
        }
        .width(100.percent)
        .justifyContent(FlexAlign.End)
        .padding(12)
    }

    @Builder
    func uiSearchOverlay(): Unit {
        SearchMenuFragment(
            visible: this.showSearchOverlay,
            searchResults: this.searchPlaceResults,
            onSearch: { q: String => this.runSearchMenuQuery(q) },
            onPlaceSelected: { pi: PlaceInfo => this.applyPlaceFromSearch(pi) },
            onDismiss: { => this.showSearchOverlay = false }
        )
    }

    @Builder
    func uiSettingsOverlay(): Unit {
        if (this.showSettingsOverlay) {
            Column(space: 12) {
                SettingsFragment(
                    onLanguageChange: { v: String => this.onSettingsLanguageChanged(v) },
                    onTemperatureChange: { v: String => this.onSettingsTemperatureChanged(v) },
                    onWindSpeedChange: { v: String => this.onSettingsWindSpeedChanged(v) },
                    onPressureChange: { v: String => this.onSettingsPressureChanged(v) }
                )
                Button("返回")
                    .onClick({ _ =>
                        this.closeSettingsWithMotion()
                    })
            }
            .width(100.percent)
            .height(100.percent)
            .padding(20)
            .backgroundColor(0xFFF5F5F5)
        }
    }

    public func build() {
        Stack() {
            Column(space: 0) {
                this.uiToolbar()
                Refresh(RefreshOptions(refreshing: @Binder(isRefreshing))) {
                    Column(space: 0) {
                        this.uiWeather()
                    }
                    .translate(x: 0.0.vp, y: (0.0 - this.headerCollapsedVp).vp)
                }
                    .enabled(this.motionSwipeEnabled)
                    .width(100.percent)
                    .layoutWeight(1)
                    .onRefreshing({
                        =>
                        this.handleLocationPermission()
                        this.runFetchPipeline()
                    })
                    .onStateChange({
                        st: RefreshStatus =>
                        match (st) {
                            case Refresh => this.motionSwipeEnabled = false
                            case Done | Inactive => this.motionSwipeEnabled = !this.showSettingsOverlay
                            case _ => ()
                        }
                    })
            }
            .width(100.percent)
            .height(100.percent)

            this.uiSearchOverlay()
            this.uiSettingsOverlay()
        }
        .width(100.percent)
        .height(100.percent)
    }

    private func handleLocationPermission(): Unit {
        if (!this.hasLocationPermission()) {
            this.toast("需要定位权限：请在系统设置中授予本应用定位权限")
        }
    }
}
