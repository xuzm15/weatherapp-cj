# custom_search_view

## 实现概要

- **目标文件**（相对 `<target_cangjie_root>`）：`components/CustomSearchView.cj`
- **组件**：`CustomSearchView`，用 ArkUI `Search` + `SearchController` 实现，对应 Android `CustomSearchView`（继承 `SearchView`）的语义。
- **外观**：`fieldBackgroundColor`、`placeholderTint` 可配置，对应 Java 中块级背景与占位符着色；圆角 `borderRadius(8.vp)`。
- **行为**：
  - `onChange` 同步 `@State query` 并打 Hilog；
  - `onSubmit` / 搜索按钮：空输入时 `showToast` 提示，非空则调用 `onSubmitQuery`；
  - 「关闭」：清空 `query`，再调用 `onClose`。
- **回调字段**：`onSubmitQuery: (String) -> Unit`、`onClose: () -> Unit` 默认带日志桩，宿主（如 `MainFragment` 的搜索浮层）可替换为 `performSearch` / 收起浮层等真实逻辑。

## IR 管线

- 已尝试 `python -m pipeline.convert`：环境缺少 `yaml`（PyYAML），管线未产出骨架。
- 源为 Android Java，非 iOS ObjC/Swift，与管线设计目标不一致；本任务按 `conversion.mode: llm-only` 与源码手工实现。

## 已知限制

- 鸿蒙 `Search` 的公开链上未在本次工程中单独封装「图标 ColorFilter」；外观以容器背景 + `placeholderColor` 为主，与 Android 对 `ImageView` 逐图标着色略有差异。

## cangjie-kb MCP

- 当前会话未挂载 cangjie-kb MCP；API 参考 `pandora-core` 内 `arkui_cangjie_wrapper` 的 `view_search.cj` 与 `workflow_output/feature_develop/syntax_error.md`。
