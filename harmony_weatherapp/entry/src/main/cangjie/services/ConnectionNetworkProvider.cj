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
    private static let INTERNET_PROBE_HOST: String = "api.open-meteo.com"

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
            if (e.code == 201) {
                // 某些设备上 NetworkKit 的连接状态查询会因权限实现差异持续返回 201。
                // 这里改为放行真实 HTTP 请求，由后续请求结果决定是否真正离线。
                Hilog.info(1, ConnectionNetworkProvider.TAG, "hasInternetConnection unavailable, allow real request fallback: ${e.code} ${e.message}")
                return true
            }
            Hilog.error(1, ConnectionNetworkProvider.TAG, "hasInternetConnection: ${e.code} ${e.message}")
            return this.probeInternetByDns()
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

    private func probeInternetByDns(): Bool {
        try {
            let addresses = getAddressesByName(ConnectionNetworkProvider.INTERNET_PROBE_HOST)
            if (addresses.size > 0) {
                Hilog.info(1, ConnectionNetworkProvider.TAG, "fallback DNS probe ok")
                return true
            }
        } catch (e: BusinessException) {
            if (e.code == 201) {
                Hilog.info(1, ConnectionNetworkProvider.TAG, "probeInternetByDns unavailable, allow real request fallback: ${e.code} ${e.message}")
                return true
            }
            Hilog.error(1, ConnectionNetworkProvider.TAG, "probeInternetByDns: ${e.code} ${e.message}")
        }
        return false
    }
}
