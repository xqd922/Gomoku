# 五子棋（Tauri 2）

支持 Windows 桌面、Android、同机双人和房间式在线双人对战。

## 开发

```bash
bun install
bun run server
bun run tauri dev
```

第二位玩家可启动另一个客户端，选择“在线房间”，填写相同服务器地址和房间号。

## Android

先安装 Android Studio，并通过 SDK Manager 安装 Android SDK Platform、Platform-Tools、NDK 和 Command-line Tools，然后配置 `JAVA_HOME`、`ANDROID_HOME` 和 `NDK_HOME`。

```bash
bun run android:init
bun run android:dev
bun run android:build
```

Android 模拟器访问电脑本机服务通常填写 `ws://10.0.2.2:8787`；真机填写电脑局域网地址，例如 `ws://192.168.1.10:8787`。正式发布应使用公网 `wss://` 服务。

Windows 构建 Android 时，Tauri 需要创建符号链接。如果提示 `Creation symbolic link is not allowed`，请在 Windows 设置中开启“系统 → 开发者选项 → 开发人员模式”，然后重新运行 `bun run android:build -- --debug`。

## 验证

```bash
bun test
bun run build
bun run tauri build
```
