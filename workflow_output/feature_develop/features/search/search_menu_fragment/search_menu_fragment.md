# search_menu_fragment 开发笔记

## 实现概要

- 新增 `components/SearchMenuFragment.cj`：全屏可收起叠层（`visible=false` 时宽高为 0，不拦截下层手势），组合 `CustomSearchView` + `SearchMenuAdapter`，通过 `onSearch` / `onPlaceSelected` / `onDismiss` 与宿主接线；`searchResults` 由宿主在 `GeoNamesClient.searchLocation` 完成后写入 `@Prop`。
- `MainFragment.cj`：用 `SearchMenuFragment` 替换原 `TextInput` + 字符串列表叠层；`runSearchMenuQuery` 调用 `geo.searchLocation`，`applyPlaceFromSearch` 解析坐标、`fused.setLocation`、`fetchOpenMeteo` 并关闭面板。
- `pages/MainPage.cj`：在入口页挂载 `MainFragment`（需 `import kit.ArkUI.*` 与 `ohos.arkui.state_management.*`，否则嵌套自定义 `@Component` 时宏展开缺少 `ReuseParams` / `LegalCallCheck` 等符号）。

## IR 管线

- 按任务要求尝试 IR 时环境缺少依赖（协议允许 llm-only）；本 feature `conversion.mode` 为 `llm-only`，未运行 `pipeline.convert`。

## cangjie-kb

- 当前会话未启用 cangjie-kb MCP；实现依据 `syntax_error.md` 与工程内 `CustomSearchView` / `SearchMenuAdapter` 既有写法。

## 平台差异

- 本工程 ArkUI 绑定中 `Column`/`Stack` 无 `backgroundBlurStyle`；面板使用半透明 `backgroundColor(0xE6FFFFFF)` 近似 Android `BlurView`，已记入 `syntax_error.md`。

## 验收

- 搜索提交 → GeoNames 查询 → 列表更新；选点 → 设置坐标并拉取天气 → Toast → 关闭面板。编译：`cjpm build success`（见本轮 `parse_build_log.py --summary`）。
