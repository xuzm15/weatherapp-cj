# open_meteo_client

## 实现要点

- **位置**：`<target_cangjie_root>/services/WeatherClient.cj` 中的 `OpenMeteoWeatherClient`（本 feature 未新增 `OpenMeteoClientService.cj`，与现有工程结构一致）。
- **请求 URL**：对齐 Android `OpenMeteoClient` 的查询维度：`past_days=6`、`forecast_days=10`、`timezone=auto`，并请求 `current`、`minutely_15`、`hourly`（含 `weather_code`、`apparent_temperature`、`precipitation_probability`、`uv_index`、`pressure_msl`、`is_day`）、`daily`（含 `sunrise`、`sunset`）。
- **解析**：
  - 优先用 `minutely_15` 数组对齐 Android 对「当前」温度、体感、风速、天气码的取值；缺省回退到 `current`。
  - 用 `current.time`（或回退到 `hourly.time` 中点）在 `hourly.time` 中定位 `hourIdx`，用于气压（`pressure_msl`）、降水概率、UV、`is_day` 及 24 小时预报窗口。
  - 风速/气压/降水概率的**变化箭头**：与 Android 一致，取当前值与约 24 小时前（`hourIdx-24` / `minIdx-24`）的差，符号交给 `ChangeIndicator.getIndicatorIcon`，绝对值写入 proto 的 diff 字段。
  - 昼夜高低温：在 hourly 上按 Android 思路用 `is_day` + 温度扫描；若无法得到昼夜分段则回退到 `daily` 中对应日期的 `temperature_2m_max/min`。
  - 今日 `uvIndex`：来自 hourly `uv_index`。
  - 24 小时逐时气温：从 `hourIdx` 起取 24 点，每小时天气码映射独立图标；逐时降水概率来自 `precipitation_probability`。
  - 多日摘要：`dailyOutlook` 从「今日」日索引起最多 7 天的 `time` + 高低温。
- **数据模型**：`DaysForecastProto` / `DayForecastProto` 等仍在 `models/WeatherForecastProto.cj`，未改结构。

## 已知限制

- 未实现 Android flatbuffers SDK 解析；采用官方 JSON API，语义对齐字段选择与索引策略。
- `SunriseSunsetProto` 的 `hourDiff`/`minuteDiff`/`isFuture` 未做完整日历运算，仅展示当日 `daily` 日出日落时间的 HH:mm。

## MCP

- 已调用 cangjie-kb：`search_cangjie_knowledge_base`，查询词 `String indexOf substring slice parse`，结果摘要：String 文档与 `indexOf`/切片相关说明。
