package ohos_app_cangjie_entry.services

import ohos_app_cangjie_entry.models.*

import kit.LocationKit.*
import ohos.business_exception.BusinessException
import kit.PerformanceAnalysisKit.Hilog

public interface LocationProvider {
    func requestLocation(): LocationCoord
    func getLocation(): LocationCoord
    func setLocation(location: LocationCoord): Unit
    /** 异步回调：在取得同步结果后交付（与 Java 侧 Single 语义一致，便于 UI 线程解耦调用方） */
    func requestLocationAsync(onComplete: (LocationCoord) -> Unit): Unit
}

public open class LocationProviderService <: LocationProvider {
    private var cachedLocation: LocationCoord = LocationCoord()

    public init() {}

    public open func requestLocation(): LocationCoord {
        try {
            let enabled = GeoLocationManager.isLocationEnabled()
            if (!enabled) {
                Hilog.error(1, "LocationProvider", "Location service is disabled")
                return this.cachedLocation
            }
            let request = SingleLocationRequest(LocatingPriority.PriorityLocatingSpeed, 10000)
            let location = GeoLocationManager.getCurrentLocation(request)
            let coord = LocationCoord(latitude: location.latitude, longitude: location.longitude)
            this.cachedLocation = coord
            Hilog.info(1, "LocationProvider", "Location: (${coord.latitude}, ${coord.longitude})")
            return coord
        } catch (e: BusinessException) {
            Hilog.error(1, "LocationProvider", "Location failed: code=${e.code}, msg=${e.message}")
            return this.cachedLocation
        }
    }

    public func getLocation(): LocationCoord {
        return this.cachedLocation
    }

    public func setLocation(location: LocationCoord): Unit {
        this.cachedLocation = location
    }

    public open func requestLocationAsync(onComplete: (LocationCoord) -> Unit): Unit {
        onComplete(this.requestLocation())
    }
}
