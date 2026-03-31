# main_fragment

## 实现要点

- **目标文件**（相对 `<target_cangjie_root>`）：`components/MainFragment.cj`。
- **类型**：`entry_wiring`。在单文件内完成原 Android `MainFragment` 的主页职责：定位、逆地理、天气展示、下拉刷新、搜索（GeoNames）、设置入口动效、`aboutToDisappear` 时写入 `AppConfig.settingsPreferences` 快照。
- **天气数据**：Open-Meteo HTTP（`api.open-meteo.com`），与现有 `GeoNamesClient`、`FusedLocationProviderService` 组合成真实调用链，无占位 mock。
- **PlaceInfo**：`models/PlaceInfo.cj` 字段在 `components` 包外不可见，通过解析 `toString()` 输出拼接展示行并解析经纬度字符串（未改 models）。
- **权限**：`BundleManager` + `AbilityAccessCtrl.checkAccessToken`；未动态 `requestPermissionsFromUser`（需 `UIAbilityContext`，当前未在宿主暴露全局 context）。无权限时走服务层默认坐标并提示 Toast。
- **IR 管线**：已尝试运行 `pipeline.convert`，因环境缺少 Python `yaml` 模块失败，按 `llm-only` 与协议记录为跳过。

## MCP / 文档

- 本会话未启用 cangjie-kb MCP；依据 `syntax_error.md` 与仓颉官方文档中的 `Refresh`、`@Builder`、`getUIContext().animateTo` / `showToast` 等用法。

## 集成说明

- 宿主需在 `@Entry` 页面（如 `index.cj`）中挂载 `MainFragment()`；本任务按约束未修改 `index.cj`。

## 已知限制

- 设置页为占位文案，完整能力对齐 `MainSettingsFragment` 依赖后续 Feature。
- 动态定位权限弹窗需在 Ability 或全局 context 就绪后补充。
