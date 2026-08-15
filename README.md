# Melune · 洛音

Flutter 界面 + Rust 核心，通过 [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) 互通。

## 技术栈

| 层 | 技术 |
| --- | --- |
| UI | Flutter 3.46（Dart 3.13） |
| 核心 | Rust 1.97 |
| 桥接 | flutter_rust_bridge 2.12 |

包名：`melune`　组织：`dev.melune`　Rust crate：`rust_lib_melune`

## 目录

```
lib/                 Flutter 应用
lib/src/rust/        自动生成的 Dart 绑定（勿手改）
rust/src/api/        对 Flutter 暴露的 Rust API
rust_builder/        Cargokit：把 Rust 编进各平台
```

写业务时：Flutter 看 `lib/`，Rust 看 `rust/src/api/`。

## 环境

- Flutter（已开启 Windows / 桌面）
- Rust（`rustup` + `cargo`）
- `flutter_rust_bridge_codegen`（`cargo install flutter_rust_bridge_codegen`）

当前机器尚未配置 Android SDK。要打 Android 包，需先安装 Android Studio / SDK。

## 运行

Windows 桌面：

```bash
flutter run -d windows
```

改 Rust API 后重新生成绑定：

```bash
flutter_rust_bridge_codegen generate
```

监听并自动生成：

```bash
flutter_rust_bridge_codegen generate --watch
```

## 最小示例

Rust（`rust/src/api/simple.rs`）：

```rust
pub fn greet(name: String) -> String {
    format!("你好，{name}。欢迎来到 Melune · 洛音。")
}
```

Dart：

```dart
final text = greet(name: '洛音');
```
