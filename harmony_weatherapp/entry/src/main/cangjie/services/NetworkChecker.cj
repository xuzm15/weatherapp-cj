package ohos_app_cangjie_entry.services

import kit.NetworkKit.*
import kit.PerformanceAnalysisKit.Hilog
import ohos.business_exception.BusinessException

/**
 * 对齐 Android `com.wemaka.weatherapp.network.NetworkChecker`：是否具备网络连通能力。
 * 使用 `kit.NetworkKit`（ohos.net.connection）的 `getDefaultNet` / `getNetCapabilities` 查询
 * 默认数据网络是否声明 `NetCapabilityInternet`。
 */
public interface NetworkChecker {
    func hasInternetConnection(): Bool
}

public class NetworkCheckerImpl <: NetworkChecker {
    private static let TAG: String = "NetworkChecker"

    public init() {}

    public func hasInternetConnection(): Bool {
        try {
            let netHandle = getDefaultNet()
            let caps = getNetCapabilities(netHandle)
            var i: Int64 = 0
            while (i < caps.networkCap.size) {
                match (caps.networkCap[i]) {
                    case NetCapabilityInternet => return true
                    case _ => ()
                }
                i += 1
            }
            return false
        } catch (e: BusinessException) {
            Hilog.error(1, NetworkCheckerImpl.TAG, "hasInternetConnection: ${e.code} ${e.message}")
            return false
        }
    }
}
