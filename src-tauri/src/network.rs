use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::mpsc;
use tokio_tungstenite::accept_async;
use uuid::Uuid;
use gomoku_lib::StoneType;

type Tx = mpsc::UnboundedSender<String>;
type PeerMap = Arc<Mutex<HashMap<String, Tx>>>;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GameRoom {
    pub id: String,
    pub host_id: String,
    pub guest_id: Option<String>,
    pub status: RoomStatus,
}

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
pub enum RoomStatus {
    Waiting,    // 等待另一玩家加入
    Playing,    // 游戏中
    Finished,   // 游戏结束
}

#[derive(Debug, Serialize, Deserialize)]
pub enum GameMessage {
    // 创建房间
    CreateRoom { player_id: String },
    // 加入房间
    JoinRoom { player_id: String, room_id: String },
    // 落子
    PlaceStone { player_id: String, row: usize, col: usize },
    // 游戏状态更新
    GameUpdate { board: Vec<Vec<Option<StoneType>>>, current_player: StoneType },
    // 游戏结束
    GameOver { winner: Option<StoneType>, is_draw: bool },
    // 重新开始
    RestartGame { player_id: String },
    // 悔棋请求
    UndoRequest { player_id: String },
    // 悔棋响应
    UndoResponse { player_id: String, accepted: bool },
    // 玩家断开连接
    PlayerDisconnected { player_id: String },
    // 错误消息
    Error { message: String },
}

// 全局游戏房间状态
pub struct GameState {
    pub rooms: HashMap<String, GameRoom>,
    pub player_rooms: HashMap<String, String>, // 玩家ID -> 房间ID的映射
}

impl GameState {
    pub fn new() -> Self {
        Self {
            rooms: HashMap::new(),
            player_rooms: HashMap::new(),
        }
    }

    // 创建新房间
    pub fn create_room(&mut self, host_id: String) -> String {
        let room_id = Uuid::new_v4().to_string();
        let room = GameRoom {
            id: room_id.clone(),
            host_id: host_id.clone(),
            guest_id: None,
            status: RoomStatus::Waiting,
        };
        
        self.rooms.insert(room_id.clone(), room);
        self.player_rooms.insert(host_id, room_id.clone());
        
        room_id
    }

    // 加入房间
    pub fn join_room(&mut self, player_id: String, room_id: String) -> Result<(), String> {
        if let Some(room) = self.rooms.get_mut(&room_id) {
            if room.status == RoomStatus::Waiting && room.guest_id.is_none() {
                room.guest_id = Some(player_id.clone());
                room.status = RoomStatus::Playing;
                self.player_rooms.insert(player_id, room_id);
                Ok(())
            } else {
                Err("房间已满或游戏已开始".to_string())
            }
        } else {
            Err("房间不存在".to_string())
        }
    }

    // 获取玩家所在房间
    pub fn get_player_room(&self, player_id: &str) -> Option<&GameRoom> {
        self.player_rooms.get(player_id)
            .and_then(|room_id| self.rooms.get(room_id))
    }

    // 处理玩家断开连接
    pub fn handle_disconnect(&mut self, player_id: &str) {
        if let Some(room_id) = self.player_rooms.remove(player_id) {
            let mut should_remove_room = false;
            let mut guest_id_opt = None;
            
            // 先获取所需信息
            if let Some(room) = self.rooms.get(&room_id) {
                if room.host_id == player_id {
                    should_remove_room = true;
                    guest_id_opt = room.guest_id.clone();
                }
            }
            
            // 然后执行操作
            if should_remove_room {
                self.rooms.remove(&room_id);
                if let Some(guest_id) = guest_id_opt {
                    self.player_rooms.remove(&guest_id);
                }
            } else if let Some(room) = self.rooms.get_mut(&room_id) {
                if let Some(guest_id) = &room.guest_id {
                    if guest_id == player_id {
                        room.guest_id = None;
                        room.status = RoomStatus::Waiting;
                    }
                }
            }
        }
    }
}

// 开始WebSocket服务器
pub async fn start_ws_server(addr: &str) -> Result<(), Box<dyn std::error::Error>> {
    println!("正在初始化WebSocket服务器...");
    let state = Arc::new(Mutex::new(GameState::new()));
    let peers: PeerMap = Arc::new(Mutex::new(HashMap::new()));
    
    println!("正在绑定地址: {}", addr);
    let listener = TcpListener::bind(addr).await?;
    println!("WebSocket服务器启动在 {}", addr);

    while let Ok((stream, addr)) = listener.accept().await {
        println!("接收到新连接: {}", addr);
        tokio::spawn(handle_connection(stream, addr, Arc::clone(&peers), Arc::clone(&state)));
    }

    Ok(())
}

async fn handle_connection(stream: TcpStream, addr: SocketAddr, 
                          peers: PeerMap, state: Arc<Mutex<GameState>>) {
    match accept_async(stream).await {
        Ok(ws_stream) => {
            println!("WebSocket握手成功: {}", addr);
            let player_id = Uuid::new_v4().to_string();
            
            println!("新连接: {}, ID: {}", addr, player_id);
            
            let (tx, rx) = mpsc::unbounded_channel();
            peers.lock().unwrap().insert(player_id.clone(), tx);
            
            let (mut ws_sender, mut ws_receiver) = ws_stream.split();
            
            // 发送初始化消息，包含玩家ID
            let init_msg = serde_json::json!({
                "type": "init",
                "playerId": player_id
            }).to_string();
            
            println!("发送初始化消息: {}", init_msg);
            if let Err(e) = ws_sender.send(init_msg.into()).await {
                println!("发送初始化消息失败: {}", e);
            } else {
                println!("初始化消息发送成功");
            }
            
            // 接收消息的处理
            let receive_task = tokio::spawn(async move {
                println!("开始接收消息循环");
                while let Some(result) = ws_receiver.next().await {
                    match result {
                        Ok(msg) => {
                            if let Ok(text) = msg.to_text() {
                                println!("收到原始消息: {}", text);
                                
                                // 处理心跳消息
                                if text.contains("ping") {
                                    println!("收到心跳消息，发送pong响应");
                                    let pong_msg = serde_json::json!({
                                        "type": "pong",
                                        "time": chrono::Utc::now().timestamp()
                                    }).to_string();
                                    
                                    if let Some(tx) = peers.lock().unwrap().get(&player_id) {
                                        let _ = tx.send(pong_msg);
                                    }
                                    continue;
                                }
                                
                                // 处理正常关闭消息
                                if text.contains("close") {
                                    println!("收到关闭连接请求，准备关闭连接");
                                    break;
                                }
                                
                                // 尝试解析为GameMessage
                                match serde_json::from_str::<GameMessage>(text) {
                                    Ok(game_msg) => {
                                        println!("成功解析消息为GameMessage: {:?}", game_msg);
                                        process_message(game_msg, &player_id, &peers, &state).await;
                                    }
                                    Err(e) => {
                                        println!("解析GameMessage失败: {}, 尝试自定义解析", e);
                                        
                                        // 尝试解析为JSON对象
                                        if let Ok(json) = serde_json::from_str::<serde_json::Value>(text) {
                                            println!("成功解析为JSON: {}", json);
                                            
                                            // 检查是否包含CreateRoom字段
                                            if json.get("CreateRoom").is_some() {
                                                println!("检测到CreateRoom请求");
                                                process_message(
                                                    GameMessage::CreateRoom { player_id: player_id.clone() },
                                                    &player_id,
                                                    &peers,
                                                    &state
                                                ).await;
                                            }
                                            // 检查是否包含JoinRoom字段
                                            else if let Some(join_data) = json.get("JoinRoom") {
                                                if let Some(room_id) = join_data.get("room_id").and_then(|v| v.as_str()) {
                                                    println!("检测到JoinRoom请求，房间ID: {}", room_id);
                                                    process_message(
                                                        GameMessage::JoinRoom { 
                                                            player_id: player_id.clone(),
                                                            room_id: room_id.to_string()
                                                        },
                                                        &player_id,
                                                        &peers,
                                                        &state
                                                    ).await;
                                                }
                                            }
                                            // 检查是否包含PlaceStone字段
                                            else if let Some(stone_data) = json.get("PlaceStone") {
                                                if let (Some(row), Some(col)) = (
                                                    stone_data.get("row").and_then(|v| v.as_u64()),
                                                    stone_data.get("col").and_then(|v| v.as_u64())
                                                ) {
                                                    println!("检测到PlaceStone请求，位置: ({}, {})", row, col);
                                                    process_message(
                                                        GameMessage::PlaceStone { 
                                                            player_id: player_id.clone(),
                                                            row: row as usize,
                                                            col: col as usize
                                                        },
                                                        &player_id,
                                                        &peers,
                                                        &state
                                                    ).await;
                                                }
                                            }
                                            // 其他类型的消息
                                            else {
                                                println!("无法识别的JSON消息格式: {}", json);
                                            }
                                        } else {
                                            println!("消息不是有效的JSON: {}", text);
                                        }
                                    }
                                }
                            } else {
                                println!("收到非文本消息");
                            }
                        }
                        Err(e) => {
                            eprintln!("WebSocket错误: {}", e);
                            break;
                        }
                    }
                }
                
                println!("消息接收循环结束");
                
                // 客户端断开连接时的清理工作
                {
                    let mut state = state.lock().unwrap();
                    state.handle_disconnect(&player_id);
                    peers.lock().unwrap().remove(&player_id);
                }
                
                // 通知其他玩家此玩家已断开
                let player_disconnected = serde_json::to_string(&GameMessage::PlayerDisconnected {
                    player_id: player_id.clone(),
                }).unwrap();
                
                let peers = peers.lock().unwrap();
                for (pid, tx) in peers.iter() {
                    if pid != &player_id {
                        println!("通知玩家 {} 玩家 {} 已断开", pid, player_id);
                        let _ = tx.send(player_disconnected.clone());
                    }
                }
                
                println!("连接断开: {}", addr);
            });
            
            // 处理来自其他任务的消息，发送到WebSocket
            let send_task = tokio::spawn(async move {
                let mut rx = rx;
                while let Some(msg) = rx.recv().await {
                    ws_sender.send(msg.into()).await.unwrap_or_else(|e| {
                        eprintln!("WebSocket发送错误: {}", e);
                    });
                }
            });

            // 等待任意一个任务完成
            let mut receive_task_handle = receive_task;
            let mut send_task_handle = send_task;

            tokio::select! {
                _ = &mut receive_task_handle => send_task_handle.abort(),
                _ = &mut send_task_handle => receive_task_handle.abort(),
            }
        }
        Err(e) => {
            println!("WebSocket握手失败: {}", e);
        }
    }
}

// 处理游戏消息
async fn process_message(
    msg: GameMessage,
    player_id: &str,
    peers: &PeerMap,
    state: &Arc<Mutex<GameState>>,
) {
    println!("处理消息: {:?}", msg);
    
    match msg {
        GameMessage::CreateRoom { player_id } => {
            println!("收到创建房间请求, 玩家ID: {}", player_id);
            let room_id = {
                let mut state = state.lock().unwrap();
                state.create_room(player_id.clone())
            };
            println!("创建房间成功, 房间ID: {}", room_id);
            
            // 向创建者发送房间创建成功消息
            let response = serde_json::json!({
                "type": "roomCreated",
                "roomId": room_id
            }).to_string();
            
            println!("发送房间创建成功消息: {}", response);
            if let Some(tx) = peers.lock().unwrap().get(&player_id) {
                match tx.send(response) {
                    Ok(_) => println!("房间创建消息发送成功"),
                    Err(e) => println!("房间创建消息发送失败: {}", e),
                }
            } else {
                println!("找不到玩家 {} 的连接", player_id);
            }
        }
        
        GameMessage::JoinRoom { player_id, room_id } => {
            println!("收到加入房间请求, 玩家: {}, 房间: {}", player_id, room_id);
            let join_result = {
                let mut state = state.lock().unwrap();
                state.join_room(player_id.clone(), room_id.clone())
            };
            
            match join_result {
                Ok(()) => {
                    println!("加入房间成功");
                    // 获取房间信息
                    let room = {
                        let state = state.lock().unwrap();
                        state.get_player_room(&player_id).cloned()
                    };
                    
                    if let Some(room) = room {
                        // 通知双方游戏开始
                        let game_start_msg = serde_json::json!({
                            "type": "gameStart",
                            "roomId": room_id,
                            "hostId": room.host_id,
                            "guestId": room.guest_id,
                        }).to_string();
                        
                        println!("发送游戏开始消息: {}", game_start_msg);
                        let peers = peers.lock().unwrap();
                        if let Some(host_tx) = peers.get(&room.host_id) {
                            match host_tx.send(game_start_msg.clone()) {
                                Ok(_) => println!("发送游戏开始消息给房主成功"),
                                Err(e) => println!("发送游戏开始消息给房主失败: {}", e),
                            }
                        } else {
                            println!("找不到房主 {} 的连接", room.host_id);
                        }
                        
                        if let Some(guest_id) = room.guest_id {
                            if let Some(guest_tx) = peers.get(&guest_id) {
                                match guest_tx.send(game_start_msg) {
                                    Ok(_) => println!("发送游戏开始消息给访客成功"),
                                    Err(e) => println!("发送游戏开始消息给访客失败: {}", e),
                                }
                            } else {
                                println!("找不到访客 {} 的连接", guest_id);
                            }
                        }
                    } else {
                        println!("无法获取房间信息");
                    }
                }
                Err(err) => {
                    println!("加入房间失败: {}", err);
                    // 发送加入失败消息
                    let error_msg = serde_json::json!({
                        "type": "error",
                        "message": err
                    }).to_string();
                    
                    if let Some(tx) = peers.lock().unwrap().get(&player_id) {
                        match tx.send(error_msg) {
                            Ok(_) => println!("发送错误消息成功"),
                            Err(e) => println!("发送错误消息失败: {}", e),
                        }
                    } else {
                        println!("找不到玩家 {} 的连接", player_id);
                    }
                }
            }
        }
        
        GameMessage::PlaceStone { player_id, row, col } => {
            // 获取玩家所在房间
            let room_info = {
                let state = state.lock().unwrap();
                state.get_player_room(&player_id).cloned()
            };
            
            if let Some(room) = room_info {
                // 向房间内所有玩家转发落子消息
                let stone_msg = serde_json::json!({
                    "type": "placeStone",
                    "playerId": player_id,
                    "row": row,
                    "col": col
                }).to_string();
                
                let peers = peers.lock().unwrap();
                
                // 发送给房主
                if let Some(host_tx) = peers.get(&room.host_id) {
                    let _ = host_tx.send(stone_msg.clone());
                }
                
                // 发送给客人
                if let Some(guest_id) = room.guest_id {
                    if let Some(guest_tx) = peers.get(&guest_id) {
                        let _ = guest_tx.send(stone_msg);
                    }
                }
            }
        }
        
        GameMessage::GameUpdate { board, current_player } => {
            // 处理游戏状态更新的逻辑
        }
        
        GameMessage::GameOver { winner, is_draw } => {
            // 处理游戏结束的逻辑
        }
        
        GameMessage::RestartGame { player_id } => {
            // 处理重新开始游戏的逻辑
        }
        
        GameMessage::UndoRequest { player_id } => {
            // 处理悔棋请求的逻辑
        }
        
        GameMessage::UndoResponse { player_id, accepted } => {
            // 处理悔棋响应的逻辑
        }
        
        GameMessage::PlayerDisconnected { player_id } => {
            // 处理玩家断开连接的逻辑
        }
        
        GameMessage::Error { message } => {
            // 处理错误消息的逻辑
        }
    }
} 