package ohos_app_cangjie_entry.services

import ohos_app_cangjie_entry.models.DailyOutlook
import ohos_app_cangjie_entry.models.DayForecastProto
import ohos_app_cangjie_entry.models.DaysForecastProto
import ohos_app_cangjie_entry.models.LocationCoord
import ohos_app_cangjie_entry.models.PlaceInfo
import ohos_app_cangjie_entry.models.PressureProto
import ohos_app_cangjie_entry.models.PressureUnit
import ohos_app_cangjie_entry.models.Resource as UiResource
import ohos_app_cangjie_entry.models.SpeedUnit
import ohos_app_cangjie_entry.models.TemperatureItem
import ohos_app_cangjie_entry.models.TemperatureProto
import ohos_app_cangjie_entry.models.TemperatureUnit
import ohos_app_cangjie_entry.models.WindSpeedProto
import ohos_app_cangjie_entry.models.convertPressure
import ohos_app_cangjie_entry.models.convertSpeed
import ohos_app_cangjie_entry.models.convertTemperature
import std.collection.ArrayList

/**
 * 对齐 Android `MainViewModel`：持有 `WeatherForecastRepository` 与 `NetworkChecker`，
 * 管理预报与地名的 `UiResource`（models.Resource）状态；无 LiveData/RxJava，通过回调 `onDaysForecastChanged` /
 * `onPlaceNameChanged` 通知 UI。
 */
public class MainViewModel {
    private static let ERR_NO_NET: String = "No internet connection"

    private let repository: WeatherForecastRepository
    private let networkChecker: NetworkChecker

    private var daysForecastState: UiResource<DaysForecastProto> = UiResource.Loading
    private var placeNameState: UiResource<String> = UiResource.Loading

    /** 预报状态变更时调用（可在 UI 层写入 `@State`）。 */
    public var onDaysForecastChanged: (UiResource<DaysForecastProto>) -> Unit = { _ => () }
    /** 地名状态变更时调用。 */
    public var onPlaceNameChanged: (UiResource<String>) -> Unit = { _ => () }

    public init(repository: WeatherForecastRepository, networkChecker: NetworkChecker) {
        this.repository = repository
        this.networkChecker = networkChecker
        this.initData()
    }

    public func getDaysForecast(): UiResource<DaysForecastProto> {
        this.daysForecastState
    }

    public func getPlaceName(): UiResource<String> {
        this.placeNameState
    }

    /** 对齐 Android `onCleared`：当前无 Rx 订阅，仅占位。 */
    public func dispose(): Unit {}

    private func notifyDays(r: UiResource<DaysForecastProto>): Unit {
        this.daysForecastState = r
        this.onDaysForecastChanged(r)
    }

    private func notifyPlace(r: UiResource<String>): Unit {
        this.placeNameState = r
        this.onPlaceNameChanged(r)
    }

    private func initData(): Unit {
        this.applyUnitsFromPrefs()
        let savedCoord = ProtoDataStoreRepository.INSTANCE.getLocationCoord()
        if (savedCoord.latitude != 0.0 || savedCoord.longitude != 0.0) {
            this.repository.setLocation(savedCoord)
        }
        let cachedJson = this.repository.getDaysForecastResponse()
        if (!cachedJson.isEmpty()) {
            match (this.repository.parseForecastJson(cachedJson)) {
                case Some(df) =>
                    let formatted = this.formatDaysForecast(df)
                    this.notifyDays(UiResource.Success(formatted))
                case None => ()
            }
        }
        this.repository.requestLocationAsync({ loc => this.fetchWeatherAndPlace(loc) })
    }

    private func applyUnitsFromPrefs(): Unit {
        let json = this.repository.getSettings()
        let t = this.parseTemperatureUnit(extractQuoted(json, "temperatureUnit"))
        let s = this.parseSpeedUnit(extractQuoted(json, "windSpeedUnit"))
        let p = this.parsePressureUnit(extractQuoted(json, "pressureUnit"))
        this.repository.setTemperatureUnit(t)
        this.repository.setSpeedUnit(s)
        this.repository.setPressureUnit(p)
    }

    private func parseTemperatureUnit(raw: String): TemperatureUnit {
        let lower = raw.toAsciiLower()
        if (lower == "fahrenheit") {
            TemperatureUnit.Fahrenheit
        } else {
            TemperatureUnit.Celsius
        }
    }

    private func parseSpeedUnit(raw: String): SpeedUnit {
        let lower = raw.toAsciiLower()
        if (lower == "ms") {
            SpeedUnit.MS
        } else if (lower == "mph") {
            SpeedUnit.MPH
        } else {
            SpeedUnit.KMH
        }
    }

    private func parsePressureUnit(raw: String): PressureUnit {
        let lower = raw.toAsciiLower()
        if (lower == "mmhg") {
            PressureUnit.MMHG
        } else if (lower == "inhg") {
            PressureUnit.INHG
        } else {
            PressureUnit.HPA
        }
    }

    public func getLocation(): LocationCoord {
        this.repository.getLocation()
    }

    public func setLocation(location: LocationCoord): Unit {
        this.repository.setLocation(location)
    }

    public func saveDataStore(snapshot: String): Unit {
        this.repository.saveDataStore(snapshot)
    }

    /** 从持久化读取坐标（对齐 `getSavedLocationCoord` LiveData 语义）。 */
    public func getSavedLocationCoord(onResult: (LocationCoord) -> Unit): Unit {
        onResult(ProtoDataStoreRepository.INSTANCE.getLocationCoord())
    }

    /** 设置 JSON 字符串（对齐 `getSavedSettings`）。 */
    public func getSavedSettings(onResult: (String) -> Unit): Unit {
        onResult(this.repository.getSettings())
    }

    /** 若本地有缓存预报 JSON 且可解析则回调，否则不调用。 */
    public func getSavedDaysForecast(onResult: (DaysForecastProto) -> Unit): Unit {
        let raw = this.repository.getDaysForecastResponse()
        if (raw.isEmpty()) {
            return ()
        }
        match (this.repository.parseForecastJson(raw)) {
            case Some(d) => onResult(this.formatDaysForecast(d))
            case None => ()
        }
    }

    public func fetchCurrentWeatherAndPlace(): Unit {
        this.repository.requestLocationAsync({ loc => this.fetchWeatherAndPlace(loc) })
    }

    public func fetchWeatherAndPlace(location: LocationCoord): Unit {
        this.safeFetchWeatherForecast(location.latitude, location.longitude)
        this.safeFetchNearestPlaceInfo(location.latitude, location.longitude)
    }

    public func fetchNearestPlaceInfo(locale: GeoLocale): Unit {
        this.repository.setLocale(locale)
        let loc = this.repository.getLocation()
        this.safeFetchNearestPlaceInfo(loc.latitude, loc.longitude)
    }

    /**
     * 搜索地点（对齐 `searchLocation` LiveData）：先 `Loading`，再 `Success`/`Error`。
     */
    public func searchLocation(query: String, onResult: (UiResource<Array<PlaceInfo>>) -> Unit): Unit {
        onResult(UiResource.Loading)
        if (!this.networkChecker.hasInternetConnection()) {
            onResult(UiResource.Error(MainViewModel.ERR_NO_NET))
            return ()
        }
        let single = this.repository.searchLocation(query)
        let response = single.get()
        onResult(UiResource.Success(response))
    }

    public func changeTemperatureUnit(unit: TemperatureUnit): Unit {
        let oldUnit = this.repository.getTemperatureUnit()
        this.repository.setTemperatureUnit(unit)
        match (this.daysForecastState) {
            case Success(d) =>
                let nd = this.transformDaysTemperatureUnit(d, oldUnit, unit)
                this.notifyDays(UiResource.Success(nd))
            case _ => ()
        }
    }

    public func changeSpeedUnit(unit: SpeedUnit): Unit {
        let oldUnit = this.repository.getSpeedUnit()
        this.repository.setSpeedUnit(unit)
        match (this.daysForecastState) {
            case Success(d) =>
                let nd = this.transformDaysSpeedUnit(d, oldUnit, unit)
                this.notifyDays(UiResource.Success(nd))
            case _ => ()
        }
    }

    public func changePressureUnit(unit: PressureUnit): Unit {
        let oldUnit = this.repository.getPressureUnit()
        this.repository.setPressureUnit(unit)
        match (this.daysForecastState) {
            case Success(d) =>
                let nd = this.transformDaysPressureUnit(d, oldUnit, unit)
                this.notifyDays(UiResource.Success(nd))
            case _ => ()
        }
    }

    private func safeFetchWeatherForecast(latitude: Float64, longitude: Float64): Unit {
        this.notifyDays(UiResource.Loading)
        if (!this.networkChecker.hasInternetConnection()) {
            this.notifyDays(UiResource.Error(MainViewModel.ERR_NO_NET))
            return ()
        }
        let single = this.repository.fetchWeatherForecast(latitude, longitude)
        let forecast = single.get()
        let formatted = this.formatDaysForecast(forecast)
        this.notifyDays(UiResource.Success(formatted))
    }

    private func safeFetchNearestPlaceInfo(latitude: Float64, longitude: Float64): Unit {
        this.notifyPlace(UiResource.Loading)
        if (!this.networkChecker.hasInternetConnection()) {
            this.notifyPlace(UiResource.Error(MainViewModel.ERR_NO_NET))
            return ()
        }
        let single = this.repository.fetchNearestPlaceInfo(latitude, longitude)
        let place = single.get()
        this.notifyPlace(UiResource.Success(placeToponymFromModel(place)))
    }

    private func formatDaysForecast(orig: DaysForecastProto): DaysForecastProto {
        let target = this.repository.getPressureUnit()
        let day = orig.today
        let p = day.pressure
        let newCur = roundToInt64(convertPressure(Float64(p.current), p.unit, target))
        let prevAbs = Float64(p.current - p.diff)
        let newPrev = roundToInt64(convertPressure(prevAbs, p.unit, target))
        let newDiff = newCur - newPrev
        let newPress = PressureProto(newCur, abs64(newDiff), p.indicatorIcon, target)
        let newDay = DayForecastProto(
            day.currentTemp,
            day.apparentTemp,
            day.dayHighTemp,
            day.nightLowTemp,
            day.weatherIconName,
            day.weatherResourceName,
            day.lastUpdateTime,
            day.sunrise,
            day.sunset,
            day.wind,
            day.precipChance,
            newPress,
            day.uvIndex,
            day.hourlyTemps,
            day.hourlyPrecip
        )
        DaysForecastProto(newDay, orig.dailyOutlook, orig.rawJson)
    }

    private func transformDaysTemperatureUnit(
        d: DaysForecastProto,
        from: TemperatureUnit,
        to: TemperatureUnit
    ): DaysForecastProto {
        let day = d.today
        let newDay = DayForecastProto(
            this.transformTemperatureProto(day.currentTemp, from, to),
            this.transformTemperatureProto(day.apparentTemp, from, to),
            this.transformTemperatureProto(day.dayHighTemp, from, to),
            this.transformTemperatureProto(day.nightLowTemp, from, to),
            day.weatherIconName,
            day.weatherResourceName,
            day.lastUpdateTime,
            day.sunrise,
            day.sunset,
            day.wind,
            day.precipChance,
            day.pressure,
            day.uvIndex,
            this.convertHourlyItems(day.hourlyTemps, from, to),
            day.hourlyPrecip
        )
        let newOutlook = this.convertDailyOutlook(d.dailyOutlook, from, to)
        DaysForecastProto(newDay, newOutlook, d.rawJson)
    }

    private func transformTemperatureProto(t: TemperatureProto, from: TemperatureUnit, to: TemperatureUnit): TemperatureProto {
        let newT = roundToInt64(convertTemperature(Float64(t.temperature), from, to))
        TemperatureProto(t.time, newT, t.weatherIconName, to)
    }

    private func convertHourlyItems(
        items: Array<TemperatureItem>,
        from: TemperatureUnit,
        to: TemperatureUnit
    ): Array<TemperatureItem> {
        let list = ArrayList<TemperatureItem>()
        var i: Int64 = 0
        while (i < items.size) {
            let it = items[i]
            let nt = roundToInt64(convertTemperature(Float64(it.temperature), from, to))
            list.add(TemperatureItem(it.time, nt, it.weatherIconName))
            i += 1
        }
        list.toArray()
    }

    private func convertDailyOutlook(
        arr: Array<DailyOutlook>,
        from: TemperatureUnit,
        to: TemperatureUnit
    ): Array<DailyOutlook> {
        let list = ArrayList<DailyOutlook>()
        var i: Int64 = 0
        while (i < arr.size) {
            let o = arr[i]
            let mx = roundToInt64(convertTemperature(Float64(o.maxTemp), from, to))
            let mn = roundToInt64(convertTemperature(Float64(o.minTemp), from, to))
            list.add(DailyOutlook(o.dateIso, mx, mn))
            i += 1
        }
        list.toArray()
    }

    private func transformDaysSpeedUnit(d: DaysForecastProto, from: SpeedUnit, to: SpeedUnit): DaysForecastProto {
        let day = d.today
        let w = day.wind
        let cur = roundToInt64(convertSpeed(Float64(w.current), from, to))
        let prevAbs = Float64(w.current - w.diff)
        let newPrev = roundToInt64(convertSpeed(prevAbs, from, to))
        let diff = cur - newPrev
        let newWind = WindSpeedProto(cur, abs64(diff), w.indicatorIcon, to)
        let newDay = DayForecastProto(
            day.currentTemp,
            day.apparentTemp,
            day.dayHighTemp,
            day.nightLowTemp,
            day.weatherIconName,
            day.weatherResourceName,
            day.lastUpdateTime,
            day.sunrise,
            day.sunset,
            newWind,
            day.precipChance,
            day.pressure,
            day.uvIndex,
            day.hourlyTemps,
            day.hourlyPrecip
        )
        DaysForecastProto(newDay, d.dailyOutlook, d.rawJson)
    }

    private func transformDaysPressureUnit(d: DaysForecastProto, from: PressureUnit, to: PressureUnit): DaysForecastProto {
        let day = d.today
        let p = day.pressure
        let cur = roundToInt64(convertPressure(Float64(p.current), from, to))
        let prevAbs = Float64(p.current - p.diff)
        let newPrev = roundToInt64(convertPressure(prevAbs, from, to))
        let diff = cur - newPrev
        let newPress = PressureProto(cur, abs64(diff), p.indicatorIcon, to)
        let newDay = DayForecastProto(
            day.currentTemp,
            day.apparentTemp,
            day.dayHighTemp,
            day.nightLowTemp,
            day.weatherIconName,
            day.weatherResourceName,
            day.lastUpdateTime,
            day.sunrise,
            day.sunset,
            day.wind,
            day.precipChance,
            newPress,
            day.uvIndex,
            day.hourlyTemps,
            day.hourlyPrecip
        )
        DaysForecastProto(newDay, d.dailyOutlook, d.rawJson)
    }
}

private func abs64(x: Int64): Int64 {
    if (x < 0) {
        -x
    } else {
        x
    }
}

private func roundToInt64(v: Float64): Int64 {
    Int64(v + (if (v >= 0.0) {
        0.5
    } else {
        -0.5
    }))
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

/** `PlaceInfo` 主构造字段在包外不可见，与 `MainFragment` 一致从 `toString()` 取地名。 */
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

private func placeToponymFromModel(p: PlaceInfo): String {
    let s = p.toString()
    extractBetweenPlaceInfo(s, "toponymName", ", countryName=")
}
