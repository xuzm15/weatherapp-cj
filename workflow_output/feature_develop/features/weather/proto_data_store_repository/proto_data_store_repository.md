# proto_data_store_repository

## 实现概要

- **目标文件**（相对 `<target_cangjie_root>`）：`services/ProtoDataStoreRepository.cj`
- **实现类型**：`local_state` — 使用 `AppConfig.settingsPreferences`（与 `AppConfig.ensureSettingsStore` 初始化后的全局 `Preferences` 单例）持久化 JSON 字符串。
- **Android 对照**：`ProtoDataStoreRepository`（DataStore + Protobuf + RxJava）；鸿蒙侧无 DataStore/RxJava，采用同步 get/set + JSON。

## API 行为

| 能力 | 说明 |
|------|------|
| `INSTANCE` | 单例 `ProtoDataStoreRepository.INSTANCE` |
| `getDataStoreProto` / `saveDataStoreProto` | 完整快照键 `pdsr_datastore_proto_json`；若未写入完整快照，则根据 `getSettings`、`getForecast`、`getLocationCoord` 组装 JSON |
| `getSettings` / `saveSettings` | Settings 与 `SettingsFragment` 共用 `pref_language`、`pref_temperature_unit`、`pref_wind_speed_unit`、`pref_pressure_unit`；JSON 字段 `language`、`temperatureUnit`、`windSpeedUnit`、`pressureUnit` |
| `getForecast` / `saveForecast` | 键 `pdsr_forecast_json`（对齐多日预报等原始 JSON 持久化） |
| `getLocationCoord` / `saveLocationCoord` | 键 `pdsr_location_coord_json`，格式 `{"latitude":…,"longitude":…}` |

## 已知限制

- 未实现 `getFlowLocationCoord()`（RxJava Flow）；按需求仅同步接口。
- 未使用 Protobuf；`DataStoreSerializer` 保留供其他模块做字节流，本仓库直接存 UTF-8 字符串。

## 构建

- `IOS2CJ_WORKFLOW_CONFIG=<workflow.config> bash <core.src_root>/scripts/build.sh cangjie` — **pass**（2026-03-31）。

## MCP 说明

- 本会话未接入 cangjie-kb；实现依据 `syntax_error.md` 与工程内现有 `Preferences`/`SettingsFragment` 用法。
