use crate::bili::wbi;
use crate::bili::{AudioProxy, Session};
use parking_lot::Mutex;
use serde_json::Value;
use std::collections::HashSet;

static STATE: Mutex<Option<BiliState>> = Mutex::new(None);

struct BiliState {
    session: Session,
    proxy_base: String,
}

fn with_state<T>(f: impl FnOnce(&mut BiliState) -> Result<T, String>) -> Result<T, String> {
    let mut guard = STATE.lock();
    let state = guard
        .as_mut()
        .ok_or_else(|| "请先调用 bili_init".to_string())?;
    f(state)
}

pub struct BiliUser {
    pub is_login: bool,
    pub mid: i64,
    pub name: String,
    pub face: String,
    pub is_vip: bool,
}

pub struct BiliTrack {
    pub id: String,
    pub bvid: String,
    pub aid: i64,
    pub cid: i64,
    pub title: String,
    pub artist: String,
    pub album_title: String,
    pub cover_url: String,
    pub duration_sec: u32,
    pub play_count: i64,
    pub audio_url: String,
    pub page_count: u32,
    pub season_id: i64,
    pub up_mid: i64,
}

pub struct BiliSearchPage {
    pub items: Vec<BiliTrack>,
    pub page: u32,
    pub total_pages: u32,
    pub total_results: i64,
}

pub struct BiliQrCode {
    pub url: String,
    pub qrcode_key: String,
}

pub struct BiliQrPoll {
    pub code: i32,
    pub message: String,
    pub logged_in: bool,
}

pub struct BiliFavoriteFolder {
    pub id: i64,
    pub title: String,
    pub media_count: i32,
    pub cover_url: String,
}

pub struct BiliHistoryPage {
    pub tracks: Vec<BiliTrack>,
    pub has_more: bool,
    pub cursor_max: i64,
    pub cursor_view_at: i64,
}

pub struct BiliLyricLine {
    pub from_ms: u32,
    pub to_ms: u32,
    pub content: String,
}

pub struct BiliInitResult {
    pub proxy_base: String,
    pub user: BiliUser,
}

pub struct BiliAudioQuality {
    pub id: i32,
    pub label: String,
    pub detail: String,
    pub bandwidth: i64,
    pub vip_only: bool,
    pub audio_url: String,
}

pub struct BiliExtractedAudio {
    pub track: BiliTrack,
    pub qualities: Vec<BiliAudioQuality>,
    pub selected_id: i32,
}

#[flutter_rust_bridge::frb]
pub fn bili_init(cookie_dir: String) -> Result<BiliInitResult, String> {
    let session = Session::open(&cookie_dir)?;
    let mut session = session;
    let nav = session.nav().unwrap_or_else(|_| empty_nav());
    let user = map_user(&nav);
    let mut guard = STATE.lock();
    if let Some(state) = guard.as_mut() {
        state.session = session;
        return Ok(BiliInitResult {
            proxy_base: state.proxy_base.clone(),
            user,
        });
    }
    let proxy_base = match AudioProxy::start() {
        Ok(proxy) => proxy.base_url(),
        Err(err) => {
            eprintln!("melune audio proxy: {err}");
            String::new()
        }
    };
    *guard = Some(BiliState {
        session,
        proxy_base: proxy_base.clone(),
    });
    Ok(BiliInitResult { proxy_base, user })
}

#[flutter_rust_bridge::frb]
pub fn bili_proxy_url(audio_url: String) -> Result<String, String> {
    with_state(|state| {
        if state.proxy_base.is_empty() {
            return Ok(audio_url.clone());
        }
        Ok(format!(
            "{}/audio?u={}",
            state.proxy_base,
            wbi::encode_uri_component_pub(&audio_url)
        ))
    })
}

#[flutter_rust_bridge::frb]
pub fn bili_nav() -> Result<BiliUser, String> {
    with_state(|state| Ok(map_user(&state.session.nav()?)))
}

#[flutter_rust_bridge::frb]
pub fn bili_logout() -> Result<(), String> {
    with_state(|state| state.session.logout())
}

#[flutter_rust_bridge::frb]
pub fn bili_qr_generate() -> Result<BiliQrCode, String> {
    with_state(|state| {
        let data = state.session.qr_generate()?;
        Ok(BiliQrCode {
            url: json_str(&data["url"]),
            qrcode_key: json_str(&data["qrcode_key"]),
        })
    })
}

#[flutter_rust_bridge::frb]
pub fn bili_qr_poll(qrcode_key: String) -> Result<BiliQrPoll, String> {
    with_state(|state| {
        let (code, message) = state.session.qr_poll(&qrcode_key)?;
        Ok(BiliQrPoll {
            code: code as i32,
            message,
            logged_in: code == 0 && state.session.is_logged_in(),
        })
    })
}

#[flutter_rust_bridge::frb]
pub fn bili_search(keyword: String, page: u32) -> Result<BiliSearchPage, String> {
    with_state(|state| {
        let data = state.session.search_video(&keyword, page.max(1), 20)?;
        let mut items = data["result"]
            .as_array()
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .filter(|item| is_music_entry(item, false))
            .filter_map(map_search_item)
            .collect::<Vec<_>>();
        fill_page_counts(&mut state.session, &mut items);
        let total_results = as_i64(&data["numResults"]);
        let total_pages = data["numPages"].as_u64().unwrap_or(0) as u32;
        Ok(BiliSearchPage {
            items,
            page,
            total_pages: if total_pages == 0 {
                ((total_results as u32) + 19) / 20
            } else {
                total_pages
            },
            total_results,
        })
    })
}

#[flutter_rust_bridge::frb]
pub fn bili_video_pages(bvid: String) -> Result<Vec<BiliTrack>, String> {
    with_state(|state| Ok(map_video_pages(&state.session.video_view(&bvid)?)))
}

#[flutter_rust_bridge::frb]
pub fn bili_season_tracks(mid: i64, season_id: i64) -> Result<Vec<BiliTrack>, String> {
    with_state(|state| {
        let mut tracks = Vec::new();
        for page in 1..=8u32 {
            let Ok(data) = state.session.season_archives(mid, season_id, page, 30) else {
                break;
            };
            let batch = json_list(&data)
                .into_iter()
                .filter(|item| is_music_entry(item, true))
                .filter_map(map_archive_item)
                .collect::<Vec<_>>();
            let batch_len = batch.len();
            tracks.extend(batch);
            if batch_len < 30 {
                break;
            }
        }
        Ok(unique_by_bvid(tracks))
    })
}

#[flutter_rust_bridge::frb]
pub fn bili_extract_audio(
    bvid: String,
    aid: i64,
    cid: i64,
    quality_id: i32,
) -> Result<BiliExtractedAudio, String> {
    with_state(|state| {
        let mut title = String::new();
        let mut artist = String::new();
        let mut cover = String::new();
        let mut duration = 0u32;
        let mut play_count = 0i64;
        let mut resolved_aid = aid;
        let mut resolved_cid = cid;
        let mut resolved_bvid = bvid.clone();

        if !bvid.is_empty() {
            if let Ok(detail) = state.session.video_view(&bvid) {
                resolved_bvid = json_str(&detail["bvid"]);
                resolved_aid = if aid > 0 { aid } else { as_i64(&detail["aid"]) };
                resolved_cid = if cid > 0 { cid } else { as_i64(&detail["cid"]) };
                title = json_str(&detail["title"]);
                artist = json_str(&detail["owner"]["name"]);
                cover = https_url(&json_str(&detail["pic"]));
                duration = as_i64(&detail["duration"]) as u32;
                play_count = as_i64(&detail["stat"]["view"]);
            }
        }

        let play = state.session.playurl(
            &resolved_bvid,
            resolved_cid,
            Some(resolved_aid).filter(|v| *v > 0),
        )?;
        let qualities = collect_audio_qualities(&play);
        let selected = pick_audio_quality(&qualities, quality_id)
            .ok_or_else(|| "没有可用音频流".to_string())?;
        let selected_id = selected.id;
        let audio_url = selected.audio_url.clone();
        if title.is_empty() {
            title = bvid.clone();
        }
        Ok(BiliExtractedAudio {
            track: BiliTrack {
                id: track_id(&resolved_bvid, resolved_cid),
                bvid: resolved_bvid,
                aid: resolved_aid,
                cid: resolved_cid,
                album_title: title.clone(),
                title,
                artist,
                cover_url: cover,
                duration_sec: duration,
                play_count,
                audio_url,
                page_count: 1,
                season_id: 0,
                up_mid: 0,
            },
            qualities,
            selected_id,
        })
    })
}

#[flutter_rust_bridge::frb]
pub fn bili_music_rank() -> Result<Vec<BiliTrack>, String> {
    with_state(|state| {
        let mut tracks = Vec::new();
        if let Ok(data) = state.session.music_rank(40) {
            tracks.extend(
                data["list"]
                    .as_array()
                    .cloned()
                    .unwrap_or_default()
                    .into_iter()
                    .filter_map(map_music_center),
            );
        }
        if tracks.is_empty() {
            let data = state.session.ranking()?;
            tracks.extend(
                data["list"]
                    .as_array()
                    .cloned()
                    .unwrap_or_default()
                    .into_iter()
                    .filter(|item| is_music_entry(item, true))
                    .filter_map(map_archive_item),
            );
        }
        Ok(tracks)
    })
}

#[flutter_rust_bridge::frb]
pub fn bili_new_songs() -> Result<Vec<BiliTrack>, String> {
    with_state(|state| {
        // 原创音乐近 7 日按播放量，而不是新碟接口的默认序。
        let mut tracks = Vec::new();
        if let Ok(payload) = state.session.cate_hot(28, 7, 1, 30) {
            tracks = collect_hot_items(&payload);
        }
        if tracks.is_empty() {
            if let Ok(payload) = state.session.newlist_rank(28, 7, 1, 30) {
                tracks = collect_hot_items(&payload);
            }
        }
        if tracks.is_empty() {
            if let Ok(data) = state.session.new_music() {
                tracks = data["list"]
                    .as_array()
                    .cloned()
                    .unwrap_or_default()
                    .into_iter()
                    .filter_map(map_music_center)
                    .collect();
                tracks.sort_by(|a, b| b.play_count.cmp(&a.play_count));
            }
        }
        Ok(unique_by_bvid(tracks))
    })
}

fn collect_music_archives(data: &Value, assume_music: bool) -> Vec<BiliTrack> {
    json_list(data)
        .into_iter()
        .filter(|item| is_music_entry(item, assume_music))
        .filter_map(map_archive_item)
        .collect()
}

fn fill_page_counts(session: &mut crate::bili::Session, tracks: &mut [BiliTrack]) {
    for track in tracks.iter_mut() {
        if track.page_count > 1 || track.bvid.is_empty() {
            continue;
        }
        let Ok(data) = session.page_list(&track.bvid) else {
            continue;
        };
        let n = data.as_array().map(|pages| pages.len() as u32).unwrap_or(0);
        if n > 1 {
            track.page_count = n;
        }
    }
}

fn collect_hot_items(payload: &Value) -> Vec<BiliTrack> {
    json_list(payload)
        .into_iter()
        .filter(|item| is_music_entry(item, true))
        .filter_map(|item| map_archive_item(item.clone()).or_else(|| map_search_item(item)))
        .collect()
}

fn unique_by_bvid(tracks: Vec<BiliTrack>) -> Vec<BiliTrack> {
    let mut seen = HashSet::new();
    tracks
        .into_iter()
        .filter(|track| seen.insert(track.bvid.clone()))
        .collect()
}

#[flutter_rust_bridge::frb]
pub fn bili_music_region(page: u32) -> Result<Vec<BiliTrack>, String> {
    with_state(|state| {
        let page = page.max(1);
        // 音乐区近 3 日热门；旧的 newlist 只按投稿时间。
        if page == 1 {
            if let Ok(data) = state.session.ranking_region(3, 3) {
                let tracks = collect_music_archives(&data, true);
                if !tracks.is_empty() {
                    return Ok(unique_by_bvid(tracks));
                }
            }
        }
        for (cate_id, days) in [(130, 3), (31, 3)] {
            if let Ok(payload) = state.session.cate_hot(cate_id, days, page, 20) {
                let tracks = collect_hot_items(&payload);
                if !tracks.is_empty() {
                    return Ok(unique_by_bvid(tracks));
                }
            }
            if let Ok(payload) = state.session.newlist_rank(cate_id, days, page, 20) {
                let tracks = collect_hot_items(&payload);
                if !tracks.is_empty() {
                    return Ok(unique_by_bvid(tracks));
                }
            }
        }
        for data in [
            state.session.music_region(page, 20),
            state.session.newlist(3, page, 20),
        ] {
            let Ok(data) = data else {
                continue;
            };
            let mut tracks = collect_music_archives(&data, true);
            if !tracks.is_empty() {
                tracks.sort_by(|a, b| b.play_count.cmp(&a.play_count));
                return Ok(unique_by_bvid(tracks));
            }
        }
        Ok(vec![])
    })
}

#[flutter_rust_bridge::frb]
pub fn bili_music_recommend() -> Result<Vec<BiliTrack>, String> {
    with_state(|state| {
        let Ok(data) = state.session.top_rcmd(20) else {
            return Ok(vec![]);
        };
        Ok(collect_music_archives(&data, false))
    })
}

fn json_list(data: &Value) -> Vec<Value> {
    if let Some(list) = data.as_array() {
        return list.clone();
    }
    for key in ["archives", "item", "list", "result"] {
        if let Some(list) = data[key].as_array() {
            return list.clone();
        }
    }
    if let Some(list) = data["data"].as_array() {
        return list.clone();
    }
    for key in ["archives", "item", "list", "result"] {
        if let Some(list) = data["data"][key].as_array() {
            return list.clone();
        }
    }
    Vec::new()
}

#[flutter_rust_bridge::frb]
pub fn bili_favorite_folders() -> Result<Vec<BiliFavoriteFolder>, String> {
    with_state(|state| {
        let nav = state.session.nav()?;
        let mid = as_i64(&nav["mid"]);
        if mid <= 0 {
            return Ok(vec![]);
        }
        let data = state.session.favorite_folders(mid)?;
        Ok(data["list"]
            .as_array()
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .map(|item| {
                let id = as_i64(&item["id"]);
                let mut cover = https_url(&json_str(&item["cover"]));
                if let Ok(list) = state.session.favorite_list(id, 1, 1) {
                    if let Some(first) = list["medias"].as_array().and_then(|arr| arr.first()) {
                        let first_cover =
                            https_url(&first_str(&[&first["cover"], &first["pic"]]));
                        if !first_cover.is_empty() {
                            cover = first_cover;
                        }
                    }
                }
                BiliFavoriteFolder {
                    id,
                    title: json_str(&item["title"]),
                    media_count: as_i64(&item["media_count"]) as i32,
                    cover_url: cover,
                }
            })
            .collect())
    })
}

#[flutter_rust_bridge::frb]
pub fn bili_favorite_tracks(media_id: i64, page: u32) -> Result<BiliSearchPage, String> {
    with_state(|state| {
        let data = state.session.favorite_list(media_id, page.max(1), 40)?;
        let items = data["medias"]
            .as_array()
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .filter(|item| is_music_entry(item, true))
            .filter_map(map_fav_item)
            .collect::<Vec<_>>();
        Ok(BiliSearchPage {
            items,
            page,
            total_pages: if data["has_more"].as_bool().unwrap_or(false) {
                page + 1
            } else {
                page
            },
            total_results: as_i64(&data["info"]["media_count"]),
        })
    })
}

#[flutter_rust_bridge::frb]
pub fn bili_history(cursor_max: i64, cursor_view_at: i64) -> Result<BiliHistoryPage, String> {
    with_state(|state| {
        let data = state.session.history(cursor_max, cursor_view_at, 30)?;
        let tracks = data["list"]
            .as_array()
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .filter(|item| is_music_entry(item, true))
            .filter_map(map_history_item)
            .collect::<Vec<_>>();
        let next_max = as_i64(&data["cursor"]["max"]);
        let next_view = as_i64(&data["cursor"]["view_at"]);
        Ok(BiliHistoryPage {
            has_more: !tracks.is_empty() && (next_max > 0 || next_view > 0),
            tracks,
            cursor_max: next_max,
            cursor_view_at: next_view,
        })
    })
}

#[flutter_rust_bridge::frb]
pub fn bili_official_lyrics(bvid: String, cid: i64) -> Result<Vec<BiliLyricLine>, String> {
    with_state(|state| {
        let data = state.session.subtitle_list(&bvid, cid)?;
        let mut subs = data["subtitle"]["subtitles"]
            .as_array()
            .cloned()
            .unwrap_or_default();
        subs.sort_by_key(subtitle_rank);
        for sub in subs {
            let mut url = json_str(&sub["subtitle_url"]);
            if let Some(rest) = url.strip_prefix("//") {
                url = format!("https://{rest}");
            }
            if url.is_empty() {
                continue;
            }
            if let Ok(file) = state.session.fetch_json_url(&url) {
                let lines = file["body"]
                    .as_array()
                    .cloned()
                    .unwrap_or_default()
                    .into_iter()
                    .filter_map(map_lyric_line)
                    .collect::<Vec<_>>();
                if !lines.is_empty() {
                    return Ok(lines);
                }
            }
        }
        Ok(vec![])
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn bili_clean_title(title: String) -> String {
    clean_title(&title)
}

fn empty_nav() -> Value {
    serde_json::json!({
        "isLogin": false,
        "mid": 0,
        "uname": "",
        "face": "",
    })
}

fn map_user(data: &Value) -> BiliUser {
    BiliUser {
        is_login: data["isLogin"].as_bool().unwrap_or(false),
        mid: as_i64(&data["mid"]),
        name: json_str(&data["uname"]),
        face: https_url(&json_str(&data["face"])),
        is_vip: is_vip(data),
    }
}

fn is_vip(data: &Value) -> bool {
    as_i64(&data["vipStatus"]) == 1 || as_i64(&data["vip"]["status"]) == 1
}

/// B 站音乐分区 tid=3 及子区。搜索/首页只保留这些，避免混入动画、游戏等视频。
fn is_music_tid(tid: i64) -> bool {
    matches!(tid, 3 | 28 | 29 | 30 | 31 | 59 | 130 | 193 | 194 | 243 | 244)
}

/// 更接近「一首歌」的子区：原创 / 翻唱 / VOCALOID / 演奏 / MV / 电音。
fn is_song_tid(tid: i64) -> bool {
    matches!(tid, 28 | 30 | 31 | 59 | 193 | 194)
}

fn is_non_song_tid(tid: i64) -> bool {
    matches!(tid, 29 | 243 | 244)
}

fn is_music_label(text: &str) -> bool {
    const HINTS: [&str; 10] = [
        "音乐", "翻唱", "vocaloid", "utau", "演奏", "现场", "mv", "电音", "古风", "纯音乐",
    ];
    let lower = text.to_lowercase();
    HINTS.iter().any(|hint| lower.contains(hint))
}

fn duration_sec_of(item: &Value) -> u32 {
    if item["duration"].is_string() {
        let text = json_str(&item["duration"]);
        let parsed = parse_duration(&text);
        if parsed > 0 {
            return parsed;
        }
        return as_i64(&item["duration"]) as u32;
    }
    as_i64(&item["duration"]) as u32
}

fn is_rejected_song_title(text: &str) -> bool {
    const BLOCKS: [&str; 18] = [
        "直播回放",
        "直播录像",
        "演唱会",
        "全场",
        "电台",
        "播客",
        "访谈",
        "采访",
        "教程",
        "教学",
        "乐评",
        "盘点",
        "开箱",
        "纪录片",
        "晚会",
        "幕后",
        "解说",
        "reaction",
    ];
    let lower = text.to_lowercase();
    BLOCKS.iter().any(|hint| lower.contains(&hint.to_lowercase()))
}

fn looks_like_song_collection(text: &str) -> bool {
    ["歌单", "合集", "专辑", "精选", "playlist"]
        .iter()
        .any(|hint| text.to_lowercase().contains(hint))
}

fn is_song_duration(item: &Value) -> bool {
    if page_count_of(item) > 1 {
        return true;
    }
    let duration = duration_sec_of(item);
    if duration == 0 {
        return true;
    }
    // 搜索结果的 duration 往往是全部分 P 总时长。多 P 专辑会被 15 分钟上限误杀。
    duration >= 25 && duration <= 3 * 3600
}

fn is_music_entry(item: &Value, assume_music: bool) -> bool {
    if is_rejected_song_title(&json_str(&item["title"])) {
        return false;
    }
    if !is_song_duration(item) {
        return false;
    }
    let tid = first_i64(&[&item["typeid"], &item["tid"], &item["type_id"]]);
    if is_non_song_tid(tid) {
        return false;
    }
    if is_song_tid(tid) {
        return true;
    }
    if is_music_tid(tid) {
        // 音乐综合 / 父分区：短的当单曲，标题像专辑的留给分 P 判定。
        let duration = duration_sec_of(item);
        return duration == 0
            || (duration >= 30 && duration <= 10 * 60)
            || looks_like_song_collection(&json_str(&item["title"]));
    }
    if is_music_label(&json_str(&item["typename"]))
        || is_music_label(&json_str(&item["tname"]))
        || is_music_label(&json_str(&item["tag"]))
    {
        return true;
    }
    if !json_str(&item["music_id"]).is_empty() || !json_str(&item["music_title"]).is_empty() {
        return true;
    }
    if tid != 0 {
        return false;
    }
    assume_music
}

fn map_search_item(item: Value) -> Option<BiliTrack> {
    let bvid = json_str(&item["bvid"]);
    if bvid.is_empty() {
        return None;
    }
    Some(BiliTrack {
        id: bvid.clone(),
        aid: as_i64(&item["aid"]),
        cid: 0,
        title: strip_html(&json_str(&item["title"])),
        artist: json_str(&item["author"]),
        album_title: json_str(&item["ugc_season"]["title"]),
        cover_url: https_url(&json_str(&item["pic"])),
        duration_sec: parse_duration(&json_str(&item["duration"])),
        play_count: as_i64(&item["play"]),
        audio_url: String::new(),
        bvid,
        page_count: page_count_of(&item),
        season_id: season_id_of(&item),
        up_mid: up_mid_of(&item),
    })
}

fn map_video_pages(detail: &Value) -> Vec<BiliTrack> {
    let bvid = json_str(&detail["bvid"]);
    let aid = as_i64(&detail["aid"]);
    let artist = json_str(&detail["owner"]["name"]);
    let album = json_str(&detail["title"]);
    let cover = https_url(&json_str(&detail["pic"]));
    let play_count = as_i64(&detail["stat"]["view"]);
    let pages = detail["pages"].as_array().cloned().unwrap_or_default();
    if pages.len() <= 1 {
        let cid = as_i64(&detail["cid"]);
        return vec![BiliTrack {
            id: track_id(&bvid, cid),
            bvid,
            aid,
            cid,
            title: album.clone(),
            artist,
            album_title: album,
            cover_url: cover,
            duration_sec: as_i64(&detail["duration"]) as u32,
            play_count,
            audio_url: String::new(),
            page_count: 1,
            season_id: 0,
            up_mid: 0,
        }];
    }
    pages
        .into_iter()
        .enumerate()
        .map(|(i, page)| {
            let cid = as_i64(&page["cid"]);
            let page_no = page["page"].as_u64().unwrap_or((i + 1) as u64) as u32;
            let part = json_str(&page["part"]);
            BiliTrack {
                id: format!("{bvid}-p{page_no}"),
                bvid: bvid.clone(),
                aid,
                cid,
                title: if part.is_empty() {
                    format!("P{page_no}")
                } else {
                    part
                },
                artist: artist.clone(),
                album_title: album.clone(),
                cover_url: cover.clone(),
                duration_sec: as_i64(&page["duration"]) as u32,
                play_count,
                audio_url: String::new(),
                page_count: 1,
                season_id: 0,
                up_mid: 0,
            }
        })
        .collect()
}

fn map_archive_item(item: Value) -> Option<BiliTrack> {
    let bvid = json_str(&item["bvid"]);
    if bvid.is_empty() {
        return None;
    }
    let duration = if item["duration"].is_string() {
        parse_duration(&json_str(&item["duration"]))
    } else {
        as_i64(&item["duration"]) as u32
    };
    Some(BiliTrack {
        id: bvid.clone(),
        aid: as_i64(&item["aid"]).max(as_i64(&item["id"])),
        cid: as_i64(&item["cid"]),
        title: json_str(&item["title"]),
        artist: first_str(&[&item["owner"]["name"], &item["author"]]),
        album_title: String::new(),
        cover_url: https_url(&first_str(&[&item["pic"], &item["cover"]])),
        duration_sec: duration,
        play_count: first_i64(&[&item["stat"]["view"], &item["play"]]),
        audio_url: String::new(),
        bvid,
        page_count: page_count_of(&item),
        season_id: season_id_of(&item),
        up_mid: up_mid_of(&item),
    })
}

fn map_music_center(item: Value) -> Option<BiliTrack> {
    let related = &item["related_archive"];
    let bvid = first_str(&[&related["bvid"], &item["bvid"]]);
    if bvid.is_empty() {
        return None;
    }
    let aid = first_i64(&[&item["aid"], &related["aid"]]);
    let cid = first_i64(&[&item["cid"], &related["cid"]]);
    Some(BiliTrack {
        id: track_id(&bvid, cid),
        aid,
        cid,
        title: first_str(&[&item["music_title"], &item["title"]]),
        artist: json_str(&item["author"]),
        album_title: json_str(&item["album"]),
        cover_url: https_url(&json_str(&item["cover"])),
        duration_sec: as_i64(&related["duration"]) as u32,
        play_count: as_i64(&item["total_vv"]),
        audio_url: String::new(),
        bvid,
        page_count: page_count_of(related).max(page_count_of(&item)),
        season_id: season_id_of(&item),
        up_mid: up_mid_of(&item),
    })
}

fn map_fav_item(item: Value) -> Option<BiliTrack> {
    let bvid = first_str(&[&item["bvid"], &item["bv_id"]]);
    if bvid.is_empty() {
        return None;
    }
    Some(BiliTrack {
        id: format!("fav-{bvid}"),
        aid: as_i64(&item["id"]),
        cid: 0,
        title: json_str(&item["title"]),
        artist: json_str(&item["upper"]["name"]),
        album_title: String::new(),
        cover_url: https_url(&first_str(&[&item["cover"], &item["pic"]])),
        duration_sec: as_i64(&item["duration"]) as u32,
        play_count: as_i64(&item["cnt_info"]["play"]),
        audio_url: String::new(),
        bvid,
        page_count: page_count_of(&item),
        season_id: season_id_of(&item),
        up_mid: up_mid_of(&item),
    })
}

fn map_history_item(item: Value) -> Option<BiliTrack> {
    let business = json_str(&item["history"]["business"]);
    if !business.is_empty() && business != "archive" {
        return None;
    }
    let bvid = json_str(&item["history"]["bvid"]);
    if bvid.is_empty() {
        return None;
    }
    Some(BiliTrack {
        id: format!("hist-{bvid}"),
        aid: as_i64(&item["history"]["oid"]),
        cid: as_i64(&item["history"]["cid"]),
        title: json_str(&item["title"]),
        artist: json_str(&item["author_name"]),
        album_title: String::new(),
        cover_url: https_url(&json_str(&item["cover"])),
        duration_sec: as_i64(&item["duration"]) as u32,
        play_count: 0,
        audio_url: String::new(),
        bvid,
        page_count: 1,
        season_id: 0,
        up_mid: 0,
    })
}

fn map_lyric_line(item: Value) -> Option<BiliLyricLine> {
    let content = json_str(&item["content"]).trim().to_string();
    if content.is_empty() {
        return None;
    }
    let from = item["from"].as_f64().unwrap_or(0.0);
    let to = item["to"].as_f64().unwrap_or(from);
    Some(BiliLyricLine {
        from_ms: (from * 1000.0) as u32,
        to_ms: (to * 1000.0) as u32,
        content: content.replace(['♪', '♩', '♫', '♬'], "").trim().to_string(),
    })
}

fn subtitle_rank(item: &Value) -> u8 {
    let lan = format!("{} {}", json_str(&item["lan"]), json_str(&item["lan_doc"])).to_lowercase();
    if lan.contains("zh-hans") || lan.contains("简体") {
        0
    } else if lan.contains("zh") || lan.contains("中文") {
        1
    } else if lan.contains("ja") || lan.contains("日") {
        2
    } else if lan.contains("en") || lan.contains("英") {
        3
    } else {
        4
    }
}

fn collect_audio_qualities(play: &Value) -> Vec<BiliAudioQuality> {
    let mut out = Vec::new();
    let mut seen = HashSet::new();
    let flac = &play["dash"]["flac"]["audio"];
    if flac.is_object() {
        if let Some(quality) = audio_quality_from_item(flac, true, "Hi-Res无损") {
            if seen.insert(quality.id) {
                out.push(quality);
            }
        }
    }
    if let Some(streams) = play["dash"]["dolby"]["audio"].as_array() {
        for item in streams {
            if let Some(quality) = audio_quality_from_item(item, true, "杜比全景声") {
                if seen.insert(quality.id) {
                    out.push(quality);
                }
            }
        }
    }
    if let Some(streams) = play["dash"]["audio"].as_array() {
        for item in streams {
            if let Some(quality) = audio_quality_from_item(item, false, "") {
                if seen.insert(quality.id) {
                    out.push(quality);
                }
            }
        }
    }
    out.sort_by_key(|item| std::cmp::Reverse(audio_quality_rank(item)));
    out
}

fn pick_audio_quality(qualities: &[BiliAudioQuality], quality_id: i32) -> Option<&BiliAudioQuality> {
    if quality_id != 0 {
        if let Some(item) = qualities.iter().find(|item| item.id == quality_id) {
            return Some(item);
        }
    }
    qualities.first()
}

fn audio_quality_from_item(item: &Value, vip_only: bool, forced_label: &str) -> Option<BiliAudioQuality> {
    let audio_url = stream_url(item);
    if audio_url.is_empty() {
        return None;
    }
    let id = as_i64(&item["id"]);
    let bandwidth = as_i64(&item["bandwidth"]);
    let codecs = first_str(&[&item["codecs"], &item["codec"]]);
    let mime = first_str(&[&item["mimeType"], &item["mime_type"]]);
    let quality_id = if id == 0 { bandwidth.max(1) as i32 } else { id as i32 };
    Some(BiliAudioQuality {
        id: quality_id,
        label: audio_quality_label(id, bandwidth, &codecs, forced_label),
        detail: audio_quality_detail(bandwidth, &codecs, &mime),
        bandwidth,
        vip_only: vip_only || is_vip_audio(id, &codecs),
        audio_url,
    })
}

fn stream_url(item: &Value) -> String {
    let url = first_str(&[&item["baseUrl"], &item["base_url"]]);
    if !url.is_empty() {
        return url;
    }
    for key in ["backupUrl", "backup_url"] {
        if let Some(list) = item[key].as_array() {
            for value in list {
                let text = json_str(value);
                if !text.is_empty() {
                    return text;
                }
            }
        }
    }
    String::new()
}

fn is_vip_audio(id: i64, codecs: &str) -> bool {
    matches!(id, 30250 | 30251 | 30252) || {
        let lower = codecs.to_lowercase();
        lower.contains("flac") || lower.contains("ec-3") || lower.contains("eac3")
    }
}

fn audio_quality_label(id: i64, bandwidth: i64, codecs: &str, forced_label: &str) -> String {
    if !forced_label.is_empty() {
        return forced_label.to_string();
    }
    match id {
        30251 | 30252 => "Hi-Res无损".into(),
        30250 => "杜比全景声".into(),
        30280 => "192Kbps".into(),
        30232 => "132Kbps".into(),
        30216 => "64Kbps".into(),
        _ if codecs.to_lowercase().contains("flac") => "Hi-Res无损".into(),
        _ => format!("{}Kbps", (bandwidth / 1000).max(1)),
    }
}

fn audio_quality_detail(bandwidth: i64, codecs: &str, mime: &str) -> String {
    let codec = if codecs.to_lowercase().contains("flac")
        || mime.to_lowercase().contains("flac")
    {
        "FLAC"
    } else if codecs.to_lowercase().contains("ec-3")
        || codecs.to_lowercase().contains("eac3")
        || mime.to_lowercase().contains("eac3")
    {
        "杜比"
    } else if codecs.is_empty() {
        "AAC"
    } else {
        codecs.split('.').next().unwrap_or(codecs)
    };
    format!("{codec} · {}Kbps", (bandwidth / 1000).max(1))
}

fn audio_quality_rank(item: &BiliAudioQuality) -> i64 {
    if item.id == 30251 || item.id == 30252 || item.label.contains("Hi-Res") {
        2_000_000_000 + item.bandwidth
    } else if item.id == 30250 || item.label.contains("杜比") {
        1_500_000_000 + item.bandwidth
    } else {
        item.bandwidth
    }
}

fn clean_title(input: &str) -> String {
    let mut text = input.replace('\u{3000}', " ");
    for noise in [
        "官方MV",
        "官方 MV",
        "完整版",
        "高音质",
        "无损",
        "翻唱",
        "Cover",
        "cover",
        "Live",
        "LIVE",
        "4K",
        "HDR",
        "字幕版",
        "中日双语",
        "中英双语",
        "【弹唱】",
        "【填词】",
    ] {
        text = text.replace(noise, " ");
    }
    if let Some(inner) = extract_book_title(&text) {
        return inner.trim().to_string();
    }
    let mut out = String::new();
    let mut depth = 0i32;
    for ch in text.chars() {
        match ch {
            '【' | '[' | '（' | '(' => depth += 1,
            '】' | ']' | '）' | ')' => depth = (depth - 1).max(0),
            _ if depth == 0 => out.push(ch),
            _ => {}
        }
    }
    out.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn extract_book_title(text: &str) -> Option<String> {
    let start = text.find('《')?;
    let rest = &text[start + '《'.len_utf8()..];
    let end = rest.find('》')?;
    let inner = &rest[..end];
    if inner.is_empty() || inner.chars().count() > 80 {
        None
    } else {
        Some(inner.to_string())
    }
}

fn strip_html(input: &str) -> String {
    let mut out = String::new();
    let mut skipping = false;
    for ch in input.chars() {
        match ch {
            '<' => skipping = true,
            '>' => skipping = false,
            _ if !skipping => out.push(ch),
            _ => {}
        }
    }
    out.replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
}

fn https_url(url: &str) -> String {
    if url.is_empty() {
        String::new()
    } else if let Some(rest) = url.strip_prefix("//") {
        format!("https://{rest}")
    } else if let Some(rest) = url.strip_prefix("http://") {
        format!("https://{rest}")
    } else {
        url.to_string()
    }
}

fn parse_duration(text: &str) -> u32 {
    if text.is_empty() {
        return 0;
    }
    let parts = text
        .split(':')
        .filter_map(|p| p.trim().parse::<u32>().ok())
        .collect::<Vec<_>>();
    match parts.as_slice() {
        [m, s] => m * 60 + s,
        [h, m, s] => h * 3600 + m * 60 + s,
        _ => 0,
    }
}

fn track_id(bvid: &str, cid: i64) -> String {
    if cid > 0 {
        format!("{bvid}-{cid}")
    } else {
        bvid.to_string()
    }
}

fn json_str(value: &Value) -> String {
    value
        .as_str()
        .map(ToString::to_string)
        .or_else(|| value.as_i64().map(|n| n.to_string()))
        .unwrap_or_default()
}

fn as_i64(value: &Value) -> i64 {
    value
        .as_i64()
        .or_else(|| value.as_u64().map(|n| n as i64))
        .or_else(|| value.as_str().and_then(|s| s.parse().ok()))
        .or_else(|| value.as_f64().map(|n| n as i64))
        .unwrap_or(0)
}

fn first_str(values: &[&Value]) -> String {
    for value in values {
        let text = json_str(value);
        if !text.is_empty() {
            return text;
        }
    }
    String::new()
}

fn first_i64(values: &[&Value]) -> i64 {
    for value in values {
        let n = as_i64(value);
        if n != 0 {
            return n;
        }
    }
    0
}

fn page_count_of(item: &Value) -> u32 {
    if let Some(pages) = item["pages"].as_array() {
        if pages.len() > 1 {
            return pages.len() as u32;
        }
    }
    let n = first_i64(&[&item["videos"], &item["video"]["videos"]]);
    if n > 1 {
        n as u32
    } else {
        1
    }
}

fn season_id_of(item: &Value) -> i64 {
    first_i64(&[&item["ugc_season"]["id"], &item["season_id"]])
}

fn up_mid_of(item: &Value) -> i64 {
    first_i64(&[
        &item["mid"],
        &item["owner"]["mid"],
        &item["ugc_season"]["mid"],
        &item["upper"]["mid"],
    ])
}

#[cfg(test)]
mod tests {
    use super::clean_title;
    use serde_json::json;

    #[test]
    fn extracts_book_title() {
        assert_eq!(clean_title("【官方MV】《夜航》完整版"), "夜航");
    }

    #[test]
    fn strips_brackets() {
        assert_eq!(clean_title("夜航（高音质）【翻唱】"), "夜航");
    }

    #[test]
    fn keeps_music_tids() {
        assert!(super::is_music_tid(3));
        assert!(super::is_music_tid(28));
        assert!(super::is_music_tid(31));
        assert!(super::is_song_tid(28));
        assert!(super::is_song_tid(194));
        assert!(!super::is_song_tid(29));
        assert!(!super::is_music_tid(24));
        assert!(!super::is_music_tid(1));
    }

    #[test]
    fn keeps_songs_and_drops_concerts() {
        let song = json!({
            "typeid": 28,
            "title": "夜航",
            "duration": 212
        });
        let concert = json!({
            "typeid": 29,
            "title": "某乐队演唱会全场",
            "duration": 7200
        });
        let lesson = json!({
            "typeid": 244,
            "title": "吉他教学入门",
            "duration": 600
        });
        let game = json!({
            "typeid": 4,
            "title": "原神直播回放",
            "duration": 180
        });
        assert!(super::is_music_entry(&song, false));
        assert!(!super::is_music_entry(&concert, true));
        assert!(!super::is_music_entry(&lesson, true));
        assert!(!super::is_music_entry(&game, true));
        assert_eq!(super::page_count_of(&json!({"videos": 1})), 1);
        assert_eq!(super::page_count_of(&json!({"videos": "12"})), 12);
        assert_eq!(
            super::page_count_of(&json!({"pages": [{}, {}, {}]})),
            3
        );
    }

    #[test]
    fn prefers_hires_flac_over_aac() {
        let play = json!({
            "dash": {
                "audio": [{
                    "id": 30280,
                    "bandwidth": 192000,
                    "codecs": "mp4a.40.2",
                    "mimeType": "audio/mp4",
                    "baseUrl": "https://example.com/192.m4s"
                }],
                "flac": {
                    "audio": {
                        "id": 30251,
                        "bandwidth": 985000,
                        "codecs": "fLaC",
                        "mimeType": "audio/mp4",
                        "baseUrl": "https://example.com/hires.m4s"
                    }
                }
            }
        });
        let qualities = super::collect_audio_qualities(&play);
        assert_eq!(qualities.len(), 2);
        assert_eq!(qualities[0].id, 30251);
        assert_eq!(qualities[0].label, "Hi-Res无损");
        assert!(qualities[0].vip_only);
        let picked = super::pick_audio_quality(&qualities, 0).unwrap();
        assert_eq!(picked.audio_url, "https://example.com/hires.m4s");
        let fallback = super::pick_audio_quality(&qualities, 30280).unwrap();
        assert_eq!(fallback.id, 30280);
    }

    #[test]
    fn maps_vip_status() {
        let nav = json!({
            "isLogin": true,
            "mid": 1,
            "uname": "洛音",
            "face": "",
            "vipStatus": 1,
            "vip": { "status": 1 }
        });
        let user = super::map_user(&nav);
        assert!(user.is_vip);
    }
}
