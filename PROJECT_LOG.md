# WatchVoiceIntake — Project Log

> Apple Watch 语音备忘录，自动转写+AI整理，直接写入 Research OS 的 AI Intake 笔记系统。Watch 只负责录音和可靠提交，不做任何本地转写/总结。

## 当前状态（最后更新：2026-08-10）

- 全部功能代码（Watch 分段录音、iPhone 段落合并+上传队列、服务器转写+AI整理+待取队列、客户端自动合并笔记）已写完、CI 编译验证通过、已推送 GitHub
- **卡在 TestFlight 首次发布**：`release.yml` 反复失败，根因见下方"踩过的坑"——当前结论是全新 Apple Developer 账号从未有过任何签名证书时，纯命令行自动签名无法可靠创建第一张 Distribution 证书，下一步要在 Xcode 图形界面里做一次性引导（登录账号 + 手动生成一次 Distribution 证书）
- 下一步：在张梦那台 Mac 上用 Xcode GUI 完成一次性证书引导，然后重新触发 `release.yml`

---

## 关键信息 / 密钥在哪

| 项目 | 位置 |
|---|---|
| GitHub 仓库 | https://github.com/pythoner0921/WatchVoiceIntake |
| 服务器 API | `https://researchos.shuyinlab.com`（同一个 Research OS 主项目，见 `server/watch.js`） |
| Apple Developer Team ID / Issuer ID / API Key | GitHub 仓库 Settings → Secrets → Actions，名字见下表（**不要把 `.p8` 内容贴进对话或提交到仓库**） |
| 远程开发用 Mac | 张梦的 MacBook Air，通过 Tailscale(100.100.154.55) SSH 访问，用户名 `zhaomeng`；SSH 私钥在本机 `D:\partition3\Services\ssh_keys\id_ed25519_zhaomeng_mac` |
| GitHub push 权限 | 本机 `gh auth status` 已登录 `pythoner0921`，走 `gh`/git https，Mac 上没配过、不能直接 push |

### GitHub Secrets 清单（Settings → Secrets and variables → Actions）

| Secret 名字 | 内容 | 备注 |
|---|---|---|
| `APPLE_TEAM_ID` | Apple Developer Team ID | Developer 后台 Membership 页面 |
| `APPSTORE_ISSURE_ID` | App Store Connect API Issuer ID | **名字打错了(ISSURE 少个字母)，代码里故意跟着用这个错的名字**，不要"修正"它，除非同时把 secret 也重建 |
| `APPSTORE_KEY_ID` | App Store Connect API Key ID | 对应下面这把 Key |
| `APPSTORE_PRIVATE_KEY` | `.p8` 私钥完整内容 | **必须是 Admin 角色的 Key**，App Manager 角色权限不够（见踩坑记录） |

---

## 时间线

### 2026-08-09 — Phase 1：项目搭建 + 云端编译

- 建仓库，XcodeGen + GitHub Actions macOS runner 做免费云端编译验证（不需要本地 Mac）
- 踩坑：Watch target 用了过时的 `application.watchapp2` 类型（watchOS 7 之前的双 target 打包格式），跟 watchOS 10+ 部署目标搭配导致 XcodeGen 生成重复输出路径，`xcodebuild` 报 "Multiple commands produce"。**修法**：改成 watchOS 9+ 的标准单 target `application` 类型
- Phase 1 完成：CI 编译通过（未签名）

### 2026-08-09 — 远程开发环境搭建

- 用户人在日本，Mac 只有一台旧 2014 MacBook Pro（跑不动现代 Xcode），改用女朋友张梦在中国的新 Mac 远程开发
- 踩坑排查过程（详见对话历史，不赘述）：VNC/屏幕共享黑屏 → 换 AnyDesk 解决远程桌面；SSH 密钥登录配置成功，密钥存在本机 `D:\partition3\Services\ssh_keys\`（不要存在项目仓库或临时 scratchpad 目录，之前一度存错地方）
- **规则**：本项目所有 SSH 命令行工作交给 Claude 做，图形界面操作（登录 Apple ID、Watch 配对信任、点击物理按钮）需要用户/张梦配合远程桌面完成

### 2026-08-09 — Phase 2/3：本地录音 + 多段录音 + Watch→iPhone 传输

- 基础录音测试通过（模拟器）
- 产品需求变更：单次录音改成"暂停/继续说/完成"三态，允许分段录音、最后合并成一条笔记再上传（避免半句话就建碎笔记）
- **重大技术坑**：`AVAssetExportSession`（用于合并多段音频）在 watchOS 上**整体不可用**——所有 `AVAssetExportPreset*` 常量在 SDK 里都标了 `API_UNAVAILABLE(watchos)`，跟 watchOS 部署目标版本无关，watchOS 11 也一样。**解法**：把合并逻辑从 Watch 移到 iPhone（`PhoneConnectivityService`），iOS 端完整支持 `AVAssetExportSession`；Watch 只管录制+发送有序段落（带 `sessionId`/`sequenceIndex`/`segmentCount` 元数据），iPhone 收齐后再合并
- **模拟器已知限制**：iOS/watchOS 模拟器之间 `WCSession.transferFile`（文件传输）经常静默失败，多次测试证实——这是 Apple 模拟器本身的限制，不是代码问题，**不值得花时间排查**，留到真机测试验证

### 2026-08-09 — Phase 4：服务器端接入 AI Intake

- 研究了 research-os 现有的会议录音异步处理管线（`server/meetings.js`：上传→AssemblyAI转写→AI总结→写入 pending 队列→客户端拉取合并），照这个成熟模式实现 Watch 语音管线，而不是重新发明
- 新增 `server/watch.js`：`POST /api/watch/voice`——转写(复用 `handleTranscribe` 抽出的 `transcribeAudioBuffer`) → AI整理成笔记(仿照 `handleCasualChatSummarize` 的"永远直接出结果不追问"模式，新建 `organizeWatchTranscript`) → 存入新表 `watch_notes_pending`
- 新表 `watch_notes_pending`：跟 `evolver_drafts`/`meeting_updates` 一样的"服务器只排队、客户端自己拉取合并进 `ros:memos`"规则，服务器永远不直接写 `ros:memos`
- `recordingId`（Watch 生成的 UUID）直接做主键，实现幂等——同一段录音重传不会建重复笔记
- 客户端 `src/pages/Memo.jsx` 新增 `pullWatchNotes()`，App 打开时自动拉取合并，**全程不经过人工确认**（这是产品要求：Watch 笔记要全自动，不像网页版 AI Intake 那样需要检查草稿再点创建）

### 2026-08-09/10 — Phase 4 续：iOS 上传队列 + 登录

- 新增 `iOS/UploadQueueManager.swift`：合并好的录音持久化存到 `Documents/PendingUploads`（不是 tmp，重启不丢），失败自动重试，`recordingId` 做幂等键防重复上传
- 新增 `iOS/AuthSession.swift`：Keychain 存 JWT（30天有效期，跟服务器 `authRequired` 中间件一致），`iOS/LoginView.swift` 提供登录界面
- **踩坑（一次真实的疏忽）**：写完 `UploadQueueManager` 后忘了把 `PhoneConnectivityService.swift` 里的占位注释换成真正的 `UploadQueueManager.shared.enqueue(...)` 调用，导致代码"看起来完整"但合并完的录音其实从没进过上传队列。**教训**：改动分布在多个文件时，改完要搜索确认所有引用点都真的接上了，不能只看单个文件编译通过就当作完成
- **踩坑（Windows/Mac 双边编辑同步问题）**：这个项目同时在张梦的 Mac（跑 SSH 命令做真正的编译验证）和本地 Windows（`D:\partition3\Boring_buss\WatchVoiceIntake`，方便用 `gh` push）各有一份工作副本，多次出现"改了一边忘了同步另一边"、"git commit 作者身份在 Mac 上被自动填成张梦的本地账户"等问题。**教训**：以 Mac 上跑通编译验证的那份为准，push 前用 `git bundle` 把 Mac 的精确历史带到 Windows 来推送，不要凭记忆在两边分别重写同一个改动
- **踩坑（Shell 转义）**：早期用 SSH 命令套 heredoc 写 Swift 文件时，Swift 代码里的 `$0`（闭包简写参数）被外层 SSH 双引号命令做了 shell 变量展开，写进文件的内容变成了乱码（`/usr/bin/bash`）。**教训**：往远程写含有 `$`、反引号等字符的代码文件，优先用 `scp` 直接传文件或 base64 编码传输，不要用双引号包裹的 heredoc

### 2026-08-10 — Apple Developer 账号 + App Store Connect 设置

- 用户完成：注册 Apple Developer Program（$99/年，Individual）、注册两个 App ID（`com.shuyinlab.watchvoiceintake` / `.watchkitapp`）、App Store Connect 建 App 记录
- 新增 `.github/workflows/release.yml`：手动触发（`workflow_dispatch`），用 App Store Connect API Key 自动签名打包上传 TestFlight，理论上不需要手动导出 `.p12`/`.mobileprovision`

### 2026-08-10 — release.yml 反复失败排查（还在进行中）

这一段完整记下来，避免以后重新踩：

1. **Secret 名字打错**：GitHub Secret 建成了 `APPSTORE_ISSURE_ID`（拼写错误），代码引用的是 `APPSTORE_ISSUER_ID`，两者对不上导致值传空。**改代码去匹配已经打错的 secret 名字**（不要求用户重建），这是故意的，见上面"关键信息"表格
2. **`ExportOptions.plist` 的 `method` 值写错**：一开始写的是 `app-store-connect`，这不是合法值；改成 `app-store`
3. **Archive 产物完全没签名**：`project.yml` 项目级设置里 `CODE_SIGNING_ALLOWED: NO` / `CODE_SIGNING_REQUIRED: NO`（Phase 1 为了让免签名云编译能过而设的），Archive 步骤命令行只覆盖了 `CODE_SIGN_STYLE=Automatic`，没覆盖这两个开关，导致 Archive 产物完全未签名，Export 阶段自然找不到任何可用的分发方式。加上 `CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES` 覆盖后，问题往前推进了一层，暴露出下面第4条真正的核心问题
4. **核心问题（未解决）**：`xcodebuild archive` 报错 "Your team has no devices from which to generate a provisioning profile"，本质是 Xcode 自动签名在执行 Archive 动作时，即便最终目标是 App Store 分发，内部依然会先尝试生成一个"开发用"签名产物作为中间步骤，而**开发类描述文件强制要求账号里至少注册过一台设备**——全新账号一台设备都没注册过，卡死在这一步
   - 试过 `CODE_SIGN_IDENTITY="Apple Distribution"` 强制指定发布签名身份 → 报错变成"自动签名判定为开发签名，但你又手动指定了发布签名身份，两者冲突"，说明这个方向是错的，回退了
   - 试过把 API Key 角色从 App Manager 换成 Admin → 没有解决这个具体错误（但 Admin 权限本身是必须的，证书管理类操作 App Manager 角色确实没权限，这个改动保留）
   - 查资料确认：这是社区广泛记录的已知限制——**全新团队从未有过任何证书时，纯命令行 + API Key 的自动签名机制无法可靠地"平地起高楼"创建第一张证书**，标准解法是先用 Xcode 图形界面登录账号、手动触发一次证书生成（这一步走的是 Xcode 自己更完整的账号管理流程，不是纯 CLI），之后自动化签名才能可靠接手
   - **下一步待执行**：在张梦的 Mac 上打开 Xcode → Settings → Accounts → 登录用户的 Apple Developer 账号 → 选中 Team → Manage Certificates → "+" → Apple Distribution，生成一次证书。做完后重新触发 `release.yml`

**给以后的教训（用户明确要求记住）**：这次反复失败的根本原因是**没有先调研 Apple 官方/社区关于"全新账号 + CI 纯命令行签名"的标准流程，就直接凭经验试**，浪费了很多轮。以后遇到"看起来是常见操作但反复报错"的情况，先搜索确认业界标准做法，再动手改，不要每次报错都靠猜测下一个修复点。
