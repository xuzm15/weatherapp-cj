# Feature: resource（`Resource<T>` 结果包装）

## 实现概要

- **类型**：`models/Resource.cj` 中定义泛型枚举 `Resource<T>`，三态为 `Success(T)`、`Error(String)`、`Loading`，对应 Android `com.wemaka.weatherapp.util.Resource` 的 Success / Error / Loading。
- **API**：`isSuccess()`、`isError()`、`isLoading()`、`getData()`（`Option<T>`）、`getMessage()`（`Option<String>`）。`getData` / `getMessage` 仅在对应态返回 `Some`，其余为 `None`。

## 使用方式

- 成功：`Resource.Success(data)`
- 失败：`Resource.Error("msg")`
- 加载中：`Resource.Loading`

跨包引用：`import ohos_app_cangjie_entry.models.Resource`。

## 限制与说明

- 与 Java 侧「getter 可能返回 null」一致地采用 `Option`，避免裸空指针。
- 本 feature 为纯本地模型，无网络与 UI；未引入 IR 管线（`conversion.mode` 为 llm-only）。

## 参考

- 仓颉泛型枚举写法参考 `stdx.effect` 中 `ImmediateHandlerReturn<T>` 模式（工程外标准库参考）。
