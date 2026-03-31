# connection_network_provider

## 实现概要

- **目标文件**（相对 `<target_cangjie_root>`）：`services/ConnectionNetworkProvider.cj`
- **接口**：实现已有 `NetworkChecker`（定义于 `services/NetworkChecker.cj`），与 `NetworkCheckerImpl` 并列，语义对齐 Android `ConnectionNetworkProvider`。

## 行为说明

- 使用 `kit.NetworkKit`：`getDefaultNet()`、`getNetCapabilities(NetHandle)`。
- 无默认网络：`netId == 0` 时返回 `false`（与文档中「无默认网络」一致）。
- 与 Android 源逻辑对应：
  - 若能力集含 `NetCapabilityInternet` → `true`；
  - 否则若承载类型为 `BearerWifi` / `BearerCellular` / `BearerEthernet` 之一 → `true`；
  - 否则 `false`。
- 异常：`BusinessException` 时记录 `Hilog.error` 并返回 `false`。

## cangjie-kb 查询摘要

- 查询词：`NetworkKit getNetCapabilities NetBearType transport WiFi cellular`、`NetCapabilities bearerTypes networkBearType`。
- 摘要：默认网络通过 `getDefaultNet()`；`NetCapabilities` 含 `networkCap` 与 `bearerTypes`（`NetBearType` 含 `BearerWifi`、`BearerCellular`、`BearerEthernet`）；无网络时 `netId` 可为 0。

## 已知限制

- 未改现有 `NetworkCheckerImpl` 的调用方；新类供需要与 Android 同名语义对齐时显式构造 `ConnectionNetworkProvider()` 使用。

## 编译

- `IOS2CJ_WORKFLOW_CONFIG=<workflow.config> bash <core.src_root>/scripts/build.sh cangjie` — 通过。
