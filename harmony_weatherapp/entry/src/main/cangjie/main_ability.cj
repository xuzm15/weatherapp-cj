package ohos_app_cangjie_entry

import ohos_app_cangjie_entry.foundation.AppConfig
import ohos_app_cangjie_entry.services.DataModule
import std.core.Option
import kit.PerformanceAnalysisKit.Hilog
import kit.AbilityKit.AbilityAccessCtrl
import kit.AbilityKit.LaunchParam
import kit.AbilityKit.LaunchReason
import kit.AbilityKit.PermissionRequestResult
import kit.AbilityKit.UIAbility
import kit.AbilityKit.Want
import kit.ArkUI.Window
import kit.ArkUI.WindowStage
import ohos.business_exception.BusinessException

class MainAbility <: UIAbility {
    private static let TAG: String = "MainAbility"

    public init() {
        super()
        registerSelf()
    }

    public override func onCreate(want: Want, launchParam: LaunchParam): Unit {
        Hilog.info(1, "Cangjie", "MainAbility OnCreated.${want.abilityName}")
        AppConfig.ensureSettingsStore(this.context)
        match (launchParam.launchReason) {
            case LaunchReason.StartAbility => Hilog.info(1, "Cangjie", "START_ABILITY")
            case _ => ()
        }
    }

    public override func onWindowStageCreate(windowStage: WindowStage): Unit {
        Hilog.info(1, "Cangjie", "MainAbility onWindowStageCreate.")
        let mainWindow: Window = windowStage.getMainWindow()
        mainWindow.setWindowLayoutFullScreen(true)
        windowStage.loadContent("MainPage")
        this.requestStartupPermissions()
    }

    private func requestStartupPermissions(): Unit {
        let atManager = AbilityAccessCtrl.createAtManager()
        let permissionList = ["ohos.permission.LOCATION", "ohos.permission.APPROXIMATELY_LOCATION"]
        let resultCallback = {
            errorCode: Option<BusinessException>, data: Option<PermissionRequestResult> =>
            match (errorCode) {
                case Some(e) =>
                    Hilog.error(1, MainAbility.TAG, "requestPermissionsFromUser failed: ${e.code} ${e.message}")
                case _ =>
                    match (data) {
                        case Some(value) =>
                            var grantedAny: Bool = false
                            var i: Int64 = 0
                            while (i < value.permissions.size) {
                                if (value.authResults[i] == 0) {
                                    grantedAny = true
                                    Hilog.info(1, MainAbility.TAG, "permission granted: ${value.permissions[i]}")
                                } else {
                                    Hilog.info(1, MainAbility.TAG, "permission denied: ${value.permissions[i]}")
                                }
                                i += 1
                            }
                            if (grantedAny) {
                                DataModule.provideMainViewModel().fetchCurrentWeatherAndPlace()
                            }
                        case None =>
                            Hilog.error(1, MainAbility.TAG, "requestPermissionsFromUser returned empty data")
                    }
            }
        }
        try {
            atManager.requestPermissionsFromUser(this.context, permissionList, resultCallback)
        } catch (e: BusinessException) {
            Hilog.error(1, MainAbility.TAG, "requestPermissionsFromUser threw: ${e.code} ${e.message}")
        }
    }
}
