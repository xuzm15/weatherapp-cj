package ohos_app_cangjie_entry.components

import ohos_app_cangjie_entry.foundation.AppConfig
import ohos_app_cangjie_entry.models.{LocationCoord, PlaceInfo}
import ohos_app_cangjie_entry.models.Resource as UiResource
import ohos_app_cangjie_entry.services.{DataModule, GeoNamesClient, GeoLocale, GeoSingle, MainViewModel}
import kit.ArkUI.*
import kit.ArkData.PreferencesValueType
import kit.PerformanceAnalysisKit.Hilog
import kit.AbilityKit.{AbilityAccessCtrl, BundleManager, BundleFlag, GrantStatus}
import ohos.arkui.state_management.*
import ohos.arkui.state_macro_manage.*

private let MAIN_TAG: String = "MainFragmentCJ"

private func substringBytes(s: String, start: Int64, end: Int64): String {
    if (start < 0 || end > s.size || start >= end) {
        return ""
    }
    return s[start..end]
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
            var ip: Int64 = 0
            var fp: Int64 = 0
            let rawIp = intPart.toArray()
            var i: Int64 = 0
            while (i < rawIp.size) {
                let d = Int64(rawIp[i]) - 48
                if (d < 0 || d > 9) {
                    break
                }
                ip = ip * 10 + d
                i += 1
            }
            let rawFp = fracPart.toArray()
            i = 0
            while (i < rawFp.size) {
                let d = Int64(rawFp[i]) - 48
                if (d < 0 || d > 9) {
                    break
                }
                fp = fp * 10 + d
                i += 1
            }
            var scale: Float64 = 1.0
            var j: Int64 = 0
            while (j < i) {
                scale = scale * 10.0
                j += 1
            }
            var v = Float64(ip) + Float64(fp) / scale
            if (neg) {
                v = -v
            }
            return Some(v)
        case None =>
            var r: Int64 = 0
            let raw = substringBytes(t, start, t.size).toArray()
            var k: Int64 = 0
            while (k < raw.size) {
                let d = Int64(raw[k]) - 48
                if (d < 0 || d > 9) {
                    break
                }
                r = r * 10 + d
                k += 1
            }
            var v = Float64(r)
            if (neg) {
                v = -v
            }
            return Some(v)
    }
}

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
 * 主页容器：工具栏、下拉刷新、`TodayWeatherFragment` 天气区、搜索与设置浮层。
 */
@Component
public class MainFragment {
    private let geo: GeoNamesClient = GeoNamesClient()
    private let vm: MainViewModel = DataModule.provideMainViewModel()

    @State
    var isRefreshing: Bool = false
    @State
    var placeLine: String = ""
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

    private func persistSnapshot(): Unit {
        match (AppConfig.settingsPreferences) {
            case Some(prefs) =>
                if (!this.placeLine.isEmpty()) {
                    prefs.put("main_last_place", PreferencesValueType.StringData(this.placeLine))
                }
                let loc = this.vm.getLocation()
                prefs.put(
                    "main_last_coord",
                    PreferencesValueType.StringData("${loc.latitude},${loc.longitude}")
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
                        let c = LocationCoord(latitude: lat, longitude: lon)
                        this.vm.setLocation(c)
                        this.vm.fetchWeatherAndPlace(c)
                        this.placeLine = placeLineFromPlaceInfoModel(pi)
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
        this.vm.fetchNearestPlaceInfo(GeoLocale(tag))
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
        this.vm.onPlaceNameChanged = { r: UiResource<String> =>
            match (r) {
                case Success(s) => this.placeLine = s
                case Error(msg) =>
                    if (this.placeLine.isEmpty()) {
                        this.placeLine = msg
                    }
                case Loading => ()
            }
        }
        this.vm.onForecastNotifyComplete = { => this.isRefreshing = false }
        match (this.vm.getPlaceName()) {
            case Success(s) =>
                if (!s.isEmpty()) {
                    this.placeLine = s
                }
            case _ => ()
        }
    }

    protected override func aboutToDisappear(): Unit {
        this.persistSnapshot()
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
    func uiHeaderPlace(): Unit {
        if (!this.placeLine.isEmpty()) {
            Text(this.placeLine)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .textAlign(TextAlign.Center)
                .width(100.percent)
                .padding(left: 16, right: 16, top: 4, bottom: 4)
        }
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
            MainSettingsFragment(
                onBack: { => this.closeSettingsWithMotion() },
                onLanguageChange: { v: String => this.onSettingsLanguageChanged(v) },
                onTemperatureChange: { v: String => this.onSettingsTemperatureChanged(v) },
                onWindSpeedChange: { v: String => this.onSettingsWindSpeedChanged(v) },
                onPressureChange: { v: String => this.onSettingsPressureChanged(v) }
            )
        }
    }

    public func build() {
        Stack() {
            Column(space: 0) {
                this.uiToolbar()
                this.uiHeaderPlace()
                Refresh(RefreshOptions(refreshing: @Binder(isRefreshing))) {
                    Column(space: 0) {
                        TodayWeatherFragment()
                    }
                    .translate(x: 0.0.vp, y: (0.0 - this.headerCollapsedVp).vp)
                }
                    .enabled(this.motionSwipeEnabled)
                    .width(100.percent)
                    .layoutWeight(1)
                    .onRefreshing({
                        =>
                        this.handleLocationPermission()
                        this.isRefreshing = true
                        this.vm.fetchCurrentWeatherAndPlace()
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
