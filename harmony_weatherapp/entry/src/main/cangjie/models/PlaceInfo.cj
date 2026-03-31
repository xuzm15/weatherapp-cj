package ohos_app_cangjie_entry.models

public class PlaceInfo <: ToString {
    public PlaceInfo(
        let toponymName: String,
        let countryName: String,
        let countryCode: String,
        let lang: String,
        let adminName1: String,
        let latitude: String,
        let longitude: String
    ) {}

    public func toString(): String {
        return "PlaceInfo(toponymName=${toponymName}, countryName=${countryName}, countryCode=${countryCode}, lang=${lang}, adminName1=${adminName1}, latitude=${latitude}, longitude=${longitude})"
    }
}
