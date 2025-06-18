// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
use serde::{Deserialize, Serialize};
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::net::UdpSocket;
use std::io::Read;

#[derive(Debug, Serialize, Deserialize, Clone, Copy, PartialEq)]
pub enum StoneType {
    Black,
    White,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GameResult {
    pub winner: Option<StoneType>,
    pub is_draw: bool,
}

// 网络对战相关的数据结构
#[derive(Debug, Serialize, Deserialize)]
pub struct CreateRoomResult {
    pub success: bool,
    pub room_id: String,
    pub error: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct JoinRoomResult {
    pub success: bool,
    pub room_id: Option<String>,
    pub error: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct WebRTCConfig {
    pub stun_servers: Vec<String>,
    pub turn_servers: Vec<TurnServerConfig>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TurnServerConfig {
    pub urls: String,
    pub username: String,
    pub credential: String,
}

// 默认STUN/TURN服务器配置
fn get_default_webrtc_config() -> WebRTCConfig {
    WebRTCConfig {
        stun_servers: vec![
            "stun:stun.l.google.com:19302".to_string(),
            "stun:stun1.l.google.com:19302".to_string(),
            "stun:stun2.l.google.com:19302".to_string(),
            "stun:stun3.l.google.com:19302".to_string(),
            "stun:stun4.l.google.com:19302".to_string(),
        ],
        turn_servers: vec![
            // 使用免费的TURN服务，但这些服务可能有限制或不稳定
            TurnServerConfig {
                urls: "turn:openrelay.metered.ca:80".to_string(),
                username: "openrelayproject".to_string(),
                credential: "openrelayproject".to_string(),
            },
            TurnServerConfig {
                urls: "turn:openrelay.metered.ca:443".to_string(),
                username: "openrelayproject".to_string(),
                credential: "openrelayproject".to_string(),
            },
            TurnServerConfig {
                urls: "turn:openrelay.metered.ca:443?transport=tcp".to_string(),
                username: "openrelayproject".to_string(),
                credential: "openrelayproject".to_string(),
            },
        ]
    }
}

#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

// 检查游戏胜负的API函数
#[tauri::command]
fn check_win(board: Vec<Vec<Option<StoneType>>>, row: usize, col: usize, stone: StoneType) -> bool {
    let directions = [
        (0, 1),   // 横向
        (1, 0),   // 纵向
        (1, 1),   // 左上到右下
        (1, -1),  // 右上到左下
    ];
    
    for (dr, dc) in directions.iter() {
        let mut count = 1;  // 当前位置已有一个棋子
        
        // 正向检查
        for i in 1..5 {
            let r = (row as isize) + dr * i;
            let c = (col as isize) + dc * i;
            
            if r < 0 || r >= board.len() as isize || c < 0 || c >= board[0].len() as isize {
                break;
            }
            
            if let Some(stone_at_pos) = board[r as usize][c as usize] {
                if stone_at_pos == stone {
                    count += 1;
                } else {
                    break;
                }
            } else {
                break;
            }
        }
        
        // 反向检查
        for i in 1..5 {
            let r = (row as isize) - dr * i;
            let c = (col as isize) - dc * i;
            
            if r < 0 || r >= board.len() as isize || c < 0 || c >= board[0].len() as isize {
                break;
            }
            
            if let Some(stone_at_pos) = board[r as usize][c as usize] {
                if stone_at_pos == stone {
                    count += 1;
                } else {
                    break;
                }
            } else {
                break;
            }
        }
        
        if count >= 5 {
            return true;
        }
    }
    
    false
}

// 检查是否平局的API函数
#[tauri::command]
fn check_draw(board: Vec<Vec<Option<StoneType>>>) -> bool {
    for row in &board {
        for cell in row {
            if cell.is_none() {
                return false;
            }
        }
    }
    true
}

// 获取本机IP地址
fn get_local_ip() -> Option<IpAddr> {
    // 这个技巧通过尝试连接到一个公共IP来获取本地网络接口
    // 不需要实际发送数据，只是获取本地出口IP
    match UdpSocket::bind("0.0.0.0:0") {
        Ok(socket) => {
            // 尝试连接到一个公共IP (Google的DNS服务器)
            let _ = socket.connect("8.8.8.8:80");
            match socket.local_addr() {
                Ok(addr) => Some(addr.ip()),
                Err(_) => None,
            }
        },
        Err(_) => None,
    }
}

// 尝试从外部服务获取公网IP地址
fn get_public_ip() -> Option<String> {
    println!("尝试获取公网IP...");
    let client = reqwest::blocking::Client::new();
    
    // 尝试多个获取公网IP的服务
    let ip_services = [
        "https://api.ipify.org",
        "https://ifconfig.me/ip",
        "https://icanhazip.com",
    ];
    
    for service in ip_services {
        println!("正在从 {} 获取公网IP", service);
        match client.get(service).timeout(std::time::Duration::from_secs(5)).send() {
            Ok(mut response) => {
                if response.status().is_success() {
                    let mut ip = String::new();
                    if response.read_to_string(&mut ip).is_ok() {
                        let ip = ip.trim().to_string();
                        println!("成功获取公网IP: {}", ip);
                        return Some(ip);
                    }
                }
            },
            Err(e) => {
                println!("从 {} 获取公网IP失败: {}", service, e);
            }
        }
    }
    
    println!("无法获取公网IP");
    None
}

// 获取WebSocket服务器地址
#[tauri::command]
fn get_ws_server_address() -> String {
    println!("前端请求WebSocket服务器地址");
    let port = 12345;
    
    // 首先尝试获取公网IP
    if let Some(public_ip) = get_public_ip() {
        let addr = format!("ws://{}:{}", public_ip, port);
        println!("返回公网WebSocket地址: {}", addr);
        return addr;
    }
    
    // 如果无法获取公网IP，尝试获取本机局域网IP
    let ip = get_local_ip().unwrap_or(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)));
    
    // 构建WebSocket URL
    let addr = format!("ws://{}:{}", ip, port);
    println!("返回局域网WebSocket地址: {}", addr);
    addr
}

// 获取WebRTC配置
#[tauri::command]
fn get_webrtc_config() -> WebRTCConfig {
    println!("前端请求WebRTC配置");
    get_default_webrtc_config()
}

// 获取Cloudflare Worker服务器地址
#[tauri::command]
fn get_cloudflare_worker_url() -> String {
    // 更新为实际部署的Cloudflare Worker地址
    // 注意：将http://替换为wss://以使用WebSocket
    let worker_url = "wss://gomoku-server.xqd922.workers.dev";
    println!("返回Cloudflare Worker地址: {}", worker_url);
    worker_url.to_string()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            greet,
            check_win,
            check_draw,
            get_ws_server_address,
            get_webrtc_config,
            get_cloudflare_worker_url
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
