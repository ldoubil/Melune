/// 桌面歌词已改由 Flutter 第二窗口渲染，这里只保留 FRB 符号以免重新 generate。
#[flutter_rust_bridge::frb(sync)]
pub fn desktop_lyric_set(
    _visible: bool,
    _locked: bool,
    _liked: bool,
    _cover_url: String,
    _previous: String,
    _current: String,
    _next: String,
) -> Result<(), String> {
    Ok(())
}
