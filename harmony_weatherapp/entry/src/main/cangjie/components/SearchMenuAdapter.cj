package ohos_app_cangjie_entry.components

import ohos_app_cangjie_entry.models.PlaceInfo
import kit.ArkUI.*
import ohos.arkui.state_macro_manage.*
import std.collection.ArrayList

private func substringBytes(s: String, start: Int64, end: Int64): String {
    if (start < 0 || end > s.size || start >= end) {
        return ""
    }
    return s[start..end]
}

private func extractBetweenPlaceInfo(s: String, startKey: String, endMarker: String): String {
    let needle = startKey + "="
    match (s.indexOf(needle)) {
        case Some(i) =>
            let from = i + needle.size
            match (s.indexOf(endMarker, from)) {
                case Some(j) => substringBytes(s, from, j)
                case None => ""
            }
        case None => ""
    }
}

/**
 * 展示 toponymName、adminName1、countryName（与 models/PlaceInfo.cj 的 toString 格式一致；包外不依赖字段可见性）。
 */
private func placeDisplayLine(p: PlaceInfo): String {
    let s = p.toString()
    let t = extractBetweenPlaceInfo(s, "toponymName", ", countryName=")
    let a = extractBetweenPlaceInfo(s, "adminName1", ", latitude=")
    let c = extractBetweenPlaceInfo(s, "countryName", ", countryCode=")
    let parts = ArrayList<String>()
    if (!t.isEmpty()) {
        parts.add(t)
    }
    if (!a.isEmpty()) {
        parts.add(a)
    }
    if (!c.isEmpty()) {
        parts.add(c)
    }
    if (parts.isEmpty()) {
        return ""
    }
    var out = parts[0]
    var i: Int64 = 1
    while (i < parts.size) {
        out = out + ", " + parts[i]
        i += 1
    }
    return out
}

/**
 * 对应 Android `SearchMenuAdapter`：`RecyclerView` 列表在鸿蒙侧用 `List` + `ListItem` 呈现 `PlaceInfo`。
 */
@Component
public class SearchMenuAdapter {
    @Prop
    var places: Array<PlaceInfo>
    @Prop
    var onItemClick: (Int64) -> Unit

    public func build() {
        List(space: 8) {
            ForEach(
                this.places,
                itemGeneratorFunc: {
                    item: PlaceInfo, idx: Int64 =>
                    ListItem() {
                        Row(space: 8) {
                            Text(placeDisplayLine(item))
                                .fontSize(16)
                                .textAlign(TextAlign.Start)
                                .layoutWeight(1)
                        }
                        .width(100.percent)
                        .padding(12)
                        .onClick({
                            _ =>
                            this.onItemClick(idx)
                        })
                    }
                },
                keyGeneratorFunc: {
                    _: PlaceInfo, idx: Int64 => idx.toString()
                }
            )
        }
        .width(100.percent)
    }
}
