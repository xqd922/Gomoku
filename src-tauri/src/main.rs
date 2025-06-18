// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

// 添加network模块
mod network;

use std::net::TcpListener;

#[tokio::main]
async fn main() {
    // 检查端口是否可用
    let ws_port = 12345;
    // 使用 0.0.0.0 绑定所有接口，这样更容易被客户端连接
    let ws_addr = format!("0.0.0.0:{}", ws_port);
    
    println!("正在尝试启动WebSocket服务器在 {}", ws_addr);
    
    // 尝试绑定端口以检查是否可用
    match TcpListener::bind(&ws_addr) {
        Ok(_) => {
            println!("端口 {} 可用，将启动WebSocket服务器", ws_port);
            // 在新线程中启动WebSocket服务器
            tokio::spawn(async move {
                println!("开始启动WebSocket服务器...");
                if let Err(e) = network::start_ws_server(&ws_addr).await {
                    eprintln!("WebSocket服务器启动失败: {}", e);
                } else {
                    println!("WebSocket服务器启动成功！");
                }
            });
        },
        Err(e) => {
            eprintln!("端口 {} 不可用: {}，网络对战功能可能无法使用", ws_port, e);
            // 可以尝试其他端口...
        }
    }

    // 启动Tauri应用
    println!("正在启动Tauri应用...");
    gomoku_lib::run()
}
