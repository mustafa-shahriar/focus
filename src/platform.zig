/// What the build targets: the desktop draws its own title bar and window
/// controls, while Android has the system's bars and no window chrome.
const builtin = @import("builtin");

pub const is_android = builtin.abi.isAndroid();
