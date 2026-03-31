# Feature app — 交付说明

## 实现概要

- **类型**: `entry_wiring`（应用入口与基础设施接线）。
- **Android 对照**: `App.java` 在 `Application.onCreate` 中初始化 `ProtoDataStoreRepository` 与 `settings.pb` 对应的 DataStore。
- **鸿蒙映射**: 使用 `kit.ArkData.Preferences` + `PreferencesOptions`，在 `UIAbility` 获得 `UIAbilityContext` 后惰性创建与 Android「仅首次 setDataStore」等价的单例。

## 关键文件（相对 `<target_cangjie_root>`）

| 文件 | 作用 |
|------|------|
| `foundation/AppConfig.cj` | 全局 `settingsPreferences`（`Option<Preferences>`）、`ensureSettingsStore(ctx)`、`onAbilityStageCreate()` |
| `ability_stage.cj` | `MyAbilityStage.onCreate` 中调用 `AppConfig.onAbilityStageCreate()`，标记进程/模块级启动 |
| `main_ability.cj` | `MainAbility.onCreate` 开头调用 `AppConfig.ensureSettingsStore(this.context)`，完成持久化存储初始化 |

## API 与查询来源

- **Preferences**: 参考仓库内 `src/reference/docs_cangjie/zh-cn/application-dev/database/cj-data-persistence-by-preferences.md` 与 `cj-apis-preferences.md`（`Preferences.getPreferences(UIAbilityContext, PreferencesOptions)`）。
- **cangjie-kb MCP**: 当前会话未挂载 cangjie-kb 工具，已以上述官方文档与 `syntax_error.md` 为准。

## 已知限制

- 鸿蒙侧为 KV 型 Preferences，与 Android Proto DataStore 二进制 schema 不兼容；后续若需结构化 proto，需在业务层自行序列化或使用其他存储方案。

## 验收

- `IOS2CJ_WORKFLOW_CONFIG=<workflow.config> bash <core.src_root>/scripts/build.sh cangjie` 已通过（本 Worker 执行）。
