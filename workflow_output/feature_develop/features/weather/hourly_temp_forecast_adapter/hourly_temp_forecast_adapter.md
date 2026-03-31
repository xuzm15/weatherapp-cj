# Hourly Temp Forecast Adapter

## 实现概要

- **数据模型**（相对 `<target_cangjie_root>`）：`models/TemperatureItem.cj`  
  - `time`、`temperature`（`Int64`）、`weatherIconName`（资源路径或 URL 字符串）。  
  - 使用 `public var` + 显式 `init`，避免 `ForEach` 宏展开后无法读取 `let` 主构造字段。

- **UI 组件**：`components/HourlyTempForecastAdapter.cj`  
  - `@Prop items: Array<TemperatureItem>`。  
  - 水平 `List`（`listDirection(Axis.Horizontal)`）+ `ListItem`，每项 `Column`：时间、`Image`/`Blank`、温度（`°` 格式化）。  
  - `build()` 直接以 `List` 为根；未使用「`build()` 仅调用 `@Builder` 作为根」的写法（见 `syntax_error.md` 新增条目）。

## 与 Android 对应关系

- Android：`HourlyTempForecastAdapter` + `TemperatureProto`（time、temperature、weather icon id）。  
- 鸿蒙：`imgIdWeatherCode` 由上层映射为 `weatherIconName` 后传入；本组件只负责展示。

## 依赖与集成

- 当前未在 `MainPage`/`MainFragment` 中挂载；宿主在需要处 `import ohos_app_cangjie_entry.components.HourlyTempForecastAdapter` 并传入 `items` 即可。

## 已知限制

- 未内置天气码到资源名的映射（由业务层完成）。  
- cangjie-kb MCP 本会话不可用；实现依据 `syntax_error.md` 与同目录 `SearchMenuAdapter` 模式及参考文档。

## IR

- `conversion.mode`: `llm-only`，未跑 IR 管线。
