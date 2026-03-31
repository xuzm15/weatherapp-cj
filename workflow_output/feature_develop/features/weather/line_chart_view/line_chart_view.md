# line_chart_view 开发笔记

## 目标

在鸿蒙侧替代 Android `LineChartView`（MPAndroidChart），用 ArkUI `Canvas` 自绘温度折线，并接入 Open-Meteo 小时温度数据。

## 实现要点

- **`components/LineChartViewComponent.cj`**：提供 `lineChartCanvasContext()`、`lineChartChartInstanceId`、`lineChartPaint`、`lineChartHandleTouchDown`；使用文件级单例 `LineChartCanvasCtx` 持有 `CanvasRenderingContext2D`（主界面仅一处图表）。
- **`components/MainFragment.cj`**：请求 URL 增加 `hourly=temperature_2m&forecast_hours=24`；`extractHourlyTemperatures` 解析 `hourly` 段中 `"temperature_2m":[` 数组；`buildForecastLabels` 生成 `+0h`… 标签；`@Builder lineChartSection()` 内声明 `Canvas` 并在 `onReady` / `onAreaChange` 中调用 `lineChartPaint`，`onTouch` 中选最近点并 Toast。
- **为何不用独立 `@Component` 子组件**：宏展开后 `LineChartViewComponent(dataPoints:labels:)` 与生成构造函数参数不一致（缺 parent / LocalStorage）；将 UI 树留在宿主 `@Builder` 中、逻辑放在同包函数中可稳定编译（已记入 `syntax_error.md`）。

## 已知限制

- 单例 Canvas 上下文仅适合单实例折线图；多图需改为按实例持有 context。
- 折线为分段直线，未做贝塞尔平滑（可后续扩展）。

## 编译

在 worktree 根目录：`IOS2CJ_WORKFLOW_CONFIG=<workflow.config> bash <core>/src/scripts/build.sh cangjie`（已通过）。
