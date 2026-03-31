# Weather Code（weather_code）

## 实现概要

- **文件**：`models/WeatherCode.cj`（相对 `<target_cangjie_root>`）。
- **来源**：对齐 Android `com.wemaka.weatherapp.util.WeatherCode`（WMO 代码、字符串资源名、昼夜 drawable 基名）。
- **实现类型**：`local_state` — 纯本地查表与二分查找，无网络。

## API

| 符号 | 说明 |
|------|------|
| `WeatherCodeEntry` | `code`、`description`（默认英文描述，与 Android `values/strings.xml` 一致）、`dayIcon` / `nightIcon`（drawable 资源名字符串） |
| `searchByCode(code)` | 二分查找，`Option<WeatherCodeEntry>` |
| `getResIdByCode(code)` | 对齐 Android `getResIdByCode`：返回 **字符串资源名**（如 `clear_sky`），供鸿蒙侧 `$r('app.string.xxx')` 绑定 |
| `getIconIdByCode(code, isDay)` | 对齐 Android `getIconIdByCode`：返回 **图标资源名**（与 Android `R.drawable` 基名一致，如 `ic_clear_day`） |

## 数据

- 表项共 **28** 条（与 Android 枚举一致），按 `code` 升序存储，与 Java 版 `searchWeatherCode` 二分逻辑一致。
- 未使用仓颉 `enum` 多参数变体，采用 `class` + 顶层数组以降低生成代码体积。

## 已知限制

- `description` 为内嵌英文文案；多语言应通过 `getResIdByCode` 取得 string 名后在资源中解析。
- 鸿蒙 `string.json` 若尚未包含上述 name，需在资源侧补齐后才能在 UI 中显示。

## MCP / IR

- 已用 cangjie-kb 检索 `Option`/`Some`/`None` 用法（摘要：`Option<T>` 含 `Some`/`None`，可用 `match`）。
- 本 feature 为 `implementation` / 非 UI，未跑 IR 管线。
