# PlaceInfo 开发记录

## 概述

PlaceInfo 是一个纯数据模型类，对应 Java 源码中使用 Lombok `@AllArgsConstructor` + `@Getter` 注解的 POJO。在仓颉中翻译为带构造器的不可变 class。

## 实现要点

- **文件位置**: `<target_cangjie_root>/models/PlaceInfo.cj`
- **包名**: `ohos_app_cangjie_entry.models`（子目录需使用子包名）
- **implementation_kind**: `local_state`

### 字段映射（Java → Cangjie）

| Java 字段 | Cangjie 字段 | 类型 |
|-----------|-------------|------|
| `private final String toponymName` | `let toponymName: String` | 构造器参数 |
| `private final String countryName` | `let countryName: String` | 构造器参数 |
| `private final String countryCode` | `let countryCode: String` | 构造器参数 |
| `private final String lang` | `let lang: String` | 构造器参数 |
| `private final String adminName1` | `let adminName1: String` | 构造器参数 |
| `private final String latitude` | `let latitude: String` | 构造器参数 |
| `private final String longitude` | `let longitude: String` | 构造器参数 |

### 设计决策

1. **`let` 构造器参数**：Cangjie 的 `let` 构造器参数同时声明不可变字段并自动暴露为公开属性，等价于 Java 的 `final` 字段 + `@Getter`
2. **实现 `ToString` 接口**：提供 `toString()` 方法，便于调试输出
3. **`class` 而非 `struct`**：选择 `class` 以保持引用语义，与 Java 原始实现一致

## 编译陷阱

- **子目录包名规则**：`cangjie/models/` 目录下的文件包名必须是 `ohos_app_cangjie_entry.models`，不能用根包名 `ohos_app_cangjie_entry`

## cangjie-kb MCP 查询记录

- MCP 不可用，改用 reference 源码 `arkui_cangjie_wrapper` 中 `Student1` 数据类模式确认构造器语法

## 已知限制

- 无（纯数据模型，功能完整）
