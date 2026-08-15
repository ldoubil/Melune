use md5::{Digest, Md5};
use serde_json::Value;
use std::time::{SystemTime, UNIX_EPOCH};

const MIXIN_KEY_ENC_TAB: [usize; 64] = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, 33, 9, 42, 19, 29,
    28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25,
    54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
];

#[derive(Clone)]
pub struct WbiKeys {
    pub img_key: String,
    pub sub_key: String,
}

pub fn keys_from_nav(nav: &Value) -> Option<WbiKeys> {
    let img_url = nav["data"]["wbi_img"]["img_url"]
        .as_str()
        .or_else(|| nav["wbi_img"]["img_url"].as_str())
        .unwrap_or("");
    let sub_url = nav["data"]["wbi_img"]["sub_url"]
        .as_str()
        .or_else(|| nav["wbi_img"]["sub_url"].as_str())
        .unwrap_or("");
    let img_key = file_stem(img_url);
    let sub_key = file_stem(sub_url);
    if img_key.is_empty() || sub_key.is_empty() {
        return None;
    }
    Some(WbiKeys { img_key, sub_key })
}

fn file_stem(url: &str) -> String {
    let name = url.rsplit('/').next().unwrap_or("");
    name.split('.').next().unwrap_or("").to_string()
}

fn mixin_key(orig: &str) -> String {
    MIXIN_KEY_ENC_TAB
        .iter()
        .filter_map(|i| orig.chars().nth(*i))
        .take(32)
        .collect()
}

fn encode_uri_component(input: &str) -> String {
    let mut out = String::new();
    for b in input.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char);
            }
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

fn md5_hex(input: &str) -> String {
    let mut hasher = Md5::new();
    hasher.update(input.as_bytes());
    hex::encode(hasher.finalize())
}

pub fn encode_wbi(keys: &WbiKeys, params: &[(&str, String)]) -> String {
    let mixin = mixin_key(&format!("{}{}", keys.img_key, keys.sub_key));
    let wts = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let mut pairs: Vec<(String, String)> = params
        .iter()
        .map(|(k, v)| (k.to_string(), v.replace(['!', '\'', '(', ')', '*'], "")))
        .collect();
    pairs.push(("wts".to_string(), wts.to_string()));
    pairs.sort_by(|a, b| a.0.cmp(&b.0));
    let query = pairs
        .iter()
        .map(|(k, v)| format!("{}={}", encode_uri_component(k), encode_uri_component(v)))
        .collect::<Vec<_>>()
        .join("&");
    let w_rid = md5_hex(&format!("{query}{mixin}"));
    format!("{query}&w_rid={w_rid}")
}

pub fn encode_uri_component_pub(input: &str) -> String {
    encode_uri_component(input)
}
