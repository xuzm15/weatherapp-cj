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
