# settings_fragment 开发笔记

## 实现类型

- `implementation_kind`: `entry_wiring`
- 设置 UI 以 `components/SettingsFragment.cj` 交付，由 `MainFragment` 在「设置」全屏叠层中装配与回调接线。

## 行为说明

- 对齐 Android `SettingsFragment` + `root_preferences.xml` 中的四个 `ListPreference`：语言（en/ru）、温度（celsius/fahrenheit）、风速（kmh/ms/mph）、气压（hpa/mmhg/inhg）。
- 展示名使用与 `arrays.xml` 一致的英文标签；`Select` 的当前值作为摘要。
- 选项变更后写入 `AppConfig.settingsPreferences`（键 `pref_language`、`pref_temperature_unit`、`pref_wind_speed_unit`、`pref_pressure_unit`），并调用 `onLanguageChange` 等回调。
- 宿主 `MainFragment`：语言切换时 `GeoLocale` 设为 `en-US` / `ru-RU`，并 `fetchNearestPlaceInfo` 刷新地点名称；其余单位变更 Toast 提示。

## 文件

- `<target_cangjie_root>/components/SettingsFragment.cj`：设置列表与持久化。
- `<target_cangjie_root>/components/MainFragment.cj`：设置叠层与回调。

## IR

- `conversion.mode`: `llm-only`；未使用 IR 管线（环境提示 yaml 不可用）。

## MCP

- 本会话未挂载 cangjie-kb MCP；实现参考 `syntax_error.md`、工程内 ArkUI 用法及 `reference` 中 `Select` 示例。

## 已知限制

- 鸿蒙侧未实现 Android `MainActivity.updateLocale()` 的完整系统语言切换，仅通过 `GeoNamesClient` 的 locale 影响地名语言。
- 天气主数值仍以 Open-Meteo 原始单位展示，单位偏好已持久化供后续格式化 Feature 使用。
