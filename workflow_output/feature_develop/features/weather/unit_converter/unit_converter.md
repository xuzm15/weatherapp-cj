# Unit Converter（unit_converter）

## 实现概要

在 `<target_cangjie_root>/models/UnitConverter.cj` 中实现纯计算型单位转换，无 UI、无网络依赖，对齐 Android `UnitConverter.java` 的核心能力。

## 类型与 API

- **枚举**
  - `TemperatureUnit`：`Celsius`、`Fahrenheit`
  - `SpeedUnit`：`MS`、`KMH`、`MPH`
  - `PressureUnit`：`HPA`、`MMHG`、`INHG`

- **顶层函数**
  - `convertTemperature(temp, fromUnit, toUnit)`：摄氏 ↔ 华氏
  - `convertSpeed(speed, fromUnit, toUnit)`：先归一化到 m/s 再换算
  - `convertPressure(pressure, fromUnit, toUnit)`：先归一化到 hPa（1013.25 hPa = 760 mmHg = 29.9213 inHg）再换算

## 编译

在 output worktree 根目录执行：

`IOS2CJ_WORKFLOW_CONFIG=<workflow.config> bash <core.src_root>/scripts/build.sh cangjie`

本轮：`cjpm build` 通过。

## 已知限制

- 未提供 Android 侧若存在的四舍五入策略；调用方按需对展示值格式化。
- cangjie-kb MCP 当前环境不可用；实现依据 `syntax_error.md` 子包命名规则与参考工程中的枚举、match 写法。

## 集成

上层展示或设置模块可 `import ohos_app_cangjie_entry.models.*` 后调用上述函数。
