package ohos_app_cangjie_entry.foundation

import kit.ArkData.{ Preferences, PreferencesOptions }
import kit.AbilityKit.UIAbilityContext
import kit.PerformanceAnalysisKit.Hilog

/**
 * 应用级配置与持久化入口，对应 Android `App.onCreate` 中对
 * ProtoDataStoreRepository / settings.pb 的惰性初始化。
 * 鸿蒙侧使用 Preferences（用户首选项）承载同类设置持久化。
 */
public class AppConfig {
    /** 与 Android `settings.pb` 对应的存储名（首选项持久化文件名由系统管理）。 */
    public static let SETTINGS_STORE_NAME: String = "settings"

    public static var settingsPreferences: Option<Preferences> = None

    /** 在 AbilityStage 创建时调用（无 UIAbilityContext，不做 Preferences 初始化）。 */
    public static func onAbilityStageCreate(): Unit {
        Hilog.info(1, "AppConfig", "AbilityStage onCreate: app process bootstrap.")
    }

    /**
     * 在 UIAbility 获得有效 `context` 后调用，确保全局 Preferences 单例已创建。
     * 与 Java 侧「若 getDataStore() 为 null 则 setDataStore」语义一致。
     */
    public static func ensureSettingsStore(ctx: UIAbilityContext): Unit {
        match (settingsPreferences) {
            case Some(_) => ()
            case None =>
                let options = PreferencesOptions(SETTINGS_STORE_NAME)
                let prefs = Preferences.getPreferences(ctx, options)
                settingsPreferences = Some(prefs)
                Hilog.info(1, "AppConfig", "Settings preferences initialized (name=${SETTINGS_STORE_NAME}).")
        }
    }
}
