package ohos_app_cangjie_entry.components

import kit.ArkUI.*
import kit.PerformanceAnalysisKit.Hilog
import ohos.arkui.state_macro_manage.Component
import ohos.arkui.state_macro_manage.State

private let CSV_TAG: String = "CustomSearchView"

private func defaultSubmitStub(q: String): Unit {
    let t = q.trimAscii()
    if (!t.isEmpty()) {
        Hilog.info(1, CSV_TAG, "submit query chars=${t.size}")
    }
}

private func defaultCloseStub(): Unit {
    Hilog.info(1, CSV_TAG, "close requested")
}

/**
 * 对应 Android `CustomSearchView`（继承 `SearchView`）：鸿蒙侧使用 ArkUI `Search` 实现，
 * 支持自定义容器背景与占位/前景色（类比 Java 中背景 drawable 与 `setColorFilter` 对图标的着色），
 * 并通过可替换回调承载「提交搜索 / 关闭」语义。
 */
@Component
public class CustomSearchView {
    @State
    var query: String = ""
    /** 可由宿主在构造后赋值，用于换肤 */
    public var placeholder: String = "搜索城市或地址"
    /** 搜索框区域背景色（对应块级背景） */
    public var fieldBackgroundColor: UInt32 = 0xFFF0F0F0
    /** 占位符颜色 */
    public var placeholderTint: UInt32 = 0xFF666666
    public var searchActionLabel: String = "搜索"

    let controller: SearchController = SearchController()

    /** 提交当前查询字符串；宿主页面可替换为 `performSearch` 等真实逻辑 */
    public var onSubmitQuery: (String) -> Unit = defaultSubmitStub
    /** 关闭时调用；宿主可在此收起浮层；默认仅清空输入并记日志 */
    public var onClose: () -> Unit = defaultCloseStub

    func build() {
        Row(space: 8) {
            Search(value: this.query, placeholder: this.placeholder, controller: this.controller)
                .layoutWeight(1)
                .backgroundColor(this.fieldBackgroundColor)
                .placeholderColor(this.placeholderTint)
                .borderRadius(8.vp)
                .onChange({ v: String =>
                    this.query = v
                    this.notifyQueryChanged(v)
                })
                .onSubmit({ v: String =>
                    this.query = v
                    this.emitSubmit()
                })
            Button(this.searchActionLabel)
                .onClick({ _ =>
                    this.emitSubmit()
                })
            Button("关闭")
                .onClick({ _ =>
                    this.emitClose()
                })
        }
        .width(100.percent)
    }

    private func notifyQueryChanged(v: String): Unit {
        Hilog.info(1, CSV_TAG, "query edit len=${v.size}")
    }

    private func emitSubmit(): Unit {
        let t = this.query.trimAscii()
        if (t.isEmpty()) {
            getUIContext().getPromptAction().showToast(ShowToastOptions(message: "请输入搜索内容"))
            return
        }
        this.onSubmitQuery(t)
    }

    private func emitClose(): Unit {
        this.query = ""
        this.onClose()
    }
}
