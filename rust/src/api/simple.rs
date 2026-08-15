/// Display name of the Melune app.
#[flutter_rust_bridge::frb(sync)]
pub fn app_name() -> String {
    "Melune · 洛音".to_string()
}

#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("你好，{name}。欢迎来到 Melune · 洛音。")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
