# Change Indicator

## 实现概要

- **类型**：`local_state`（纯符号与资源名映射，无网络）。
- **文件**：`<target_cangjie_root>/models/ChangeIndicator.cj`
- **package**：`ohos_app_cangjie_entry.models`（与 `models` 子目录一致，见 `syntax_error.md`）。

## 行为

对照 Android `ChangeIndicator`：

- 枚举：`UP`、`DOWN`、`UNCHANGED`。
- `iconResourceName()`：返回与 `R.drawable.ic_arrow_*` 对应的**资源名字符串**（Harmony 侧按名绑定 drawable，而非 Android 的整型 id）。
- `getIndicatorIcon(value: Int64): String`：`value > 0` → 上升图标名；`< 0` → 下降；`== 0` → 不变。与 Java `getIndicatorValue` 的分支逻辑一致，返回类型为资源名。

## 编译

- `IOS2CJ_WORKFLOW_CONFIG=<workflow.config> bash <core>/src/scripts/build.sh cangjie`：通过。

## 已知限制

- 未引入 UI；调用方在需要时自行将资源名解析为 `Resource`/`PixelMap` 等（与工程其余资源加载方式一致）。

## IR

- 本 feature 配置为 `llm-only`，未使用 IR 管线。
