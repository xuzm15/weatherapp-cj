package ohos_app_cangjie_entry.services

import kit.NetworkKit.*
import kit.PerformanceAnalysisKit.Hilog
import ohos.business_exception.BusinessException

/**
 * 对齐 Android `com.wemaka.weatherapp.network.ConnectionNetworkProvider`：
 * 基于当前默认数据网络判断是否存在可用的互联网相关连接。
 * 使用 `kit.NetworkKit` 的 `getDefaultNet` / `getNetCapabilities`，等价于
 * ActiveNetwork + NetworkCapabilities（WiFi / 蜂窝 / 以太网 任一承载，或具备 INTERNET 能力）。
 */
public class ConnectionNetworkProvider <: NetworkChecker {
    private static let TAG: String = "ConnectionNetworkProvider"

    public init() {}

    public func hasInternetConnection(): Bool {
        try {
            let netHandle = getDefaultNet()
            if (netHandle.netId == 0) {
                return false
            }
            let caps = getNetCapabilities(netHandle)
            if (hasInternetCapability(caps)) {
                return true
            }
            if (hasKnownTransport(caps)) {
                return true
            }
            return false
        } catch (e: BusinessException) {
            Hilog.error(1, ConnectionNetworkProvider.TAG, "hasInternetConnection: ${e.code} ${e.message}")
            return false
        }
    }

    private func hasInternetCapability(caps: NetCapabilities): Bool {
        var i: Int64 = 0
        while (i < caps.networkCap.size) {
            match (caps.networkCap[i]) {
                case NetCapabilityInternet => return true
                case _ => ()
            }
            i += 1
        }
        return false
    }

    private func hasKnownTransport(caps: NetCapabilities): Bool {
        var j: Int64 = 0
        while (j < caps.bearerTypes.size) {
            match (caps.bearerTypes[j]) {
                case BearerWifi => return true
                case BearerCellular => return true
                case BearerEthernet => return true
                case _ => ()
            }
            j += 1
        }
        return false
    }
}
