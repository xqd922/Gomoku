# 五子棋（Tauri 2）

跨平台双人五子棋，提供 Windows 桌面版和 Android ARM64 版。支持同机双人、基于 WebSocket 房间的在线双人、悔棋/重做、键盘导航和触控操作。

## 开发

```bash
bun install
bun run server
bun run tauri dev
```

`server/index.ts` 是轻量级房间服务器，不会被打进客户端安装包。在线对局的两台客户端填写相同的服务器地址和房间号即可。应用每次启动会生成新的 6 位房号；房号相当于邀请凭证，不要在公开场合复用或使用容易猜测的房号。

## Android 联机

Android 模拟器访问开发机通常填写 `ws://10.0.2.2:8787`，真机填写电脑局域网地址，例如 `ws://192.168.1.10:8787`。正式公网部署必须使用 `wss://`，并在反向代理或 WebSocket 服务端启用 TLS。正式 APK 为兼容用户明确填写的局域网 `ws://` 地址而允许明文 WebSocket；请不要在不可信网络中使用明文连接。

## Android 构建

先安装 Android Studio，并通过 SDK Manager 安装 Android SDK Platform、Platform-Tools、NDK 和 Command-line Tools，然后配置 `JAVA_HOME`、`ANDROID_HOME` 和 `NDK_HOME`。

```bash
bun run android:init
bun run android:dev
bun run android:build -- --apk --target aarch64
```

Windows 构建 Android 时，Tauri 需要创建符号链接。如果提示 `Creation symbolic link is not allowed`，请在 Windows 设置中开启“系统 → 开发者选项 → 开发人员模式”，然后重新运行构建。Linux CI runner 不受此限制。

## Windows 构建

```bash
bun run tauri build --bundles nsis
```

安装包位于 `src-tauri/target/release/bundle/nsis/`。当前仓库没有 Windows 代码签名证书，因此 NSIS 安装程序会显示未签名提示；发布前可在 CI 中接入组织自己的 Authenticode 证书。

## 验证

```bash
bun run test:unit
bun run build
bun run test:e2e
bun audit
```

E2E 覆盖 Windows、Android 竖屏/横屏、Canvas 非空与无越界、Axe 可访问性、键盘/真实触控落子、胜负、悔棋/重做、在线同步和满房重试。在线服务器也有独立的 Bun WebSocket 测试。

## GitHub Actions 与发布

`.github/workflows/build.yml` 支持手动运行 `Build installers`，以及推送 `v*` Tag 时构建并发布。工作流会先跑单元测试、构建、浏览器测试和依赖审计，再生成 Windows x64 NSIS 安装包和签名 Android `arm64-v8a` Release APK，并上传 SHA-256 校验文件。

正式 Release 资产名称为 `Gomoku_windows_x64_setup.exe` 和 `Gomoku_android_arm64_release.apk`。Android Release 使用仓库外的签名密钥；本版本证书 SHA-256 指纹为 `c5bbb8806b7034dbc4ab65652c3f89839f057d782df31ece4e8125f5792e5333`。从旧版 debug APK 升级时因签名不同，可能需要先卸载旧包再安装 Release APK；卸载会清除应用数据。
