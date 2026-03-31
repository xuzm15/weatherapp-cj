package ohos_app_cangjie_entry.pages

import ohos_app_cangjie_entry.components.MainFragment
import kit.ArkUI.*
import kit.PerformanceAnalysisKit.Hilog
import ohos.arkui.state_management.*
import ohos.arkui.state_macro_manage.Component
import ohos.arkui.state_macro_manage.Entry
import ohos.arkui.state_macro_manage.State

/**
 * 对应 Android MainViewModel：主页面状态容器（不放在 models 包下，仅服务本页接线）。
 */
public class MainPageViewModel {
    public var screenTitle: String = "Weather"
}

/**
 * 主页面：对应 `MainActivity` + `placeHolder` 上的 `MainFragment` 区域。
 * 根 Column 使用 padding 模拟 Android `OnApplyWindowInsetsListener` 对左/右/底的避让。
 */
@Entry
@Component
class MainPage {
    @State
    var model: MainPageViewModel = MainPageViewModel()

    func build() {
        Column {
            Text(this.model.screenTitle)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .onClick({
                    _ =>
                    Hilog.info(1, "MainPage", "Main page content tapped.")
                })
            MainFragment()
        }
        .width(100.percent)
        .height(100.percent)
        .padding(left: 16, right: 16, bottom: 24, top: 0)
    }
}
