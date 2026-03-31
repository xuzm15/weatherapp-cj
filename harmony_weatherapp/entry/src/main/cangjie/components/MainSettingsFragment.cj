package ohos_app_cangjie_entry.components

import kit.ArkUI.*
import ohos.arkui.state_macro_manage.*
import std.sync.*

private func defaultVoid(): Unit {}

private func defaultString(_: String): Unit {}

/**
 * 对应 Android `MainSettingsFragment`：深色全屏容器，顶部 Toolbar（返回 + 「Settings」）+ 内嵌 `SettingsFragment`。
 * 返回时先向右滑出（slide right），再通过 `onBack` 通知宿主关闭叠层或出栈。
 */
@Component
public class MainSettingsFragment {
    @State
    var slideExitVp: Float64 = 0.0

    private var backTimer: Timer = Timer.once(Duration.Zero, { => () })

    public var onBack: () -> Unit = defaultVoid
    public var onLanguageChange: (String) -> Unit = defaultString
    public var onTemperatureChange: (String) -> Unit = defaultString
    public var onWindSpeedChange: (String) -> Unit = defaultString
    public var onPressureChange: (String) -> Unit = defaultString

    private func emitBack(): Unit {
        getUIContext().animateTo(AnimateParam(duration: 280, curve: Curve.EaseInOut), {
            =>
            this.slideExitVp = 360.0
        })
        this.backTimer.cancel()
        this.backTimer = Timer.once(280 * Duration.millisecond, {
            =>
            this.onBack()
        })
    }

    @Builder
    func uiToolbar(): Unit {
        Row(space: 12) {
            Text("←")
                .fontSize(24)
                .fontColor(0xFFFFFFFF)
                .fontWeight(FontWeight.Medium)
                .padding(4)
                .onClick({ _ =>
                    this.emitBack()
                })
            Text("Settings")
                .fontSize(22)
                .fontColor(0xFFFFFFFF)
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
        }
        .width(100.percent)
        .alignItems(VerticalAlign.Center)
        .padding(left: 8, right: 16, top: 12, bottom: 12)
    }

    @Builder
    func uiBody(): Unit {
        Column(space: 0) {
            SettingsFragment(
                showHeader: false,
                onLanguageChange: { v: String => this.onLanguageChange(v) },
                onTemperatureChange: { v: String => this.onTemperatureChange(v) },
                onWindSpeedChange: { v: String => this.onWindSpeedChange(v) },
                onPressureChange: { v: String => this.onPressureChange(v) }
            )
        }
        .layoutWeight(1)
        .width(100.percent)
        .backgroundColor(0xFFF5F5F5)
    }

    public func build() {
        Column(space: 0) {
            this.uiToolbar()
            this.uiBody()
        }
        .width(100.percent)
        .height(100.percent)
        .backgroundColor(0xFF000000)
        .translate(x: this.slideExitVp.vp, y: 0.0.vp)
    }
}
