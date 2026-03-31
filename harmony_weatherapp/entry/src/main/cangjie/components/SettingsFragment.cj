package ohos_app_cangjie_entry.components

import ohos_app_cangjie_entry.foundation.AppConfig
import kit.ArkData.PreferencesValueType
import kit.ArkUI.*
import kit.PerformanceAnalysisKit.Hilog
import ohos.arkui.component.*
import ohos.arkui.state_macro_manage.*

private let SETTINGS_TAG: String = "SettingsFragment"

private let K_LANG: String = "pref_language"
private let K_TEMP: String = "pref_temperature_unit"
private let K_WIND: String = "pref_wind_speed_unit"
private let K_PRESS: String = "pref_pressure_unit"

private let LANG_LABELS: Array<String> = ["English", "Русский"]
private let LANG_VALUES: Array<String> = ["en", "ru"]

private let TEMP_LABELS: Array<String> = ["Degrees Celsius (°C)", "Degrees Fahrenheit (°F)"]
private let TEMP_VALUES: Array<String> = ["celsius", "fahrenheit"]

private let WIND_LABELS: Array<String> = [
    "Kilometers per hour (km/h)",
    "Meters per second (m/s)",
    "Miles per hour (mph)"
]
private let WIND_VALUES: Array<String> = ["kmh", "ms", "mph"]

private let PRESS_LABELS: Array<String> = [
    "Hectopascals (hPa)",
    "Millimeters of mercury column (mmHg)",
    "Inch of mercury column (inHg)"
]
private let PRESS_VALUES: Array<String> = ["hpa", "mmhg", "inhg"]

private func defaultStringHandler(_: String): Unit {}

private func indexOfValue(values: Array<String>, v: String): Int32 {
    var i: Int64 = 0
    while (i < values.size) {
        if (values[i] == v) {
            return Int32(i)
        }
        i += 1
    }
    return 0
}

private func labelFor(values: Array<String>, labels: Array<String>, current: String): String {
    var i: Int64 = 0
    while (i < values.size && i < labels.size) {
        if (values[i] == current) {
            return labels[i]
        }
        i += 1
    }
    if (labels.size > 0) {
        return labels[0]
    }
    return ""
}

private func langOptions(): Array<SelectOption> {
    [
        SelectOption(value: LANG_LABELS[0]),
        SelectOption(value: LANG_LABELS[1])
    ]
}

private func tempOptions(): Array<SelectOption> {
    [
        SelectOption(value: TEMP_LABELS[0]),
        SelectOption(value: TEMP_LABELS[1])
    ]
}

private func windOptions(): Array<SelectOption> {
    [
        SelectOption(value: WIND_LABELS[0]),
        SelectOption(value: WIND_LABELS[1]),
        SelectOption(value: WIND_LABELS[2])
    ]
}

private func pressOptions(): Array<SelectOption> {
    [
        SelectOption(value: PRESS_LABELS[0]),
        SelectOption(value: PRESS_LABELS[1]),
        SelectOption(value: PRESS_LABELS[2])
    ]
}

/**
 * 对应 Android `PreferenceFragmentCompat` + `root_preferences.xml` 中的四个 `ListPreference`。
 * 使用 `Row`（标题 + `Select` 摘要）与 `Preferences` 持久化；变更通过回调通知宿主。
 */
@Component
public class SettingsFragment {
    @State
    var selectedLanguage: String = "en"
    @State
    var selectedTemperature: String = "celsius"
    @State
    var selectedWindSpeed: String = "kmh"
    @State
    var selectedPressure: String = "hpa"

    public var onLanguageChange: (String) -> Unit = defaultStringHandler
    public var onTemperatureChange: (String) -> Unit = defaultStringHandler
    public var onWindSpeedChange: (String) -> Unit = defaultStringHandler
    public var onPressureChange: (String) -> Unit = defaultStringHandler

    protected override func aboutToAppear(): Unit {
        match (AppConfig.settingsPreferences) {
            case Some(prefs) =>
                match (prefs.get(K_LANG, PreferencesValueType.StringData("en"))) {
                    case StringData(s) => this.selectedLanguage = s
                    case _ => ()
                }
                match (prefs.get(K_TEMP, PreferencesValueType.StringData("celsius"))) {
                    case StringData(s) => this.selectedTemperature = s
                    case _ => ()
                }
                match (prefs.get(K_WIND, PreferencesValueType.StringData("kmh"))) {
                    case StringData(s) => this.selectedWindSpeed = s
                    case _ => ()
                }
                match (prefs.get(K_PRESS, PreferencesValueType.StringData("hpa"))) {
                    case StringData(s) => this.selectedPressure = s
                    case _ => ()
                }
            case None => Hilog.info(1, SETTINGS_TAG, "preferences not ready; use defaults")
        }
    }

    private func persistKey(key: String, value: String): Unit {
        match (AppConfig.settingsPreferences) {
            case Some(prefs) =>
                prefs.put(key, PreferencesValueType.StringData(value))
                try {
                    prefs.flush()
                } catch (e: Exception) {
                    Hilog.error(1, SETTINGS_TAG, "flush: ${e.message}")
                }
            case None => ()
        }
    }

    @Builder
    func uiTitle(): Unit {
        Text("Settings")
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .width(100.percent)
    }

    @Builder
    func rowLanguage(): Unit {
        Row(space: 8) {
            Text("Language")
                .fontSize(16)
                .layoutWeight(1)
            Select(langOptions())
                .selected(indexOfValue(LANG_VALUES, this.selectedLanguage))
                .value(labelFor(LANG_VALUES, LANG_LABELS, this.selectedLanguage))
                .layoutWeight(2)
                .onSelect({
                    idx: Int32, _: String =>
                    let i = Int64(idx)
                    if (i >= 0 && i < LANG_VALUES.size) {
                        let v = LANG_VALUES[i]
                        if (v != this.selectedLanguage) {
                            this.selectedLanguage = v
                            this.persistKey(K_LANG, v)
                            this.onLanguageChange(v)
                        }
                    }
                })
        }
        .width(100.percent)
        .alignItems(VerticalAlign.Center)
    }

    @Builder
    func rowTemperature(): Unit {
        Row(space: 8) {
            Text("Temperature")
                .fontSize(16)
                .layoutWeight(1)
            Select(tempOptions())
                .selected(indexOfValue(TEMP_VALUES, this.selectedTemperature))
                .value(labelFor(TEMP_VALUES, TEMP_LABELS, this.selectedTemperature))
                .layoutWeight(2)
                .onSelect({
                    idx: Int32, _: String =>
                    let i = Int64(idx)
                    if (i >= 0 && i < TEMP_VALUES.size) {
                        let v = TEMP_VALUES[i]
                        if (v != this.selectedTemperature) {
                            this.selectedTemperature = v
                            this.persistKey(K_TEMP, v)
                            this.onTemperatureChange(v)
                        }
                    }
                })
        }
        .width(100.percent)
        .alignItems(VerticalAlign.Center)
    }

    @Builder
    func rowWind(): Unit {
        Row(space: 8) {
            Text("Wind speed")
                .fontSize(16)
                .layoutWeight(1)
            Select(windOptions())
                .selected(indexOfValue(WIND_VALUES, this.selectedWindSpeed))
                .value(labelFor(WIND_VALUES, WIND_LABELS, this.selectedWindSpeed))
                .layoutWeight(2)
                .onSelect({
                    idx: Int32, _: String =>
                    let i = Int64(idx)
                    if (i >= 0 && i < WIND_VALUES.size) {
                        let v = WIND_VALUES[i]
                        if (v != this.selectedWindSpeed) {
                            this.selectedWindSpeed = v
                            this.persistKey(K_WIND, v)
                            this.onWindSpeedChange(v)
                        }
                    }
                })
        }
        .width(100.percent)
        .alignItems(VerticalAlign.Center)
    }

    @Builder
    func rowPressure(): Unit {
        Row(space: 8) {
            Text("Air pressure")
                .fontSize(16)
                .layoutWeight(1)
            Select(pressOptions())
                .selected(indexOfValue(PRESS_VALUES, this.selectedPressure))
                .value(labelFor(PRESS_VALUES, PRESS_LABELS, this.selectedPressure))
                .layoutWeight(2)
                .onSelect({
                    idx: Int32, _: String =>
                    let i = Int64(idx)
                    if (i >= 0 && i < PRESS_VALUES.size) {
                        let v = PRESS_VALUES[i]
                        if (v != this.selectedPressure) {
                            this.selectedPressure = v
                            this.persistKey(K_PRESS, v)
                            this.onPressureChange(v)
                        }
                    }
                })
        }
        .width(100.percent)
        .alignItems(VerticalAlign.Center)
    }

    public func build() {
        Scroll() {
            Column(space: 16) {
                this.uiTitle()
                this.rowLanguage()
                this.rowTemperature()
                this.rowWind()
                this.rowPressure()
            }
            .width(100.percent)
            .padding(4)
        }
        .width(100.percent)
        .layoutWeight(1)
    }
}
