package ohos_app_cangjie_entry.models

/**
 * 数值变化方向，对应 Android ChangeIndicator 枚举；图标以资源名字符串表示（Harmony 侧按名加载）。
 */
public enum ChangeIndicator {
    | UP
    | DOWN
    | UNCHANGED

    /** 与 Android R.drawable.* 对应的资源名，供 Image 等组件使用。 */
    public func iconResourceName(): String {
        match (this) {
            case UP => "ic_arrow_upgrade"
            case DOWN => "ic_arrow_downgrade"
            case UNCHANGED => "ic_arrow_unchanged"
        }
    }

    /**
     * 根据差值符号选择图标资源名（与 Java getIndicatorValue 逻辑一致，返回类型为资源名而非整型 id）。
     */
    public static func getIndicatorIcon(value: Int64): String {
        if (value > 0) {
            return UP.iconResourceName()
        } else if (value < 0) {
            return DOWN.iconResourceName()
        } else {
            return UNCHANGED.iconResourceName()
        }
    }
}
