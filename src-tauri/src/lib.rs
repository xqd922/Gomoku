// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
use serde::{Deserialize, Serialize};

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

// 获取WebSocket服务器地址
#[tauri::command]
fn get_ws_server_address() -> String {
    println!("前端请求WebSocket服务器地址");
    // 使用localhost代替127.0.0.1，可能对某些环境更友好
    let addr = "ws://localhost:12345";
    println!("返回WebSocket地址: {}", addr);
    addr.to_string()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            greet,
            check_win,
            check_draw,
            get_ws_server_address
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
