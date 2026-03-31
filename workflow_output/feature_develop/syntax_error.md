# 仓颉编译陷阱记录

## 子目录 package 名称必须匹配目录路径
- **触发条件**: 在 `<cangjie_root>/models/` 子目录中的 .cj 文件使用 `package ohos_app_cangjie_entry`（根 package 名）
- **错误信息**: `Error: the package name in .../models is wrong, the right name should be 'ohos_app_cangjie_entry.models'`
- **修复方式**: 子目录中的文件必须使用 `package ohos_app_cangjie_entry.<子目录名>`，跨子包引用需 `import ohos_app_cangjie_entry.<子包>.*`
- **发现于**: location_provider, 2026-03-31

## 带默认值命名参数构造函数与无参构造函数歧义
- **触发条件**: 类同时定义 `public init() {}` 和 `public init(latitude!: Float64 = 0.0, longitude!: Float64 = 0.0)` 两个构造函数，调用 `ClassName()` 时编译器无法选择
- **错误信息**: `error: ambiguous match for constructor call 'LocationCoord'`
- **修复方式**: 移除无参 `init()`，仅保留带默认值命名参数的 `init(...)`，因为所有参数有默认值时已可零参调用
- **发现于**: location_provider, 2026-03-31

## 子类继承需基类 `open` 且覆写方法需 `open`
- **触发条件**: `public class Child <: Parent` 而 `Parent` 未标记 `open`，或覆写 `public func` 而父类方法未标记 `open`
- **错误信息**: `super class 'Parent' is not inheritable` / `cannot override function ... parent is not modified by 'open'`
- **修复方式**: 将基类声明为 `public open class`，将允许覆写的方法改为 `public open func`，子类中使用 `public open func` 覆写
- **发现于**: fused_location_provider, 2026-03-31

## Hilog.warn 与 Hilog.error 参数个数不一致
- **触发条件**: 调用 `Hilog.warn(domain, tag, msg)` 三参数形式
- **错误信息**: `missing argument for parameter list '(UInt32, Struct-String, Struct-String, Struct-Array<...>)' in call`
- **修复方式**: 对该 SDK 版本改用 `Hilog.error`/`Hilog.info` 等与现有工程一致的三参数形式，或按编译器提示补全四参数重载
- **发现于**: fused_location_provider, 2026-03-31

## 异步回调中修改外层 var / waitUntil 捕获可变变量
- **触发条件**: `HttpRequest.request` 的回调里对函数作用域内的 `var`（如 `body`、`done`）赋值；或对 `cond.waitUntil({ => done })` 使用外层可变 `done`
- **错误信息**: `lambda capturing mutable variables needs to be called directly`
- **修复方式**: 将状态放入引用类型（如私有 `class HttpSyncBox { var body: String; var done: Bool; ... }`），在回调内修改字段；等待循环使用 `while (!box.done) { cond.wait() }`，避免在谓词闭包中捕获可变标量
- **发现于**: geo_location_client, 2026-03-31

## HttpData 枚举匹配需覆盖开放变体
- **触发条件**: `match (r.result)` 仅列出 `StringData` / `ArrayData`
- **错误信息**: `non-exhaustive patterns` / `_ is not covered`
- **修复方式**: 增加 `case _ => ...` 处理 SDK 中 `HttpData` 的 `| ...` 扩展变体
- **发现于**: geo_location_client, 2026-03-31

## 字符串下标 `body[pos]` 为 UInt8，不可与字符字面量直接比较
- **触发条件**: `body[pos] == ']'`、`c == '{'` 等写法（`body[pos]` 类型为 `UInt8`）
- **错误信息**: `invalid binary operator '==' on type 'UInt8' and 'Struct-String'`
- **修复方式**: 使用 `Int64(body[pos]) == 93`（`]`）、`123`（`{`）、`125`（`}`）等与整数码点比较
- **发现于**: geo_names_client, 2026-03-31
