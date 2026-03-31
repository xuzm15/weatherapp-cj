package ohos_app_cangjie_entry.services

/**
 * 数据持久化序列化层：对应 Android Jetpack `Serializer<DataStoreProto>` 中
 * `readFrom` / `writeTo` 对 Protobuf 流的编解码。
 * 鸿蒙侧无 DataStore/Protobuf 时，以 UTF-8 字节与 `String`（通常为 JSON）互转，
 * 供 `Preferences` 等存储在写入前序列化、读出后反序列化。
 */
public class DataStoreSerializer {
    public init() {}

    /** 将文本（如 JSON）序列化为 UTF-8 字节，便于写入二进制流或自定义存储。 */
    public static func serialize(data: String): Array<UInt8> {
        return data.toArray()
    }

    /** 将 UTF-8 字节反序列化为字符串；空数组得到空串。 */
    public static func deserialize(bytes: Array<UInt8>): String {
        if (bytes.size == 0) {
            return ""
        }
        return String.fromUtf8(bytes)
    }
}
