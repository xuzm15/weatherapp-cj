package ohos_app_cangjie_entry.models

/**
 * 异步或计算结果的包装，对应 Android `Resource<T>` 的 Success / Error / Loading 三态。
 */
public enum Resource<T> {
    Success(T)
    | Error(String)
    | Loading

    public func isSuccess(): Bool {
        match (this) {
            case Success(_) => true
            case _ => false
        }
    }

    public func isError(): Bool {
        match (this) {
            case Error(_) => true
            case _ => false
        }
    }

    public func isLoading(): Bool {
        match (this) {
            case Loading => true
            case _ => false
        }
    }

    /** 成功时返回数据，否则为 `None`。 */
    public func getData(): Option<T> {
        match (this) {
            case Success(d) => Some(d)
            case _ => None
        }
    }

    /** 错误态返回消息，其余为 `None`。 */
    public func getMessage(): Option<String> {
        match (this) {
            case Error(msg) => Some(msg)
            case _ => None
        }
    }
}
