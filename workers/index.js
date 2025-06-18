/**
 * 五子棋游戏的Cloudflare Worker中继服务器
 * 用于处理WebSocket连接，实现不同网络环境下的对战功能
 */

// 用于存储活跃连接的映射
const clients = new Map();
// 用于存储游戏房间信息
const rooms = new Map();

// 处理新的WebSocket连接
async function handleSession(webSocket) {
  // 生成唯一的客户端ID
  const clientId = crypto.randomUUID();
  // 存储WebSocket连接
  clients.set(clientId, webSocket);
  
  console.log(`[${clientId}] 客户端已连接`);
  
  // 定义初始化消息发送函数
  const sendInitMessage = () => {
    try {
      const initMessage = JSON.stringify({
        type: "init",
        playerId: clientId
      });
      webSocket.send(initMessage);
      console.log(`[${clientId}] 已发送初始化消息`);
    } catch (error) {
      console.error(`[${clientId}] 发送初始化消息失败:`, error);
    }
  };
  
  // 立即发送初始化消息
  sendInitMessage();
  
  // 再次发送初始化消息（确保客户端收到）
  setTimeout(sendInitMessage, 1000);
  
  // 设置WebSocket消息处理
  webSocket.addEventListener("message", async (event) => {
    try {
      // 尝试解析消息
      const message = JSON.parse(event.data);
      console.log(`[${clientId}] 收到消息:`, JSON.stringify(message));
      
      // 处理心跳消息
      if (message.type === "ping") {
        console.log(`[${clientId}] 收到ping消息`);
        webSocket.send(JSON.stringify({
          type: "pong",
          time: Date.now()
        }));
        
        // 如果客户端发送ping但可能没收到初始init消息，再次发送
        sendInitMessage();
        return;
      }
      
      // 处理关闭连接消息
      if (message.type === "close") {
        handlePlayerDisconnect(clientId);
        return;
      }
      
      // 处理游戏相关消息 - 支持多种格式
      // 格式1: { CreateRoom: { player_id: xxx } }
      if (message.CreateRoom) {
        console.log(`[${clientId}] 收到创建房间请求(格式1):`, JSON.stringify(message.CreateRoom));
        
        // 生成唯一的房间ID
        const roomId = crypto.randomUUID();
        
        // 存储房间信息
        rooms.set(roomId, {
          id: roomId,
          hostId: clientId,
          guestId: null,
          status: "waiting" // 等待另一玩家加入
        });
        
        // 记录玩家与房间的映射关系
        const playerRoom = clientId + "_room";
        clients.set(playerRoom, roomId);
        
        console.log(`[${clientId}] 创建房间 ${roomId}`);
        
        // 立即发送房间创建成功消息
        const roomCreatedMessage = JSON.stringify({
          type: "roomCreated",
          roomId: roomId
        });
        
        try {
          webSocket.send(roomCreatedMessage);
          console.log(`[${clientId}] 直接发送房间创建成功消息: ${roomCreatedMessage}`);
        } catch (error) {
          console.error(`[${clientId}] 直接发送房间创建成功消息失败:`, error);
        }
        
        // 延迟500ms后再次发送一次，确保客户端收到
        setTimeout(() => {
          try {
            if (webSocket.readyState === 1) { // 检查WebSocket是否仍然开启
              webSocket.send(roomCreatedMessage);
              console.log(`[${clientId}] 延迟再次发送房间创建成功消息: ${roomCreatedMessage}`);
            }
          } catch (error) {
            console.error(`[${clientId}] 延迟再次发送房间创建成功消息失败:`, error);
          }
        }, 500);
        
        return;
      }
      
      // 格式2: { type: "CreateRoom", player_id: xxx }
      if (message.type === "CreateRoom") {
        console.log(`[${clientId}] 收到创建房间请求(格式2):`, JSON.stringify(message));
        
        // 生成唯一的房间ID
        const roomId = crypto.randomUUID();
        
        // 存储房间信息
        rooms.set(roomId, {
          id: roomId,
          hostId: clientId,
          guestId: null,
          status: "waiting" // 等待另一玩家加入
        });
        
        // 记录玩家与房间的映射关系
        const playerRoom = clientId + "_room";
        clients.set(playerRoom, roomId);
        
        console.log(`[${clientId}] 创建房间 ${roomId}`);
        
        // 立即发送房间创建成功消息
        const roomCreatedMessage = JSON.stringify({
          type: "roomCreated",
          roomId: roomId
        });
        
        try {
          webSocket.send(roomCreatedMessage);
          console.log(`[${clientId}] 直接发送房间创建成功消息: ${roomCreatedMessage}`);
        } catch (error) {
          console.error(`[${clientId}] 直接发送房间创建成功消息失败:`, error);
        }
        
        // 延迟500ms后再次发送一次，确保客户端收到
        setTimeout(() => {
          try {
            if (webSocket.readyState === 1) { // 检查WebSocket是否仍然开启
              webSocket.send(roomCreatedMessage);
              console.log(`[${clientId}] 延迟再次发送房间创建成功消息: ${roomCreatedMessage}`);
            }
          } catch (error) {
            console.error(`[${clientId}] 延迟再次发送房间创建成功消息失败:`, error);
          }
        }, 500);
        
        return;
      }
      
      if (message.JoinRoom) {
        console.log(`[${clientId}] 收到加入房间请求:`, JSON.stringify(message.JoinRoom));
        handleJoinRoom(clientId, message.JoinRoom.room_id, webSocket);
        return;
      } 
      
      if (message.PlaceStone) {
        console.log(`[${clientId}] 收到落子请求:`, JSON.stringify(message.PlaceStone));
        handlePlaceStone(clientId, message.PlaceStone.row, message.PlaceStone.col);
        return;
      }
      
      // 如果消息格式不匹配任何已知格式，返回错误
      console.error(`[${clientId}] 未知消息格式:`, JSON.stringify(message));
      webSocket.send(JSON.stringify({
        type: "error",
        message: "未知消息格式，请检查客户端代码"
      }));
    } catch (error) {
      console.error(`[${clientId}] 处理消息错误:`, error);
      webSocket.send(JSON.stringify({
        type: "error",
        message: "消息格式错误: " + error.message
      }));
    }
  });
  
  // 处理连接关闭
  webSocket.addEventListener("close", () => {
    handlePlayerDisconnect(clientId);
  });
  
  // 处理错误
  webSocket.addEventListener("error", (error) => {
    console.error(`[${clientId}] WebSocket错误:`, error);
    handlePlayerDisconnect(clientId);
  });
}

// 处理加入房间请求
function handleJoinRoom(clientId, roomId, webSocket) {
  // 检查房间是否存在
  if (!rooms.has(roomId)) {
    console.log(`[${clientId}] 尝试加入不存在的房间 ${roomId}`);
    webSocket.send(JSON.stringify({
      type: "error",
      message: "房间不存在"
    }));
    return;
  }
  
  const room = rooms.get(roomId);
  
  // 检查房间状态
  if (room.status !== "waiting" || room.guestId !== null) {
    console.log(`[${clientId}] 尝试加入已满或游戏已开始的房间 ${roomId}`);
    webSocket.send(JSON.stringify({
      type: "error",
      message: "房间已满或游戏已开始"
    }));
    return;
  }
  
  // 更新房间信息
  room.guestId = clientId;
  room.status = "playing";
  rooms.set(roomId, room);
  
  // 记录玩家与房间的映射关系
  const playerRoom = clientId + "_room";
  clients.set(playerRoom, roomId);
  
  console.log(`[${clientId}] 加入房间 ${roomId}`);
  
  // 获取房主的WebSocket连接
  const hostSocket = clients.get(room.hostId);
  const guestSocket = webSocket;
  
  // 通知双方游戏开始
  const gameStartMessage = JSON.stringify({
    type: "gameStart",
    roomId: roomId,
    hostId: room.hostId,
    guestId: clientId
  });
  
  hostSocket.send(gameStartMessage);
  guestSocket.send(gameStartMessage);
}

// 处理落子消息
function handlePlaceStone(clientId, row, col) {
  // 获取玩家所在房间
  const playerRoom = clientId + "_room";
  const roomId = clients.get(playerRoom);
  
  if (!roomId || !rooms.has(roomId)) {
    console.log(`[${clientId}] 尝试在不存在的房间中落子`);
    return;
  }
  
  const room = rooms.get(roomId);
  
  // 验证游戏状态
  if (room.status !== "playing") {
    console.log(`[${clientId}] 尝试在非游戏中状态的房间落子`);
    return;
  }
  
  // 获取双方的WebSocket连接
  const hostSocket = clients.get(room.hostId);
  const guestSocket = room.guestId ? clients.get(room.guestId) : null;
  
  if (!hostSocket || !guestSocket) {
    console.log(`[${clientId}] 尝试在连接不完整的房间落子`);
    return;
  }
  
  // 创建落子消息
  const stoneMessage = JSON.stringify({
    type: "placeStone",
    playerId: clientId,
    row: row,
    col: col
  });
  
  // 向双方发送落子消息
  hostSocket.send(stoneMessage);
  guestSocket.send(stoneMessage);
}

// 处理玩家断开连接
function handlePlayerDisconnect(clientId) {
  console.log(`[${clientId}] 客户端断开连接`);
  
  // 检查玩家是否在房间中
  const playerRoom = clientId + "_room";
  const roomId = clients.get(playerRoom);
  
  if (roomId && rooms.has(roomId)) {
    const room = rooms.get(roomId);
    
    // 通知另一玩家断开连接
    const disconnectMessage = JSON.stringify({
      type: "playerDisconnected",
      playerId: clientId
    });
    
    if (room.hostId === clientId) {
      // 如果是房主断开，通知访客并删除房间
      if (room.guestId && clients.has(room.guestId)) {
        const guestSocket = clients.get(room.guestId);
        guestSocket.send(disconnectMessage);
        
        // 删除访客与房间的映射
        const guestRoom = room.guestId + "_room";
        clients.delete(guestRoom);
      }
      
      // 删除房间
      rooms.delete(roomId);
    } else if (room.guestId === clientId) {
      // 如果是访客断开，通知房主并更新房间状态
      if (clients.has(room.hostId)) {
        const hostSocket = clients.get(room.hostId);
        hostSocket.send(disconnectMessage);
      }
      
      // 更新房间状态为等待中
      room.guestId = null;
      room.status = "waiting";
      rooms.set(roomId, room);
    }
  }
  
  // 删除客户端连接
  clients.delete(clientId);
  clients.delete(playerRoom);
}

// 处理HTTP请求，升级为WebSocket
async function handleRequest(request) {
  const upgradeHeader = request.headers.get("Upgrade");
  
  if (upgradeHeader !== "websocket") {
    return new Response("Expected WebSocket connection", { status: 426 });
  }
  
  const webSocketPair = new WebSocketPair();
  const [client, server] = Object.values(webSocketPair);
  
  // 处理WebSocket会话
  handleSession(server);
  
  // 返回客户端WebSocket
  return new Response(null, {
    status: 101,
    webSocket: client
  });
}

// Worker入口点
export default {
  async fetch(request, env, ctx) {
    try {
      return await handleRequest(request);
    } catch (error) {
      console.error("处理请求错误:", error);
      return new Response("服务器内部错误", { status: 500 });
    }
  }
}; 