package ohos_app_cangjie_entry.services

import ohos_app_cangjie_entry.models.*

import kit.AbilityKit.*
import kit.LocationKit.*
import ohos.business_exception.BusinessException
import kit.PerformanceAnalysisKit.Hilog

/**
 * 融合定位：对应 Android FusedLocationProvider。
 * - 权限：ohos.permission.APPROXIMATELY_LOCATION（必选）/ ohos.permission.LOCATION（精确）
 * - 定位开关与 GNSS/网络策略通过 LocatingPriority 映射
 * - 失败时回退上次缓存，再回退默认坐标 (40.72, -74.00)
 */
public class FusedLocationProviderService <: LocationProviderService {
    public static let DEFAULT_LAT: Float64 = 40.72
    public static let DEFAULT_LON: Float64 = -74.00
    private static let TAG: String = "FusedLocationProvider"
    private static let LOC_TIMEOUT_MS: Int32 = 10000

    public init() {
        super()
    }

    private func defaultCoord(): LocationCoord {
        LocationCoord(latitude: FusedLocationProviderService.DEFAULT_LAT, longitude: FusedLocationProviderService.DEFAULT_LON)
    }

    /** 是否已授予模糊定位（对应 Android ACCESS_COARSE_LOCATION） */
    private func isApproximateLocationGranted(): Bool {
        try {
            let tokenID = BundleManager.getBundleInfoForSelf(BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).appInfo.accessTokenId
            let atManager = AbilityAccessCtrl.createAtManager()
            return atManager.checkAccessToken(tokenID, "ohos.permission.APPROXIMATELY_LOCATION") == GrantStatus.PermissionGranted
        } catch (e: Exception) {
            Hilog.error(1, FusedLocationProviderService.TAG, "check APPROXIMATELY_LOCATION failed: ${e.message}")
            return false
        }
    }

    /** 是否已授予精确定位（对应 Android ACCESS_FINE_LOCATION） */
    private func isPreciseLocationGranted(): Bool {
        try {
            let tokenID = BundleManager.getBundleInfoForSelf(BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).appInfo.accessTokenId
            let atManager = AbilityAccessCtrl.createAtManager()
            return atManager.checkAccessToken(tokenID, "ohos.permission.LOCATION") == GrantStatus.PermissionGranted
        } catch (e: Exception) {
            Hilog.error(1, FusedLocationProviderService.TAG, "check LOCATION failed: ${e.message}")
            return false
        }
    }

    /** 与 Android isProviderEnabled(GPS|NETWORK) 对应：系统定位总开关 */
    private func isLocationSubsystemAvailable(): Bool {
        try {
            return GeoLocationManager.isLocationEnabled()
        } catch (e: BusinessException) {
            Hilog.error(1, FusedLocationProviderService.TAG, "isLocationEnabled: ${e.message}")
            return false
        }
    }

    private func handleLocationKit(loc: Location): LocationCoord {
        let coord = LocationCoord(latitude: loc.latitude, longitude: loc.longitude)
        this.setLocation(coord)
        return coord
    }

    /** 按权限选择单次定位优先级：精确 -> 精度优先；仅模糊 -> 快速优先 */
    private func primaryLocatingPriority(): LocatingPriority {
        if (this.isPreciseLocationGranted()) {
            return LocatingPriority.PriorityAccuracy
        }
        return LocatingPriority.PriorityLocatingSpeed
    }

    private func fetchCurrentLocation(priority: LocatingPriority): LocationCoord {
        let request = SingleLocationRequest(priority, FusedLocationProviderService.LOC_TIMEOUT_MS)
        let loc = GeoLocationManager.getCurrentLocation(request)
        return this.handleLocationKit(loc)
    }

    /** 最后已知位置：优先缓存，否则默认坐标 */
    private func getLastKnownOrDefault(): LocationCoord {
        let cached = super.getLocation()
        if (cached.latitude != 0.0 || cached.longitude != 0.0) {
            return cached
        }
        let d = defaultCoord()
        this.setLocation(d)
        return d
    }

    public open func requestLocation(): LocationCoord {
        if (!this.isApproximateLocationGranted()) {
            Hilog.error(1, FusedLocationProviderService.TAG, "location permission not granted; keep default")
            let d = defaultCoord()
            this.setLocation(d)
            return d
        }

        if (!this.isLocationSubsystemAvailable()) {
            Hilog.error(1, FusedLocationProviderService.TAG, "location disabled; use last known")
            return this.getLastKnownOrDefault()
        }

        let primary = this.primaryLocatingPriority()
        let secondary =
            if (this.isPreciseLocationGranted()) {
                LocatingPriority.PriorityLocatingSpeed
            } else {
                LocatingPriority.PriorityAccuracy
            }

        try {
            return this.fetchCurrentLocation(primary)
        } catch (e: BusinessException) {
            Hilog.error(1, FusedLocationProviderService.TAG, "getCurrentLocation primary failed: code=${e.code} msg=${e.message}")
        }

        try {
            return this.fetchCurrentLocation(secondary)
        } catch (e: BusinessException) {
            Hilog.error(1, FusedLocationProviderService.TAG, "getCurrentLocation secondary failed: code=${e.code} msg=${e.message}")
        }

        Hilog.error(1, FusedLocationProviderService.TAG, "current location failed; fallback last known")
        return this.getLastKnownOrDefault()
    }

    public open func requestLocationAsync(onComplete: (LocationCoord) -> Unit): Unit {
        let coord = this.requestLocation()
        onComplete(coord)
    }
}
