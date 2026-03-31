package ohos_app_cangjie_entry.models

/**
 * 对齐 Android `ListPaddingDecoration`（RecyclerView ItemDecoration）的语义占位。
 * ArkUI `List` 使用 `space` 在相邻项之间插入统一间距，无需 ItemDecoration；
 * 本类保存设计稿中的 padding（vp）与方向，供 `List(space: this.getSpacingVp().vp, ...)` 等调用。
 */
public enum ListPaddingOrientation {
    | Horizontal
    | Vertical
}

public class ListPaddingDecoration {
    /** 项间 padding，单位 vp（对齐 Android dp 在鸿蒙侧用 vp 表达）。 */
    public var paddingVp: Float64
    public var orientation: ListPaddingOrientation

    public init(paddingVp!: Float64, orientation!: ListPaddingOrientation = Vertical) {
        this.paddingVp = paddingVp
        this.orientation = orientation
    }

    /** 供 `List(space: ...)` 使用的间距值（vp）。 */
    public func getSpacingVp(): Float64 {
        this.paddingVp
    }
}
