# list_padding_decoration

## 实现概要

- **目标文件**（相对 `<target_cangjie_root>`）：`models/ListPaddingDecoration.cj`
- **实现类型**：`local_state`（数据模型与间距配置，无网络）

Android `ListPaddingDecoration` 通过 `ItemDecoration` 在除最后一项外的项上施加 padding（水平方向为 `right`，垂直为 `bottom`）。鸿蒙 ArkUI 的 `List` 使用 `space` 在**相邻项之间**插入统一间距，语义接近「项间距」，无需 `ItemDecoration`。

## 仓颉侧设计

- `ListPaddingOrientation`：`Horizontal` / `Vertical`，对齐 Android 枚举，便于调用方按原业务分支传参。
- `ListPaddingDecoration`：持有 `paddingVp`（vp）与 `orientation`；`getSpacingVp()` 返回用于 `List(space: ...)` 的间距值（vp）。

## 使用方式

在 `List` 上设置：

```text
List(space: decoration.getSpacingVp().vp) { ... }
```

## 已知限制

- `List.space` 为项间统一间距，无法逐「最后一项」去掉外侧间距；若需与 Android 最后一项零外边距完全一致，需在最后一项 `ListItem` 上单独用 `padding` / 布局补偿（本兼容层不封装该逻辑）。

## 其它

- **IR 管线**：本任务为 `conversion.mode: llm-only`，且用户指定 IR 不可用，未运行 IR 转换。
- **cangjie-kb**：已检索「List 列表」相关文档，确认以 `List` + 布局能力实现列表；间距由调用方通过 `space` 传入。
