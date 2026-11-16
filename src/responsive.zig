const nanoui = @import("nanoui");
const ui = nanoui.ui;

pub const compact_breakpoint: f32 = 680;

pub fn isCompact(c: *ui.Context) bool {
    return c.size.w < compact_breakpoint;
}

pub fn pagePadding(c: *ui.Context) f32 {
    return if (isCompact(c)) 16 else 30;
}
