package ohos_app_cangjie_entry.services

import std.core.Option
import std.sync.Mutex

/**
 * 对齐 Android `DataModule`（Dagger `@Module` + `@Provides`）。
 * 鸿蒙无 DI 框架：以进程内 Service Locator + 惰性单例代替 `SingletonComponent`。
 */
public class DataModule {
    private static let lock: Mutex = Mutex()

    private static var weatherClientOpt: Option<OpenMeteoWeatherClient> = None
    private static var geoLocationClientOpt: Option<GeoNamesClient> = None
    private static var locationProviderOpt: Option<FusedLocationProviderService> = None
    private static var networkCheckerOpt: Option<ConnectionNetworkProvider> = None
    private static var repositoryOpt: Option<WeatherForecastRepository> = None

    /** 对应 `provideWeatherClient()` → `OpenMeteoClient`。 */
    public static func provideWeatherClient(): WeatherClient {
        lock.lock()
        let w = weatherClientLocked()
        lock.unlock()
        return w
    }

    /** 对应 `provideGeoLocationClient()` → `GeoNamesClient`。 */
    public static func provideGeoLocationClient(): GeoLocationClient {
        lock.lock()
        let g = geoLocationClientLocked()
        lock.unlock()
        return g
    }

    /** 对应 `provideLocationProvider()` → `FusedLocationProvider`。 */
    public static func provideLocationProvider(): LocationProvider {
        lock.lock()
        let p = locationProviderLocked()
        lock.unlock()
        return p
    }

    /** 对应 `provideNetworkChecker()` → `ConnectionNetworkProvider`。 */
    public static func provideNetworkChecker(): NetworkChecker {
        lock.lock()
        let n = networkCheckerLocked()
        lock.unlock()
        return n
    }

    /** 对应 `provideRepository(...)`。 */
    public static func provideRepository(): WeatherForecastRepository {
        lock.lock()
        let r = repositoryLocked()
        lock.unlock()
        return r
    }

    private static func weatherClientLocked(): OpenMeteoWeatherClient {
        match (weatherClientOpt) {
            case Some(w) => w
            case None =>
                let w = OpenMeteoWeatherClient()
                weatherClientOpt = Some(w)
                w
        }
    }

    private static func geoLocationClientLocked(): GeoNamesClient {
        match (geoLocationClientOpt) {
            case Some(g) => g
            case None =>
                let g = GeoNamesClient()
                geoLocationClientOpt = Some(g)
                g
        }
    }

    private static func locationProviderLocked(): FusedLocationProviderService {
        match (locationProviderOpt) {
            case Some(p) => p
            case None =>
                let p = FusedLocationProviderService()
                locationProviderOpt = Some(p)
                p
        }
    }

    private static func networkCheckerLocked(): ConnectionNetworkProvider {
        match (networkCheckerOpt) {
            case Some(n) => n
            case None =>
                let n = ConnectionNetworkProvider()
                networkCheckerOpt = Some(n)
                n
        }
    }

    private static func repositoryLocked(): WeatherForecastRepository {
        match (repositoryOpt) {
            case Some(r) => r
            case None =>
                let lp = locationProviderLocked()
                let wc = weatherClientLocked()
                let gc = geoLocationClientLocked()
                let r = WeatherForecastRepository(lp, wc, gc)
                repositoryOpt = Some(r)
                r
        }
    }
}
