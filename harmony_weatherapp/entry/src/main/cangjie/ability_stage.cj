package ohos_app_cangjie_entry

import ohos_app_cangjie_entry.foundation.AppConfig
import kit.AbilityKit.AbilityStage
import kit.PerformanceAnalysisKit.Hilog

class MyAbilityStage <: AbilityStage {
    public override func onCreate(): Unit {
        Hilog.info(1, "Cangjie", "MyAbilityStage onCreated.")
        AppConfig.onAbilityStageCreate()
    }
}
