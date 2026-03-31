package ohos_app_cangjie_entry.components

import ohos_app_cangjie_entry.models.*
import ohos_app_cangjie_entry.models.Resource as UiResource
import ohos_app_cangjie_entry.services.{DataModule, MainViewModel}
import kit.ArkUI.*
import ohos.arkui.state_macro_manage.*
import ohos.arkui.component.common.TouchType
import std.collection.ArrayList

private func formatTemperatureLine(t: TemperatureProto): String {
    let u = match (t.unit) {
        case Celsius => "°C"
        case Fahrenheit => "°F"
    }
    return "${t.temperature}${u}"
}

private func formatSpeedString(speed: Int64, unit: SpeedUnit): String {
    match (unit) {
        case MS => "${speed} m/s"
        case KMH => "${speed} km/h"
        case MPH => "${speed} mph"
    }
}

private func formatPressureString(pressure: Int64, unit: PressureUnit): String {
    match (unit) {
        case HPA => "${pressure} hPa"
        case MMHG => "${pressure} mmHg"
        case INHG => "${pressure} inHg"
    }
}

private func formatSunriseThrough(s: SunriseSunsetProto): String {
    if (s.hourDiff == 0 && s.minuteDiff == 0) {
        return ""
    }
    let n: Int64 = if (s.hourDiff == 0) {
        s.minuteDiff
    } else {
        s.hourDiff
    }
    if (s.isFuture) {
        if (s.hourDiff == 0) {
            return "约 ${n} 分钟后"
        }
        return "约 ${n} 小时后"
    }
    if (s.hourDiff == 0) {
        return "已过 ${n} 分钟"
    }
    return "已过 ${n} 小时"
}

private func hourlyItemsForAdapter(df: DayForecastProto): Array<TemperatureItem> {
    let src = df.hourlyTemps
    if (src.size == 0) {
        return Array<TemperatureItem>()
    }
    let list = ArrayList<TemperatureItem>()
    var i: Int64 = 0
    while (i < src.size) {
        let it = src[i]
        if (i == 0) {
            list.add(TemperatureItem("现在", it.temperature, it.weatherIconName))
        } else {
            list.add(TemperatureItem(it.time, it.temperature, it.weatherIconName))
        }
        i += 1
    }
    list.toArray()
}

private func hourlyPrecipFirstNow(items: Array<PrecipitationChanceProto>): Array<PrecipitationChanceProto> {
    if (items.size == 0) {
        return Array<PrecipitationChanceProto>()
    }
    let list = ArrayList<PrecipitationChanceProto>()
    var i: Int64 = 0
    while (i < items.size) {
        let it = items[i]
        if (i == 0) {
            list.add(PrecipitationChanceProto("现在", it.percent, it.diff, it.indicatorIcon))
        } else {
            list.add(it)
        }
        i += 1
    }
    list.toArray()
}

private func chartDataFromHourly(items: Array<TemperatureItem>): (Array<Float64>, Array<String>) {
    let tList = ArrayList<Float64>()
    let lList = ArrayList<String>()
    var i: Int64 = 0
    while (i < items.size) {
        let it = items[i]
        tList.add(Float64(it.temperature))
        lList.add(it.time)
        i += 1
    }
    (tList.toArray(), lList.toArray())
}

/**
 * 今日天气主内容区：对齐 Android `TodayWeatherFragment`，数据来自 `MainViewModel` 与 `DaysForecastProto`。
 */
@Component
public class TodayWeatherFragment {
    private let vm: MainViewModel = DataModule.provideMainViewModel()

    @State
    var mainTempLine: String = "--"
    @State
    var feelsLikeLine: String = ""
    @State
    var weatherDesc: String = ""
    @State
    var dayNightLine: String = ""
    @State
    var lastUpdateLine: String = ""
    @State
    var weatherIconName: String = ""
    @State
    var windText: String = ""
    @State
    var rainText: String = ""
    @State
    var pressureText: String = ""
    @State
    var uvText: String = ""
    @State
    var windDiffText: String = ""
    @State
    var rainDiffText: String = ""
    @State
    var pressureDiffText: String = ""
    @State
    var uvDiffText: String = ""
    @State
    var windIndIcon: String = ""
    @State
    var rainIndIcon: String = ""
    @State
    var pressureIndIcon: String = ""
    @State
    var uvIndIcon: String = ""
    @State
    var sunriseTime: String = ""
    @State
    var sunsetTime: String = ""
    @State
    var sunriseThrough: String = ""
    @State
    var sunsetThrough: String = ""
    @State
    var hourlyItems: Array<TemperatureItem> = Array<TemperatureItem>()
    @State
    var precipItems: Array<PrecipitationChanceProto> = Array<PrecipitationChanceProto>()
    @State
    var chartTemps: Array<Float64> = Array<Float64>()
    @State
    var chartLabels: Array<String> = Array<String>()
    @State
    var errorText: String = ""
    @State
    var showLoadingHint: Bool = true

    private func toast(msg: String): Unit {
        getUIContext().getPromptAction().showToast(ShowToastOptions(message: msg))
    }

    private func applyForecastResource(r: UiResource<DaysForecastProto>): Unit {
        match (r) {
            case Loading =>
                this.showLoadingHint = true
                this.errorText = ""
            case Error(msg) =>
                this.showLoadingHint = false
                this.errorText = msg
            case Success(data) =>
                this.showLoadingHint = false
                this.errorText = ""
                let df = data.today
                this.mainTempLine = formatTemperatureLine(df.currentTemp)
                this.feelsLikeLine = "体感 " + formatTemperatureLine(df.apparentTemp)
                this.weatherDesc = df.weatherResourceName
                if (this.weatherDesc.isEmpty()) {
                    this.weatherDesc = df.weatherIconName
                }
                this.weatherIconName = df.weatherIconName
                this.dayNightLine =
                    "白天 " + formatTemperatureLine(df.dayHighTemp) + "  ·  夜间 " + formatTemperatureLine(df.nightLowTemp)
                if (!df.lastUpdateTime.isEmpty()) {
                    this.lastUpdateLine = "更新 " + df.lastUpdateTime
                } else {
                    this.lastUpdateLine = ""
                }
                this.windText = formatSpeedString(df.wind.current, df.wind.unit)
                this.rainText = "${df.precipChance.percent}%"
                this.pressureText = formatPressureString(df.pressure.current, df.pressure.unit)
                this.uvText = "${df.uvIndex}"
                this.windDiffText = "${df.wind.diff}"
                this.rainDiffText = "${df.precipChance.diff}"
                this.pressureDiffText = "${df.pressure.diff}"
                this.uvDiffText = "—"
                this.windIndIcon = df.wind.indicatorIcon
                this.rainIndIcon = df.precipChance.indicatorIcon
                this.pressureIndIcon = df.pressure.indicatorIcon
                this.uvIndIcon = ChangeIndicator.getIndicatorIcon(0)
                this.sunriseTime = df.sunrise.time
                this.sunsetTime = df.sunset.time
                this.sunriseThrough = formatSunriseThrough(df.sunrise)
                this.sunsetThrough = formatSunriseThrough(df.sunset)
                let adapterHourly = hourlyItemsForAdapter(df)
                this.hourlyItems = adapterHourly
                this.precipItems = hourlyPrecipFirstNow(df.hourlyPrecip)
                let (temps, labels) = chartDataFromHourly(adapterHourly)
                this.chartTemps = temps
                this.chartLabels = labels
        }
    }

    protected override func aboutToAppear(): Unit {
        let prev = this.vm.onDaysForecastChanged
        this.vm.onDaysForecastChanged = { r: UiResource<DaysForecastProto> =>
            this.applyForecastResource(r)
            prev(r)
        }
        this.applyForecastResource(this.vm.getDaysForecast())
    }

    @Builder
    func lineChartBlock(): Unit {
        Stack {
            Canvas(lineChartCanvasContext())
                .width(100.percent)
                .height(180.0.vp)
                .backgroundColor(0xFFFFFFFF)
                .id(lineChartChartInstanceId(this.chartTemps))
                .onReady({
                    =>
                    let ctx: CanvasRenderingContext2D = lineChartCanvasContext()
                    lineChartPaint(this.chartTemps, this.chartLabels, ctx.width, ctx.height)
                })
                .onAreaChange({
                    _: Area, _: Area =>
                    let ctx: CanvasRenderingContext2D = lineChartCanvasContext()
                    lineChartPaint(this.chartTemps, this.chartLabels, ctx.width, ctx.height)
                })
                .onTouch({
                    evt: TouchEvent =>
                    if (evt.eventType == TouchType.Down && evt.changedTouches.size > 0) {
                        let x: Float64 = evt.changedTouches[0].x
                        lineChartHandleTouchDown(
                            x,
                            this.chartTemps,
                            this.chartLabels,
                            { m: String => this.toast(m) }
                        )
                    }
                })
        }
        .width(100.percent)
    }

    @Builder
    func precipSection(): Unit {
        if (this.precipItems.size > 0) {
            Text("降水概率（逐时）")
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .width(100.percent)
                .padding(left: 4, right: 4, top: 8, bottom: 4)
            Column(space: 6) {
                ForEach(
                    this.precipItems,
                    itemGeneratorFunc: {
                        p: PrecipitationChanceProto, _: Int64 =>
                        Row(space: 8) {
                            Text(p.time)
                                .fontSize(14)
                                .layoutWeight(1)
                            Text("${p.percent}%")
                                .fontSize(14)
                                .width(56.vp)
                                .textAlign(TextAlign.End)
                        }
                        .width(100.percent)
                        .padding(4)
                    },
                    keyGeneratorFunc: {
                        p: PrecipitationChanceProto, idx: Int64 => "${idx}_${p.time}"
                    }
                )
            }
            .width(100.percent)
        }
    }

    public func build() {
        Scroll {
            Column(space: 12) {
                if (this.showLoadingHint && this.errorText.isEmpty() && this.mainTempLine == "--") {
                    Text("正在加载天气…")
                        .fontSize(14)
                        .fontColor(0xFF888888)
                        .width(100.percent)
                        .textAlign(TextAlign.Center)
                }
                if (!this.errorText.isEmpty()) {
                    Text(this.errorText)
                        .fontSize(14)
                        .fontColor(0xFFFF6600)
                        .width(100.percent)
                        .textAlign(TextAlign.Center)
                }
                Row(space: 12) {
                    if (!this.weatherIconName.isEmpty()) {
                        Image(this.weatherIconName)
                            .width(72.vp)
                            .height(72.vp)
                            .objectFit(ImageFit.Contain)
                    }
                    Column(space: 4) {
                        Text(this.mainTempLine)
                            .fontSize(40)
                            .fontWeight(FontWeight.Bold)
                        Text(this.weatherDesc)
                            .fontSize(16)
                            .fontColor(0xFF444444)
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                }
                .width(100.percent)
                .justifyContent(FlexAlign.Center)
                Text(this.feelsLikeLine)
                    .fontSize(14)
                    .textAlign(TextAlign.Center)
                    .width(100.percent)
                Text(this.dayNightLine)
                    .fontSize(14)
                    .textAlign(TextAlign.Center)
                    .width(100.percent)
                Column(space: 0) {
                    Row(space: 0) {
                        Column(space: 6) {
                            Text("风速")
                                .fontSize(12)
                                .fontColor(0xFF888888)
                            Text(this.windText)
                                .fontSize(16)
                                .fontWeight(FontWeight.Medium)
                            Row(space: 4) {
                                if (!this.windIndIcon.isEmpty()) {
                                    Image(this.windIndIcon)
                                        .width(14.vp)
                                        .height(14.vp)
                                        .objectFit(ImageFit.Contain)
                                }
                                Text(this.windDiffText)
                                    .fontSize(12)
                                    .fontColor(0xFF666666)
                            }
                        }
                        .layoutWeight(1)
                        .padding(8)
                        .alignItems(HorizontalAlign.Start)
                        Column(space: 6) {
                            Text("降水")
                                .fontSize(12)
                                .fontColor(0xFF888888)
                            Text(this.rainText)
                                .fontSize(16)
                                .fontWeight(FontWeight.Medium)
                            Row(space: 4) {
                                if (!this.rainIndIcon.isEmpty()) {
                                    Image(this.rainIndIcon)
                                        .width(14.vp)
                                        .height(14.vp)
                                        .objectFit(ImageFit.Contain)
                                }
                                Text(this.rainDiffText)
                                    .fontSize(12)
                                    .fontColor(0xFF666666)
                            }
                        }
                        .layoutWeight(1)
                        .padding(8)
                        .alignItems(HorizontalAlign.Start)
                    }
                    .width(100.percent)
                    Row(space: 0) {
                        Column(space: 6) {
                            Text("气压")
                                .fontSize(12)
                                .fontColor(0xFF888888)
                            Text(this.pressureText)
                                .fontSize(16)
                                .fontWeight(FontWeight.Medium)
                            Row(space: 4) {
                                if (!this.pressureIndIcon.isEmpty()) {
                                    Image(this.pressureIndIcon)
                                        .width(14.vp)
                                        .height(14.vp)
                                        .objectFit(ImageFit.Contain)
                                }
                                Text(this.pressureDiffText)
                                    .fontSize(12)
                                    .fontColor(0xFF666666)
                            }
                        }
                        .layoutWeight(1)
                        .padding(8)
                        .alignItems(HorizontalAlign.Start)
                        Column(space: 6) {
                            Text("紫外线")
                                .fontSize(12)
                                .fontColor(0xFF888888)
                            Text(this.uvText)
                                .fontSize(16)
                                .fontWeight(FontWeight.Medium)
                            Row(space: 4) {
                                if (!this.uvIndIcon.isEmpty()) {
                                    Image(this.uvIndIcon)
                                        .width(14.vp)
                                        .height(14.vp)
                                        .objectFit(ImageFit.Contain)
                                }
                                Text(this.uvDiffText)
                                    .fontSize(12)
                                    .fontColor(0xFF666666)
                            }
                        }
                        .layoutWeight(1)
                        .padding(8)
                        .alignItems(HorizontalAlign.Start)
                    }
                    .width(100.percent)
                }
                .width(100.percent)
                Row(space: 16) {
                    Column(space: 4) {
                        Text("日出")
                            .fontSize(12)
                            .fontColor(0xFF888888)
                        Text(this.sunriseTime)
                            .fontSize(15)
                        Text(this.sunriseThrough)
                            .fontSize(11)
                            .fontColor(0xFF666666)
                    }
                    .layoutWeight(1)
                    Column(space: 4) {
                        Text("日落")
                            .fontSize(12)
                            .fontColor(0xFF888888)
                        Text(this.sunsetTime)
                            .fontSize(15)
                        Text(this.sunsetThrough)
                            .fontSize(11)
                            .fontColor(0xFF666666)
                    }
                    .layoutWeight(1)
                }
                .width(100.percent)
                .padding(8)
                Text("小时预报")
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .width(100.percent)
                HourlyTempForecastAdapter(items: this.hourlyItems)
                Text("温度趋势")
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .width(100.percent)
                this.lineChartBlock()
                this.precipSection()
                if (!this.lastUpdateLine.isEmpty()) {
                    Text(this.lastUpdateLine)
                        .fontSize(12)
                        .fontColor(0xFF888888)
                        .textAlign(TextAlign.Center)
                        .width(100.percent)
                }
            }
            .width(100.percent)
            .padding(16)
        }
        .width(100.percent)
        .scrollBar(BarState.Auto)
    }
}
