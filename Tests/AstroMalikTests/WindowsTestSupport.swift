#if os(Windows)
import ucrt
@discardableResult
func setenv(_ name: String, _ value: String, _ overwrite: Int32) -> Int32 {
    if overwrite == 0, getenv(name) != nil { return 0 }
    return _putenv_s(name, value)
}
@discardableResult
func unsetenv(_ name: String) -> Int32 { _putenv_s(name, "") }
#endif
