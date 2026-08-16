use std::fs;
use std::path::{Path, PathBuf};
use std::sync::RwLock;
use ureq::{AgentBuilder, Proxy};

static COOKIE_DIR: RwLock<Option<PathBuf>> = RwLock::new(None);

pub fn set_cookie_dir(dir: &str) {
    let trimmed = dir.trim();
    if trimmed.is_empty() {
        return;
    }
    if let Ok(mut guard) = COOKIE_DIR.write() {
        *guard = Some(PathBuf::from(trimmed));
    }
}

pub fn apply(builder: AgentBuilder, url: &str) -> AgentBuilder {
    if is_loopback(url) {
        return builder;
    }
    let Some(proxy) = configured_proxy() else {
        return builder;
    };
    builder.proxy(proxy)
}

fn configured_proxy() -> Option<Proxy> {
    let dir = COOKIE_DIR.read().ok()?.clone()?;
    let raw = fs::read_to_string(dir.join("http_proxy")).ok()?;
    let line = raw.trim();
    if line.is_empty() {
        return None;
    }
    Proxy::new(line).ok()
}

fn is_loopback(url: &str) -> bool {
    let lower = url.to_ascii_lowercase();
    lower.contains("://127.0.0.1")
        || lower.contains("://localhost")
        || lower.contains("://[::1]")
        || Path::new(url).is_absolute()
}
