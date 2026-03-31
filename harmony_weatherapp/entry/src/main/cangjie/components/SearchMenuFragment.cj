package ohos_app_cangjie_entry.components

import ohos_app_cangjie_entry.models.PlaceInfo
import kit.ArkUI.*
import ohos.arkui.state_macro_manage.Component
import ohos.arkui.state_macro_manage.Prop

private func defaultOnSearch(_: String): Unit {}

private func defaultOnPlace(_: PlaceInfo): Unit {}

private func defaultDismiss(): Unit {}

/**
 * 对应 Android `SearchMenuFragment`（`BottomSheetDialogFragment`）：鸿蒙侧用全屏叠层 + 模糊背景 + 列表，
 * 搜索与选点由宿主通过回调注入（`GeoNamesClient.searchLocation` / `setLocation` + 拉天气等）。
 */
@Component
public class SearchMenuFragment {
    /** 是否展示全屏搜索面板；为 false 时叠层宽高为 0，避免挡住下层手势。 */
    @Prop
    var visible: Bool
    /** 由宿主在 `onSearch` 异步完成后更新。 */
    @Prop
    var searchResults: Array<PlaceInfo>

    public var onSearch: (String) -> Unit = defaultOnSearch
    public var onPlaceSelected: (PlaceInfo) -> Unit = defaultOnPlace
    public var onDismiss: () -> Unit = defaultDismiss

    private func overlayWidth(): Length {
        if (this.visible) {
            return 100.percent
        }
        return 0.percent
    }

    private func overlayHeight(): Length {
        if (this.visible) {
            return 100.percent
        }
        return 0.percent
    }

    private func emitQuery(q: String): Unit {
        this.onSearch(q)
    }

    private func emitPick(idx: Int64): Unit {
        if (idx >= 0 && idx < this.searchResults.size) {
            this.onPlaceSelected(this.searchResults[idx])
        }
    }

    public func build() {
        Stack(alignContent: Alignment.TopStart) {
            if (this.visible) {
                Column(space: 12) {
                    CustomSearchView(
                        placeholder: "搜索城市或地址",
                        onSubmitQuery: { q: String => this.emitQuery(q) },
                        onClose: { => this.onDismiss() }
                    )
                    Scroll() {
                        SearchMenuAdapter(places: this.searchResults, onItemClick: { idx: Int64 => this.emitPick(idx) })
                    }
                        .layoutWeight(1)
                        .width(100.percent)
                }
                    .width(100.percent)
                    .height(100.percent)
                    .padding(12)
                    .backgroundColor(0xE6FFFFFF)
            }
        }
            .width(this.overlayWidth())
            .height(this.overlayHeight())
    }
}
