# network_checker

## 实现概要

- **目标**：对齐 Android `NetworkChecker.hasInternetConnection()`，在鸿蒙侧提供可注入的 `NetworkChecker` 接口与默认实现。
- **源码位置**（相对 `<target_cangjie_root>`）：`services/NetworkChecker.cj`
- **实现类型**：`implementation_kind = network`（使用系统网络连接能力，非 HTTP mock）。

## API 与调用链

- **接口**：`public interface NetworkChecker { func hasInternetConnection(): Bool }`
- **实现**：`NetworkCheckerImpl`，通过 `import kit.NetworkKit.*` 使用 connection 模块：
  - `getDefaultNet()` 取得默认数据网络句柄；
  - `getNetCapabilities(netHandle)` 读取 `NetCapabilities`；
  - 遍历 `networkCap`，若存在 `NetCapabilityInternet` 则返回 `true`。
- **异常**：`BusinessException`（如无默认网络、权限或服务异常）时记录 `Hilog.error` 并返回 `false`。

## 文档依据

- 当前会话未启用 cangjie-kb MCP；实现参考 pandora-core 内 OpenHarmony 仓颉文档：`src/reference/docs_cangjie/zh-cn/application-dev/reference/NetworkKit/cj-apis-net-connection.md`（`getDefaultNet`、`getNetCapabilities`、`NetCap`）。

## 已知限制

- 能力位 `NetCapabilityInternet` 表示网络提供者声明的 Internet 能力，与「已验证可访问外网」不同；更严格场景可结合 `NetCapabilityValidated` 或业务层探测。
- 运行期需 `ohos.permission.GET_NETWORK_INFO`（及文档所列相关权限）；若模块未声明权限，真机可能返回权限类错误，实现侧已降级为 `false`。

## 编译

- 已在 worktree 根执行：`IOS2CJ_WORKFLOW_CONFIG=<workflow.config> bash <core>/src/scripts/build.sh cangjie`，cjpm 构建通过。
