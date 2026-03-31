package ohos_app_cangjie_entry.services

import ohos_app_cangjie_entry.models.*

/**
 * 数据仓库层：组合 `LocationProvider`、`WeatherClient`、`GeoLocationClient` 与 `ProtoDataStoreRepository`。
 * 仅做代理转发，不包含额外业务逻辑（对齐 Android `WeatherForecastRepository`）。
 */
public class WeatherForecastRepository {
    private let locationProvider: LocationProvider
    private let weatherClient: WeatherClient
    private let geoLocationClient: GeoLocationClient

    public init(
        locationProvider: LocationProvider,
        weatherClient: WeatherClient,
        geoLocationClient: GeoLocationClient
    ) {
        this.locationProvider = locationProvider
        this.weatherClient = weatherClient
        this.geoLocationClient = geoLocationClient
    }

    public func fetchWeatherForecast(latitude: Float64, longitude: Float64): GeoSingle<DaysForecastProto> {
        this.weatherClient.fetchWeatherForecast(latitude, longitude)
    }

    public func getTemperatureUnit(): TemperatureUnit {
        this.weatherClient.getTemperatureUnit()
    }

    public func getSpeedUnit(): SpeedUnit {
        this.weatherClient.getSpeedUnit()
    }

    public func getPressureUnit(): PressureUnit {
        this.weatherClient.getPressureUnit()
    }

    public func setTemperatureUnit(unit: TemperatureUnit): Unit {
        this.weatherClient.setTemperatureUnit(unit)
    }

    public func setSpeedUnit(unit: SpeedUnit): Unit {
        this.weatherClient.setSpeedUnit(unit)
    }

    public func setPressureUnit(unit: PressureUnit): Unit {
        this.weatherClient.setPressureUnit(unit)
    }

    public func fetchNearestPlaceInfo(latitude: Float64, longitude: Float64): GeoSingle<PlaceInfo> {
        this.geoLocationClient.fetchNearestPlaceInfo(latitude, longitude)
    }

    public func searchLocation(query: String): GeoSingle<Array<PlaceInfo>> {
        this.geoLocationClient.searchLocation(query)
    }

    public func setLocale(locale: GeoLocale): Unit {
        this.geoLocationClient.setLocale(locale)
    }

    /** 设置 JSON 快照，对应 Android `saveDataStore(DataStoreProto)`。 */
    public func saveDataStore(snapshot: String): Unit {
        ProtoDataStoreRepository.INSTANCE.saveDataStoreProto(snapshot)
    }

    public func getSettings(): String {
        ProtoDataStoreRepository.INSTANCE.getSettings()
    }

    public func saveForecast(json: String): Unit {
        ProtoDataStoreRepository.INSTANCE.saveForecast(json)
    }

    public func saveLocationCoord(coord: LocationCoord): Unit {
        ProtoDataStoreRepository.INSTANCE.saveLocationCoord(coord)
    }

    /** 对齐 Android `getDaysForecastResponse()`：侧持久化的预报 JSON。 */
    public func getDaysForecastResponse(): String {
        ProtoDataStoreRepository.INSTANCE.getForecast()
    }

    public func getLocation(): LocationCoord {
        this.locationProvider.getLocation()
    }

    public func setLocation(location: LocationCoord): Unit {
        this.locationProvider.setLocation(location)
    }

    public func requestLocation(): LocationCoord {
        this.locationProvider.requestLocation()
    }

    public func requestLocationAsync(onComplete: (LocationCoord) -> Unit): Unit {
        this.locationProvider.requestLocationAsync(onComplete)
    }
}
