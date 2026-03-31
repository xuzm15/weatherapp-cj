# today_weather_fragment

## 实现概要

- **目标文件（相对 `<target_cangjie_root>`）**
  - `components/TodayWeatherFragment.cj`：今日天气主 UI（Scroll + Column）：当前温/体感/昼夜、四宫格（风速、降水、气压、UV）、日出日落、小时水平列表（`HourlyTempForecastAdapter`）、温度折线（`LineChartViewComponent` 中 `lineChartPaint` / 触摸选点）、逐时降水文本列表。
  - `components/MainFragment.cj`：嵌入 `TodayWeatherFragment`，外层 `Refresh` 调用 `MainViewModel.fetchCurrentWeatherAndPlace()`；顶部地名行订阅 `onPlaceNameChanged`。
  - `services/DataModule.cj`：新增 `provideMainViewModel()` 单例。
  - `services/MainViewModel.cj`：新增 `onForecastNotifyComplete`，在每次 `notifyDays` 后触发，用于结束下拉刷新动画。

## 数据流

- `MainViewModel.getDaysForecast()` / `onDaysForecastChanged` → `UiResource<DaysForecastProto>`。
- `TodayWeatherFragment.aboutToAppear` 链式注册 `onDaysForecastChanged`（保留先前回调），并立即 `applyForecastResource(getDaysForecast())`。
- 下拉刷新：`MainFragment` 将 `isRefreshing = true`，`notifyDays` 完成后 `onForecastNotifyComplete` 将 `isRefreshing = false`。

## IR / MCP

- **IR**：按任务说明未跑 IR 管线（Android 源在 `input/weatherapp/...`，与 worktree 配置一致时可再补跑）。
- **cangjie-kb**：已检索「Scroll Column Refresh ArkUI」类词条，确认 Scroll/Refresh 组合为常见布局模式。

## 已知限制

- Android 侧周温度折线采样逻辑与 MPAndroidChart 标记与鸿蒙侧「按小时温度点」展示在细节上不完全一致，但覆盖「折线图 + 触摸选点」行为。
- `SunriseSunsetProto` 若 `hourDiff`/`minuteDiff` 为 0，日出日落「相对当前」文案留空。

## 编译

- `IOS2CJ_WORKFLOW_CONFIG=<workflow.config> bash <core.src_root>/scripts/build.sh cangjie`：**通过**（`cjpm build success`）。
