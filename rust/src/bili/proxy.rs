use std::io::{Read, Write};
use std::net::{SocketAddr, TcpListener, TcpStream};
use std::thread;
use std::time::Duration;
use url::Url;

const UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36";
const REFERER: &str = "https://www.bilibili.com";

pub struct AudioProxy {
    pub port: u16,
    loopback: bool,
}

impl AudioProxy {
    pub fn start() -> Result<Self, String> {
        let listener = bind_listener()?;
        listener
            .set_nonblocking(false)
            .map_err(|e| format!("音频代理 set_nonblocking 失败：{e}"))?;
        let addr = listener
            .local_addr()
            .map_err(|e| format!("音频代理读取端口失败：{e}"))?;
        let port = addr.port();
        thread::Builder::new()
            .name("melune-bili-proxy".into())
            .spawn(move || accept_loop(listener))
            .map_err(|e| format!("无法启动音频代理线程：{e}"))?;
        Ok(Self {
            port,
            loopback: addr.is_ipv4(),
        })
    }

    pub fn base_url(&self) -> String {
        if self.loopback {
            format!("http://127.0.0.1:{}", self.port)
        } else {
            format!("http://[::1]:{}", self.port)
        }
    }
}

fn bind_listener() -> Result<TcpListener, String> {
    const CANDIDATES: &[&str] = &["127.0.0.1:0", "[::1]:0", "0.0.0.0:0", "[::]:0"];
    let mut errors = Vec::new();
    for addr in CANDIDATES {
        match TcpListener::bind(*addr) {
            Ok(listener) => return Ok(listener),
            Err(err) => errors.push(format!("{addr} → {err}")),
        }
    }
    Err(format!(
        "无法绑定本地音频代理：{}",
        errors.join("；")
    ))
}

fn accept_loop(listener: TcpListener) {
    loop {
        match listener.accept() {
            Ok((stream, addr)) => {
                thread::spawn(move || {
                    if let Err(err) = handle_client(stream, addr) {
                        eprintln!("melune audio proxy: {err}");
                    }
                });
            }
            Err(_) => thread::sleep(Duration::from_millis(20)),
        }
    }
}

fn handle_client(mut stream: TcpStream, _addr: SocketAddr) -> Result<(), String> {
    stream.set_read_timeout(Some(Duration::from_secs(15))).ok();
    let mut buf = Vec::new();
    let mut tmp = [0u8; 1024];
    loop {
        let n = stream.read(&mut tmp).map_err(|e| e.to_string())?;
        if n == 0 {
            return Ok(());
        }
        buf.extend_from_slice(&tmp[..n]);
        if buf.windows(4).any(|w| w == b"\r\n\r\n") {
            break;
        }
        if buf.len() > 16 * 1024 {
            return write_status(&mut stream, 413, "Request Header Too Large");
        }
    }
    let header_text = String::from_utf8_lossy(&buf);
    let mut lines = header_text.split("\r\n");
    let request_line = lines.next().unwrap_or("");
    let mut parts = request_line.split_whitespace();
    let method = parts.next().unwrap_or("");
    let path = parts.next().unwrap_or("");
    if method != "GET" && method != "HEAD" {
        return write_status(&mut stream, 405, "Method Not Allowed");
    }

    let mut range = None::<String>;
    for line in lines {
        let lower = line.to_ascii_lowercase();
        if let Some(rest) = lower.strip_prefix("range:") {
            range = Some(rest.trim().to_string());
            if let Some((_, raw)) = line.split_once(':') {
                range = Some(raw.trim().to_string());
            }
        }
    }

    let Some(url) = extract_target(path) else {
        return write_status(&mut stream, 400, "Missing audio url");
    };
    if !is_allowed_media(&url) {
        return write_status(&mut stream, 403, "Host not allowed");
    }

    let agent = super::outbound::apply(
        ureq::AgentBuilder::new()
            .timeout_connect(Duration::from_secs(30))
            .timeout_read(Duration::from_secs(300))
            .user_agent(UA),
        url.as_str(),
    )
    .build();
    let mut req = agent
        .get(url.as_str())
        .set("Referer", REFERER)
        .set("Origin", "https://www.bilibili.com");
    if let Some(range) = range.as_deref() {
        req = req.set("Range", range);
    }
    let resp = match req.call() {
        Ok(resp) => resp,
        Err(ureq::Error::Status(code, resp)) => {
            let _ = resp;
            return write_status(&mut stream, code, "Upstream error");
        }
        Err(err) => return write_status(&mut stream, 502, &err.to_string()),
    };

    let status = resp.status();
    let content_type = resp
        .header("content-type")
        .unwrap_or("application/octet-stream")
        .to_string();
    let content_length = resp.header("content-length").map(|s| s.to_string());
    let content_range = resp.header("content-range").map(|s| s.to_string());
    let accept_ranges = resp.header("accept-ranges").unwrap_or("bytes").to_string();

    let mut head = format!("HTTP/1.1 {status} OK\r\n");
    if status == 206 {
        head = "HTTP/1.1 206 Partial Content\r\n".to_string();
    }
    head.push_str(&format!("Content-Type: {content_type}\r\n"));
    head.push_str(&format!("Accept-Ranges: {accept_ranges}\r\n"));
    if let Some(len) = content_length {
        head.push_str(&format!("Content-Length: {len}\r\n"));
    }
    if let Some(cr) = content_range {
        head.push_str(&format!("Content-Range: {cr}\r\n"));
    }
    head.push_str("Access-Control-Allow-Origin: *\r\n");
    head.push_str("Connection: close\r\n\r\n");
    stream
        .write_all(head.as_bytes())
        .map_err(|e| e.to_string())?;
    if method == "HEAD" {
        return Ok(());
    }
    let mut reader = resp.into_reader();
    let mut chunk = [0u8; 16 * 1024];
    loop {
        let n = reader.read(&mut chunk).map_err(|e| e.to_string())?;
        if n == 0 {
            break;
        }
        stream.write_all(&chunk[..n]).map_err(|e| e.to_string())?;
    }
    Ok(())
}

fn extract_target(path: &str) -> Option<Url> {
    let rest = path.strip_prefix("/audio")?;
    let query = rest.strip_prefix('?').unwrap_or(rest);
    for pair in query.split('&') {
        let mut kv = pair.splitn(2, '=');
        let key = kv.next()?;
        if key != "u" {
            continue;
        }
        let value = kv.next().unwrap_or("");
        let decoded = urlencoding_decode(value)?;
        return Url::parse(&decoded).ok();
    }
    None
}

fn urlencoding_decode(input: &str) -> Option<String> {
    let bytes = url::form_urlencoded::parse(format!("u={input}").as_bytes())
        .find(|(k, _)| k == "u")
        .map(|(_, v)| v.into_owned());
    bytes
}

fn is_allowed_media(url: &Url) -> bool {
    if url.scheme() != "https" {
        return false;
    }
    let host = url.host_str().unwrap_or("").to_ascii_lowercase();
    host.ends_with("bilivideo.com")
        || host.ends_with("akamaized.net")
        || host.ends_with("hdslb.com")
        || host.contains("bilivideo")
}

fn write_status(stream: &mut TcpStream, code: u16, msg: &str) -> Result<(), String> {
    let body = msg.as_bytes();
    let head = format!(
        "HTTP/1.1 {code} Error\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
        body.len()
    );
    stream
        .write_all(head.as_bytes())
        .map_err(|e| e.to_string())?;
    stream.write_all(body).map_err(|e| e.to_string())?;
    Ok(())
}
