# main_settings_fragment 开发笔记

## 实现类型

- `implementation_kind`: **entry_wiring**
- 宿主：`MainFragment` 叠层中挂载 `MainSettingsFragment`，返回时调用 `closeSettingsWithMotion()`。

## IR / cangjie-kb

- **IR 管线**：环境缺少 yaml 依赖，未运行 `pipeline.convert`；按 **llm-only** 与 Android 源码实现。
- **cangjie-kb MCP**：当前会话未挂载 cangjie-kb；对照 `syntax_error.md` 与工程内 `MainFragment` / `SettingsFragment` 写法。

## 文件与职责

| 路径（相对 `<target_cangjie_root>`） | 说明 |
|-----------------------------------|------|
| `components/MainSettingsFragment.cj` | 顶部黑色工具栏 Row（← + Settings）；下方浅色区（`0xFFF5F5F5`）内嵌 `SettingsFragment(showHeader: false)`，保证列表文字对比度；`emitBack` 使用 `animateTo` 平移 + `Timer.once(280ms)` 后调用 `onBack`。 |
| `components/SettingsFragment.cj` | 新增 `showHeader`，避免与外层工具栏标题重复。 |
| `components/MainFragment.cj` | 设置叠层改为使用 `MainSettingsFragment`，`onBack` → `closeSettingsWithMotion()`。 |

## 与 Android 对齐

- Toolbar 标题「Settings」、返回、黑色背景、子 Fragment 为设置列表。
- 退出：`slideExitVp` 模拟 slide right，再通知宿主（对应 `popBackStack` 前对 `swipeRefresh` 的动画）。

## 已知限制

- **系统返回键**：叠层为 `@Component` 子树，未单独注册页面级 `onBackPress`；若需与 Android `OnBackPressedCallback` 一致，需在承载 `MainFragment` 的页面或 Ability 层统一拦截并调用同一 `onBack` 链。
- 返回按钮使用 `Text("←")`；工程未提供 `ic_arrow_direction_left` 媒体资源时可后续替换为 `Image` + `$r`。

## 编译

```bash
cd <output.repo_root>
IOS2CJ_WORKFLOW_CONFIG=<workflow.config> bash <core.src_root>/scripts/build.sh cangjie
```

本轮：`cjpm build success`，`parse_build_log.py --summary` 无错误。
