# data_store_serializer

## 实现概要

Android 侧 `DataStoreSerializer` 实现 Jetpack `Serializer<DataStoreProto>`，通过 Wire Protobuf 的 `decode` / `encode` 读写流。鸿蒙无等价 DataStore/Protobuf，本 feature 在仓颉侧提供**持久化序列化层**：以 UTF-8 将 `String`（通常为 JSON 配置）与 `Array<UInt8>` 互转，与 `AppConfig` 中已采用的 `Preferences` 路径配合使用（写入前 `serialize`、读出后 `deserialize`）。

## 目标文件（相对 `<target_cangjie_root>`）

- `services/DataStoreSerializer.cj`：`DataStoreSerializer` 类，静态方法 `serialize(data: String): Array<UInt8>`、`deserialize(bytes: Array<UInt8>): String`；空字节数组反序列化为空字符串。

## 与 Android 对应关系

| Android | 鸿蒙 |
|--------|------|
| `readFrom(InputStream)` → `ADAPTER.decode` | `deserialize(bytes)` ← UTF-8 字节 |
| `writeTo` → `encode(OutputStream)` | `serialize(data)` → UTF-8 字节再写入流/存储 |
| `getDefaultValue()` 空 proto | 空字节 → `""`（调用方可再解析默认 JSON） |

## 已知限制

- 非 Protobuf 二进制兼容；若后续需要与 Android `settings.pb` 字节级互通，需另行定义跨端 schema 或迁移策略。
- `String.fromUtf8` 要求合法 UTF-8；非法序列需在上层处理（本类保持与 Java 侧「解码失败抛异常」类似的契约，由运行时校验）。

## 编译

在 output worktree 根目录执行：`IOS2CJ_WORKFLOW_CONFIG=<workflow.config> bash <core.src_root>/scripts/build.sh cangjie`（本轮已通过）。

## MCP / IR

- `conversion.mode`: llm-only；未使用 IR 管线。
- 本轮会话未接入 cangjie-kb MCP；实现依据工程内 `syntax_error.md` 子目录 package 规则与标准库 `String.toArray` / `String.fromUtf8` 用法。
