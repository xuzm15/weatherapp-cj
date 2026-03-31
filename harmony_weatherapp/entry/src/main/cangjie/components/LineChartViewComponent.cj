package ohos_app_cangjie_entry.components

import kit.ArkUI.*
import kit.PerformanceAnalysisKit.Hilog
import ohos.arkui.component.common.TouchType

private let LCV_TAG: String = "LineChartView"

/** 避免在 @Component 中持有 CanvasRenderingContext2D；主界面仅一处折线图时使用单例。 */
private class LineChartCanvasCtx {
    var settings: RenderingContextSettings = RenderingContextSettings(antialias: true)
    var context: CanvasRenderingContext2D
    var selectedIndex: Int64 = -1

    public init() {
        this.context = CanvasRenderingContext2D(this.settings)
    }
}

private var lineChartSharedCtx: LineChartCanvasCtx = LineChartCanvasCtx()

private let LINE_COLOR: UInt32 = 0xFF2196F3
private let GRID_COLOR: UInt32 = 0x22000000
private let AXIS_TEXT_COLOR: UInt32 = 0xFF666666

public func lineChartCanvasContext(): CanvasRenderingContext2D {
    return lineChartSharedCtx.context
}

public func lineChartChartInstanceId(dataPoints: Array<Float64>): String {
    var s: String = "${dataPoints.size}_"
    var i: Int64 = 0
    let cap: Int64 = if (dataPoints.size < 8) {
        dataPoints.size
    } else {
        8
    }
    while (i < cap) {
        s = s + "${dataPoints[i]},"
        i += 1
    }
    return s
}

private func computeYRange(dataPoints: Array<Float64>): (Float64, Float64) {
    let n: Int64 = dataPoints.size
    if (n == 0) {
        return (0.0, 1.0)
    }
    var lo: Float64 = dataPoints[0]
    var hi: Float64 = dataPoints[0]
    var i: Int64 = 1
    while (i < n) {
        let v: Float64 = dataPoints[i]
        if (v < lo) {
            lo = v
        }
        if (v > hi) {
            hi = v
        }
        i += 1
    }
    if (lo == hi) {
        lo = lo - 1.0
        hi = hi + 1.0
    }
    let span: Float64 = hi - lo
    let pad: Float64 = span * 0.08
    return (lo - pad, hi + pad)
}

private func plotMetrics(w: Float64, h: Float64): (Float64, Float64, Float64, Float64, Float64, Float64) {
    let padL: Float64 = 44.0
    let padR: Float64 = 12.0
    let padT: Float64 = 14.0
    let padB: Float64 = 36.0
    let plotW: Float64 = w - padL - padR
    let plotH: Float64 = h - padT - padB
    return (padL, padR, padT, padB, plotW, plotH)
}

private func xAt(i: Int64, n: Int64, padL: Float64, plotW: Float64): Float64 {
    if (n <= 1) {
        return padL + plotW * 0.5
    }
    return padL + plotW * (Float64(i) / Float64(n - 1))
}

private func yAt(v: Float64, ymin: Float64, ymax: Float64, padT: Float64, plotH: Float64): Float64 {
    let t: Float64 = (v - ymin) / (ymax - ymin)
    return padT + plotH * (1.0 - t)
}

/** 在 Canvas 上绘制折线（由宿主在 onReady / onAreaChange / 触摸后调用）。 */
public func lineChartPaint(dataPoints: Array<Float64>, labels: Array<String>, w: Float64, h: Float64): Unit {
    let ctx: CanvasRenderingContext2D = lineChartSharedCtx.context
    ctx.clearRect(0.0, 0.0, w, h)
    ctx.fillStyle = 0xFFF8F8F8
    ctx.fillRect(0.0, 0.0, w, h)

    let n: Int64 = dataPoints.size
    if (n == 0) {
        ctx.fillStyle = AXIS_TEXT_COLOR
        ctx.font = Some("14px sans-serif")
        ctx.fillText("暂无温度曲线数据", 12.0, h * 0.5)
        return
    }

    let (ymin, ymax) = computeYRange(dataPoints)
    let (padL, _, padT, _, plotW, plotH) = plotMetrics(w, h)

    ctx.strokeStyle = GRID_COLOR
    ctx.lineWidth = 1.0
    var gi: Int64 = 0
    while (gi < 4) {
        let gy: Float64 = padT + plotH * (Float64(gi) / 3.0)
        let gridPath: Path2D = Path2D()
        gridPath.moveTo(padL, gy)
        gridPath.lineTo(padL + plotW, gy)
        ctx.stroke(gridPath)
        gi += 1
    }

    ctx.fillStyle = AXIS_TEXT_COLOR
    ctx.font = Some("11px sans-serif")
    ctx.textAlign = Some("left")
    ctx.textBaseline = Some("middle")
    var li: Int64 = 0
    while (li < 4) {
        let gy: Float64 = padT + plotH * (Float64(li) / 3.0)
        let val: Float64 = ymax - (ymax - ymin) * (Float64(li) / 3.0)
        ctx.fillText("${val.toString()}", 4.0, gy)
        li += 1
    }

    let linePath: Path2D = Path2D()
    let x0: Float64 = xAt(0, n, padL, plotW)
    let y0: Float64 = yAt(dataPoints[0], ymin, ymax, padT, plotH)
    linePath.moveTo(x0, y0)
    var j: Int64 = 1
    while (j < n) {
        let xj: Float64 = xAt(j, n, padL, plotW)
        let yj: Float64 = yAt(dataPoints[j], ymin, ymax, padT, plotH)
        linePath.lineTo(xj, yj)
        j += 1
    }

    ctx.strokeStyle = LINE_COLOR
    ctx.lineWidth = 2.5
    ctx.stroke(linePath)

    ctx.fillStyle = AXIS_TEXT_COLOR
    ctx.font = Some("10px sans-serif")
    ctx.textAlign = Some("center")
    let labelCount: Int64 = if (labels.size < n) {
        labels.size
    } else {
        n
    }
    var k: Int64 = 0
    while (k < labelCount) {
        let lx: Float64 = xAt(k, n, padL, plotW)
        let lab: String = labels[k]
        ctx.fillText(lab, lx, h - 12.0)
        k += 1
    }

    let sel: Int64 = lineChartSharedCtx.selectedIndex
    if (sel >= 0 && sel < n) {
        let sx: Float64 = xAt(sel, n, padL, plotW)
        let sy: Float64 = yAt(dataPoints[sel], ymin, ymax, padT, plotH)
        let dotPath: Path2D = Path2D()
        dotPath.arc(sx, sy, 5.0, 0.0, 6.28318)
        ctx.fillStyle = LINE_COLOR
        ctx.fill(Some(dotPath))
        ctx.fillStyle = 0xFF222222
        ctx.font = Some("12px sans-serif")
        ctx.textAlign = Some("left")
        let tip: String = "${dataPoints[sel].toString()}°"
        ctx.fillText(tip, sx + 8.0, sy - 8.0)
    }
}

private func pickIndexFromLocalX(x: Float64, w: Float64, h: Float64, dataPoints: Array<Float64>): Int64 {
    let n: Int64 = dataPoints.size
    if (n <= 0) {
        return -1
    }
    let (padL, _, _, _, plotW, _) = plotMetrics(w, h)
    if (plotW <= 0.0) {
        return -1
    }
    if (n == 1) {
        return 0
    }
    var best: Int64 = 0
    var bestD: Float64 = 1.0e9
    var i: Int64 = 0
    while (i < n) {
        let xi: Float64 = xAt(i, n, padL, plotW)
        let d: Float64 = if (x > xi) {
            x - xi
        } else {
            xi - x
        }
        if (d < bestD) {
            bestD = d
            best = i
        }
        i += 1
    }
    return best
}

/** 触摸选点并重绘；toast 由宿主传入以避免在非组件上下文中取 UI 能力。 */
public func lineChartHandleTouchDown(
    x: Float64,
    dataPoints: Array<Float64>,
    labels: Array<String>,
    onToast: (String) -> Unit
): Unit {
    let ctx: CanvasRenderingContext2D = lineChartSharedCtx.context
    let w: Float64 = ctx.width
    let h: Float64 = ctx.height
    if (w <= 0.0 || h <= 0.0) {
        return
    }
    let idx: Int64 = pickIndexFromLocalX(x, w, h, dataPoints)
    lineChartSharedCtx.selectedIndex = idx
    if (idx >= 0 && idx < dataPoints.size) {
        onToast("温度 ${dataPoints[idx].toString()}°")
    }
    lineChartPaint(dataPoints, labels, w, h)
    Hilog.info(1, LCV_TAG, "selected idx=${idx}")
}
