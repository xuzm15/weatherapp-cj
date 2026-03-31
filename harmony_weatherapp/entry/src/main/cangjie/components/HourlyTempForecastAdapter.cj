package ohos_app_cangjie_entry.components

import ohos_app_cangjie_entry.models.TemperatureItem
import kit.ArkUI.*
import ohos.arkui.state_macro_manage.*

private func formatTemperatureDegrees(c: Int64): String {
    return c.toString() + "°"
}

/**
 * 对应 Android `HourlyTempForecastAdapter`：`RecyclerView` 水平列表在鸿蒙侧用 `List` + `ListItem` 呈现 `TemperatureItem`。
 * 子项 UI 在 `ForEach` 内联展开，避免嵌套 `@Builder` 将 `item` 包成 `ObservedProperty` 后无法访问 `let` 字段。
 */
@Component
public class HourlyTempForecastAdapter {
    @Prop
    var items: Array<TemperatureItem>

    public func build() {
        List(space: 12) {
            ForEach(
                this.items,
                itemGeneratorFunc: {
                    item: TemperatureItem, _: Int64 =>
                    ListItem() {
                        Column(space: 4) {
                            Text(item.time)
                                .fontSize(12)
                                .fontColor(0xFF666666)
                                .textAlign(TextAlign.Center)
                            if (!item.weatherIconName.isEmpty()) {
                                Image(item.weatherIconName)
                                    .width(36.vp)
                                    .height(36.vp)
                                    .objectFit(ImageFit.Contain)
                            } else {
                                Blank()
                                    .width(36.vp)
                                    .height(36.vp)
                            }
                            Text(formatTemperatureDegrees(item.temperature))
                                .fontSize(16)
                                .fontWeight(FontWeight.Medium)
                                .textAlign(TextAlign.Center)
                        }
                        .width(64.vp)
                        .padding(8)
                        .alignItems(HorizontalAlign.Center)
                    }
                },
                keyGeneratorFunc: {
                    _: TemperatureItem, idx: Int64 => idx.toString()
                }
            )
        }
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width(100.percent)
    }
}
