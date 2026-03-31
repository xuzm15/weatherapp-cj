# main_activity（entry_wiring）

## 实现要点

- **MainAbility**（`main_ability.cj`）：在 `onWindowStageCreate` 中取主窗口，调用 `setWindowLayoutFullScreen(true)` 对应 Android `EdgeToEdge.enable`；`loadContent("MainPage")` 挂载主页面。
- **MainPage**（`pages/MainPage.cj`）：`MainPageViewModel` 承载主页面展示状态（与 Android `MainViewModel` 角色对应，未放入 `models/` 以免与既有分层冲突）；根 `Column` 使用 `padding(left/right/bottom)` 模拟 Java 侧对 `placeHolder` 的 window insets 避让；内层 `Column` 对应 `MainFragment` 内容区；标题 `Text` 的 `onClick` 中调用 `Hilog.info`（非空回调）。
- **IR 管线**：已尝试 `pipeline.convert`，因环境缺少 Python 模块 `yaml` 失败，按 LLM-only 对照 `MainActivity.java` 实现。

## 关键 API

- `WindowStage.getMainWindow()`、`Window.setWindowLayoutFullScreen(Bool)`
- `windowStage.loadContent("MainPage")` 与 `@Entry` 页面注册名一致

## 已知限制

- 未使用 `getWindowAvoidArea` 做动态 insets，当前为固定 padding；后续可接窗口避让区回调与状态栏属性。
- Feature JSON 中模板任务列出的 `features/MainActivity*.cj` 未创建；本迭代按任务说明在 `pages/MainPage.cj` + `main_ability.cj` 完成入口接线。
