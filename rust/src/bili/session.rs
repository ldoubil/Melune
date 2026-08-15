use super::wbi::{self, WbiKeys};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use ureq::Response;

const UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36";
const API: &str = "https://api.bilibili.com";
const PASSPORT: &str = "https://passport.bilibili.com";
const REFERER: &str = "https://www.bilibili.com";
/// DASH + HDR + 4K + 杜比音频 + 杜比视界 + 8K + AV1，才能拿到 Hi-Res / 杜比音频流。
const FNVAL: &str = "4048";

pub struct Session {
    cookies: HashMap<String, String>,
    cookie_path: PathBuf,
    wbi: Option<(WbiKeys, Instant)>,
}

impl Session {
    pub fn open(cookie_dir: &str) -> Result<Self, String> {
        let dir = PathBuf::from(cookie_dir);
        fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
        let cookie_path = dir.join("cookies.json");
        let mut cookies = load_cookies(&cookie_path);
        ensure_buvid(&mut cookies);
        let session = Self {
            cookies,
            cookie_path,
            wbi: None,
        };
        session.persist()?;
        Ok(session)
    }

    pub fn persist(&self) -> Result<(), String> {
        let json = serde_json::to_string_pretty(&self.cookies).map_err(|e| e.to_string())?;
        fs::write(&self.cookie_path, json).map_err(|e| e.to_string())
    }

    pub fn is_logged_in(&self) -> bool {
        self.cookies.contains_key("SESSDATA")
            && self.cookies.contains_key("bili_jct")
            && self.cookies.contains_key("DedeUserID")
    }

    pub fn logout(&mut self) -> Result<(), String> {
        for key in ["SESSDATA", "bili_jct", "DedeUserID", "DedeUserID__ckMd5"] {
            self.cookies.remove(key);
        }
        self.persist()
    }

    fn cookie_header(&self) -> String {
        self.cookies
            .iter()
            .map(|(k, v)| format!("{k}={v}"))
            .collect::<Vec<_>>()
            .join("; ")
    }

    fn absorb_cookies(&mut self, resp: &Response) {
        for header in resp.all("set-cookie") {
            if let Some((name, value)) = parse_set_cookie(header) {
                self.cookies.insert(name, value);
            }
        }
    }

    fn request(
        &mut self,
        method: &str,
        url: &str,
        referer: &str,
        form: Option<&[(&str, &str)]>,
        redirects: u32,
    ) -> Result<Response, String> {
        let agent = ureq::AgentBuilder::new()
            .timeout(Duration::from_secs(25))
            .user_agent(UA)
            .redirects(redirects)
            .build();
        let mut req = if method == "POST" {
            agent.post(url)
        } else {
            agent.get(url)
        };
        req = req
            .set("Referer", referer)
            .set("Origin", "https://www.bilibili.com");
        let cookie = self.cookie_header();
        if !cookie.is_empty() {
            req = req.set("Cookie", &cookie);
        }
        let resp = if let Some(form) = form {
            req.send_form(form).map_err(map_ureq)?
        } else {
            req.call().map_err(map_ureq)?
        };
        self.absorb_cookies(&resp);
        let _ = self.persist();
        Ok(resp)
    }

    fn get_json(&mut self, path: &str, referer: &str) -> Result<Value, String> {
        let url = if path.starts_with("http") {
            path.to_string()
        } else {
            format!("{API}{path}")
        };
        let resp = self.request("GET", &url, referer, None, 8)?;
        resp.into_json::<Value>().map_err(|e| e.to_string())
    }

    fn require_data(&self, body: Value, path: &str) -> Result<Value, String> {
        let code = body["code"].as_i64().unwrap_or(-1);
        if code != 0 {
            let message = body["message"].as_str().unwrap_or("未知错误");
            return Err(format!("B站接口 {path} 错误 {code}：{message}"));
        }
        Ok(body["data"].clone())
    }

    fn require_ok_payload(&self, body: Value, path: &str) -> Result<Value, String> {
        let code = body["code"].as_i64().unwrap_or(-1);
        if code != 0 {
            let message = body["message"]
                .as_str()
                .or_else(|| body["msg"].as_str())
                .unwrap_or("未知错误");
            return Err(format!("B站接口 {path} 错误 {code}：{message}"));
        }
        Ok(body)
    }

    fn wbi_keys(&mut self) -> Result<WbiKeys, String> {
        if let Some((keys, ts)) = &self.wbi {
            if ts.elapsed() < Duration::from_secs(6 * 3600) {
                return Ok(keys.clone());
            }
        }
        let url = format!("{API}/x/web-interface/nav");
        let resp = self.request("GET", &url, REFERER, None, 8)?;
        let body: Value = resp.into_json().map_err(|e| e.to_string())?;
        let keys = wbi::keys_from_nav(&body).ok_or_else(|| "无法读取 WBI 密钥".to_string())?;
        self.wbi = Some((keys.clone(), Instant::now()));
        Ok(keys)
    }

    fn get_wbi(
        &mut self,
        path: &str,
        params: &[(&str, String)],
        referer: &str,
    ) -> Result<Value, String> {
        let keys = self.wbi_keys()?;
        let query = wbi::encode_wbi(&keys, params);
        let url = format!("{API}{path}?{query}");
        let body = self.get_json(&url, referer)?;
        self.require_data(body, path)
    }

    pub fn nav(&mut self) -> Result<Value, String> {
        let body = self.get_json("/x/web-interface/nav", REFERER)?;
        if let Some(keys) = wbi::keys_from_nav(&body) {
            self.wbi = Some((keys, Instant::now()));
        }
        if body["code"].as_i64().unwrap_or(-1) == 0 {
            return Ok(body["data"].clone());
        }
        Ok(json!({
            "isLogin": false,
            "mid": 0,
            "uname": "",
            "face": "",
        }))
    }

    pub fn qr_generate(&mut self) -> Result<Value, String> {
        let url = format!("{PASSPORT}/x/passport-login/web/qrcode/generate");
        let body = self.get_json(&url, "https://passport.bilibili.com/login")?;
        self.require_data(body, "qrGenerate")
    }

    pub fn qr_poll(&mut self, qrcode_key: &str) -> Result<(i64, String), String> {
        let url = format!(
            "{PASSPORT}/x/passport-login/web/qrcode/poll?qrcode_key={}",
            wbi::encode_uri_component_pub(qrcode_key)
        );
        let resp = self.request("GET", &url, "https://passport.bilibili.com/login", None, 0)?;
        let status = resp.status();
        if status == 301 || status == 302 {
            return Ok((0, "登录成功".to_string()));
        }
        let body: Value = resp.into_json().map_err(|e| e.to_string())?;
        let code = body["data"]["code"]
            .as_i64()
            .or_else(|| body["code"].as_i64())
            .unwrap_or(-1);
        let message = body["data"]["message"]
            .as_str()
            .or_else(|| body["message"].as_str())
            .unwrap_or("")
            .to_string();
        Ok((code, message))
    }

    pub fn search_video(
        &mut self,
        keyword: &str,
        page: u32,
        page_size: u32,
    ) -> Result<Value, String> {
        self.get_wbi(
            "/x/web-interface/wbi/search/type",
            &[
                ("search_type", "video".into()),
                ("keyword", keyword.into()),
                ("page", page.to_string()),
                ("page_size", page_size.to_string()),
                ("tids", "3".into()),
            ],
            REFERER,
        )
    }

    pub fn video_view(&mut self, bvid: &str) -> Result<Value, String> {
        let body = self.get_json(
            &format!(
                "/x/web-interface/view?bvid={}",
                wbi::encode_uri_component_pub(bvid)
            ),
            REFERER,
        )?;
        self.require_data(body, "/x/web-interface/view")
    }

    pub fn playurl(&mut self, bvid: &str, cid: i64, avid: Option<i64>) -> Result<Value, String> {
        let wbi = self.get_wbi(
            "/x/player/wbi/playurl",
            &playurl_params(bvid, cid, avid),
            &format!("{REFERER}/video/{bvid}"),
        );
        if let Ok(data) = wbi {
            return Ok(data);
        }
        let mut path = format!("/x/player/playurl?cid={cid}&qn=0&fnver=0&fnval={FNVAL}&fourk=1");
        if !bvid.is_empty() {
            path.push_str(&format!("&bvid={}", wbi::encode_uri_component_pub(bvid)));
        }
        if let Some(avid) = avid {
            path.push_str(&format!("&avid={avid}"));
        }
        let body = self.get_json(&path, &format!("{REFERER}/video/{bvid}"))?;
        self.require_data(body, "/x/player/playurl")
    }

    pub fn ranking(&mut self) -> Result<Value, String> {
        let body = self.get_json(
            "/x/web-interface/ranking/v2?rid=1003&type=all&web_location=333.934",
            "https://www.bilibili.com/v/popular/rank/music",
        )?;
        self.require_data(body, "/x/web-interface/ranking/v2")
    }

    pub fn new_music(&mut self) -> Result<Value, String> {
        let body = self.get_json("/x/centralization/interface/new/music", REFERER)?;
        self.require_data(body, "/x/centralization/interface/new/music")
    }

    pub fn music_rank(&mut self, ps: u32) -> Result<Value, String> {
        let body = self.get_json(
            &format!("/x/centralization/interface/music/comprehensive/web/rank?pn=1&ps={ps}"),
            REFERER,
        )?;
        self.require_data(body, "music/comprehensive/web/rank")
    }

    pub fn music_region(&mut self, page: u32, page_size: u32) -> Result<Value, String> {
        let body = self.get_json(
            &format!("/x/web-interface/dynamic/region?rid=3&pn={page}&ps={page_size}"),
            "https://www.bilibili.com/v/music/",
        )?;
        self.require_data(body, "/x/web-interface/dynamic/region")
    }

    /// 分区最新投稿。`dynamic/region` 已对 rid=3 返回 -404，B 站频道页改走这条。
    pub fn newlist(&mut self, rid: i64, page: u32, page_size: u32) -> Result<Value, String> {
        let body = self.get_json(
            &format!(
                "/x/web-interface/newlist?rid={rid}&type=0&pn={page}&ps={page_size}"
            ),
            "https://www.bilibili.com/v/music/",
        )?;
        self.require_data(body, "/x/web-interface/newlist")
    }

    /// 分区近 1/3/7 日热门。音乐区 `rid=3`。
    pub fn ranking_region(&mut self, rid: i64, day: u32) -> Result<Value, String> {
        let day = if matches!(day, 1 | 3 | 7) { day } else { 3 };
        let body = self.get_json(
            &format!("/x/web-interface/ranking/region?rid={rid}&day={day}"),
            "https://www.bilibili.com/v/music/",
        )?;
        self.require_data(body, "/x/web-interface/ranking/region")
    }

    /// 子分区近 N 日按播放量排序。对齐 B 站频道页「热门」。
    pub fn cate_hot(
        &mut self,
        cate_id: i64,
        days: u32,
        page: u32,
        page_size: u32,
    ) -> Result<Value, String> {
        let (time_from, time_to) = ymd_range_cst(days.max(1));
        let url = format!(
            "https://s.search.bilibili.com/cate/search?main_ver=v3&search_type=video&view_type=hot_rank&order=click&copy_right=-1&cate_id={cate_id}&page={}&pagesize={}&time_from={time_from}&time_to={time_to}",
            page.max(1),
            page_size.clamp(1, 50),
        );
        let body = self.get_json(&url, "https://www.bilibili.com/v/music/")?;
        self.require_ok_payload(body, "cate/search")
    }

    /// 频道页近期热门的 API 站版本，和 `cate/search` 同参。
    pub fn newlist_rank(
        &mut self,
        cate_id: i64,
        days: u32,
        page: u32,
        page_size: u32,
    ) -> Result<Value, String> {
        let (time_from, time_to) = ymd_range_cst(days.max(1));
        let path = format!(
            "/x/web-interface/newlist_rank?main_ver=v3&search_type=video&view_type=hot_rank&order=click&copy_right=-1&cate_id={cate_id}&page={}&pagesize={}&time_from={time_from}&time_to={time_to}",
            page.max(1),
            page_size.clamp(1, 50),
        );
        let body = self.get_json(&path, "https://www.bilibili.com/v/music/")?;
        self.require_ok_payload(body, "/x/web-interface/newlist_rank")
    }

    /// UP 主合集里的稿件列表，当作歌单。
    pub fn season_archives(
        &mut self,
        mid: i64,
        season_id: i64,
        page: u32,
        page_size: u32,
    ) -> Result<Value, String> {
        let path = format!(
            "/x/polymer/web-space/seasons_archives_list?mid={mid}&season_id={season_id}&sort_reverse=false&page_num={}&page_size={}",
            page.max(1),
            page_size.clamp(1, 50),
        );
        let body = self.get_json(&path, REFERER)?;
        self.require_data(body, "/x/polymer/web-space/seasons_archives_list")
    }

    /// 首页推荐兜底，对齐 BiliMusic `getRecommendedVideos`。
    pub fn top_rcmd(&mut self, ps: u32) -> Result<Value, String> {
        let body = self.get_json(
            &format!("/x/web-interface/index/top/rcmd?fresh_type=3&version=1&ps={ps}"),
            REFERER,
        )?;
        self.require_data(body, "/x/web-interface/index/top/rcmd")
    }

    pub fn favorite_folders(&mut self, mid: i64) -> Result<Value, String> {
        let body = self.get_json(
            &format!("/x/v3/fav/folder/created/list-all?up_mid={mid}"),
            REFERER,
        )?;
        self.require_data(body, "/x/v3/fav/folder/created/list-all")
    }

    pub fn favorite_list(
        &mut self,
        media_id: i64,
        page: u32,
        page_size: u32,
    ) -> Result<Value, String> {
        let body = self.get_json(
            &format!(
                "/x/v3/fav/resource/list?media_id={media_id}&pn={page}&ps={page_size}&keyword=&order=mtime&type=0&tid=0&platform=web"
            ),
            REFERER,
        )?;
        self.require_data(body, "/x/v3/fav/resource/list")
    }

    pub fn history(&mut self, max: i64, view_at: i64, page_size: u32) -> Result<Value, String> {
        let body = self.get_json(
            &format!(
                "/x/web-interface/history/cursor?max={max}&view_at={view_at}&business=&ps={page_size}"
            ),
            REFERER,
        )?;
        self.require_data(body, "/x/web-interface/history/cursor")
    }

    pub fn subtitle_list(&mut self, bvid: &str, cid: i64) -> Result<Value, String> {
        self.get_wbi(
            "/x/player/wbi/v2",
            &[
                ("bvid", bvid.into()),
                ("cid", cid.to_string()),
                ("isGaiaAvoided", "false".into()),
                ("web_location", "1315873".into()),
            ],
            &format!("{REFERER}/video/{bvid}"),
        )
    }

    pub fn fetch_json_url(&mut self, url: &str) -> Result<Value, String> {
        let body = self.get_json(url, REFERER)?;
        Ok(body)
    }
}

fn playurl_params(bvid: &str, cid: i64, avid: Option<i64>) -> Vec<(&'static str, String)> {
    let mut params = vec![
        ("cid", cid.to_string()),
        ("qn", "0".into()),
        ("fnver", "0".into()),
        ("fnval", FNVAL.into()),
        ("fourk", "1".into()),
    ];
    if !bvid.is_empty() {
        params.push(("bvid", bvid.into()));
    }
    if let Some(avid) = avid {
        params.push(("avid", avid.to_string()));
    }
    params
}

fn load_cookies(path: &Path) -> HashMap<String, String> {
    let Ok(text) = fs::read_to_string(path) else {
        return HashMap::new();
    };
    serde_json::from_str(&text).unwrap_or_default()
}

fn ensure_buvid(cookies: &mut HashMap<String, String>) {
    if cookies.contains_key("buvid3") {
        return;
    }
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    cookies.insert(
        "buvid3".into(),
        format!(
            "{:08X}-{:04X}-{:04X}-{:04X}-{:012X}infoc",
            (stamp & 0xffff_ffff) as u32,
            ((stamp >> 32) & 0xffff) as u16,
            ((stamp >> 48) & 0x0fff) as u16 | 0x4000,
            ((stamp >> 8) & 0x3fff) as u16 | 0x8000,
            (stamp >> 16) & 0xffff_ffff_ffff
        ),
    );
}

fn parse_set_cookie(header: &str) -> Option<(String, String)> {
    let pair = header.split(';').next()?.trim();
    let (name, value) = pair.split_once('=')?;
    let name = name.trim();
    if name.is_empty() {
        return None;
    }
    Some((name.to_string(), value.trim().to_string()))
}

fn map_ureq(err: ureq::Error) -> String {
    match err {
        ureq::Error::Status(code, resp) => {
            let message = resp.into_string().unwrap_or_default();
            format!("HTTP {code}: {message}")
        }
        other => other.to_string(),
    }
}

/// 东八区日期区间，供分区热门的 `time_from` / `time_to`（YYYYMMDD）。
fn ymd_range_cst(days: u32) -> (String, String) {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64
        + 8 * 3600;
    let today = now.div_euclid(86400);
    (
        unix_days_to_ymd(today - days as i64),
        unix_days_to_ymd(today),
    )
}

/// Unix 日序（1970-01-01 = 0）→ 公历日期。
/// https://howardhinnant.github.io/date_algorithms.html#civil_from_days
fn unix_days_to_ymd(z: i64) -> String {
    let z = z + 719468;
    let era = z.div_euclid(146097);
    let doe = (z - era * 146097) as u32;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    format!("{y:04}{m:02}{d:02}")
}
