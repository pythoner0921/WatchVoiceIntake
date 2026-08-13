# App Store 发布前合规检查清单

> 用法：每次准备提交 App Store / TestFlight 之前跑一遍 `/appstore-preflight`。
> 状态标记：✅ 已通过 / ⚠️ 建议修但不一定阻断 / ❌ 硬阻断，大概率导致被拒或提交不了 / ⏳ 需要人工去后台确认，代码层面无法判断。

最后核对日期：2026-08-13

---

## 硬阻断项（不修大概率被拒 / 提交不了）

### 1. ⏳ 审核可测试性 — App Review Information 里是否填了测试账号（纯后台操作，代码帮不上忙）
- **代码现状**：`iOS/LoginView.swift` + `iOS/AuthSession.swift` 是纯邮箱/密码登录，指向私有服务器
  `researchos.shuyinlab.com`，**app 内没有注册流程**。审核员打开 app 第一屏就是登录框，登不进去
  后面所有功能都看不到。
- **风险**：Apple Guideline 2.1 (Information Needed) 最常见的拒绝原因之一。**跟"Sign in with Apple"
  无关**（那条只在提供第三方 OAuth 登录时才触发，见下方第7项），这里是单纯的"审核员需要一组能登录
  的凭证"。
- **要做的事**（提交前手动操作，5分钟）：
  1. 打开 App Store Connect → 你的 App → App Review 信息 → "Sign-In Information"
  2. 勾选"需要登录"，填一组邮箱+密码——可以直接用你自己的真实账号（只有你自己用，审核员登进去看
     到你的真实数据也无妨），介意的话可以在 researchos 网页端另建一个空的测试子账号
  3. 建议在 App Review Notes 里补一句英文说明，降低被 Guideline 4.2(最低功能性)/2.3.1 卡的概率，
     比如："This app is a personal voice-note capture client that connects to the user's own
     account on a note-taking backend the developer also built and operates. Functionality:
     record on Apple Watch → auto-transcribe → AI-organized notes, synced to the account."

### 2. ✅ 账号删除入口（2026-08-13 已修复）
- **修复内容**：`iOS/AuthSession.swift` 新增 `deleteAccount()`，调用 research-os 后端**已经存在**的
  `DELETE /api/account`（`server/index.js:363`，本来就要求 `confirm: true`、会挡掉有活跃订阅的账号，
  这次没有新写任何删除数据的逻辑，只是把已有的、已经带防护的接口接到客户端）。
  `iOS/AccountSettingsView.swift` 新增账号设置页（`ContentView` 右上角人形图标进入），提供"退出登录"
  和"删除账号"（destructive 按钮 + 二次确认 alert，文案明确"无法撤销"）。
- **状态**：代码已写完，**还没有在真机/模拟器实测过**（本机是 Windows，走远程 Mac 编译验证），下次
  联调 CI/远程 Mac 时要验证一遍删除流程走通、以及触发 `active_subscription_exists` 时的报错文案正常。

---

## 建议修项

### 3. ⏳ 隐私政策 URL — App Store Connect 必填项
- **代码现状**：仓库里没有找到任何隐私政策文件或页面（`Grep "privacy|隐私"` 全项目无匹配）。
- **要做的事**：App Store Connect 提交时"App Privacy"页面强制要求一个可访问的隐私政策 URL。
  可以是 researchos.shuyinlab.com 下的一个静态页面，几句话说明：收集哪些数据（录音、邮箱）、
  用途（转写整理笔记）、是否第三方共享（AssemblyAI 做转写，需要如实提一句）。

### 4. ⏳ App Privacy 营养标签（后台勾选项，需要如实对应代码行为）
- **代码里实际收集/上传的数据**：
  - 录音音频（`iOS/PhoneConnectivityService.swift` 合并后经 `UploadQueueManager` 上传）
  - 邮箱 + 密码（登录用，服务器换成 JWT，`AuthSession.swift`）
  - 转写文本 + AI 整理后的笔记内容（`server/watch.js` 处理，落库到 `watch_notes_pending`）
- **要做的事**：App Store Connect → App Privacy 页面，勾选 "Audio Data"、"User ID / Email
  Address"，且要标注"Linked to your identity"（是，因为账号系统关联）。**不勾或勾错比"收集数据
  本身"更容易被拒**——App Review 会实际抓包比对你申报的和 app 实际传的是否一致。

### 5. ⏳ Export Compliance 加密声明
- **代码现状**：所有网络请求走 `https://researchos.shuyinlab.com`（标准 HTTPS，`URLSession`
  默认走 ATS），没有自定义加密算法。
- **要做的事**：提交时会被问"Does your app use encryption?"，标准 HTTPS-only 的情况下选择
  "仅使用 Apple 提供的标准加密"（可豁免出口合规文件），不要选"是，且需要额外合规文件"，
  否则会卡在这一步。

---

## 已通过项

### 6. ✅ 麦克风权限说明文案
- `project.yml` 里两个 target 都设置了 `NSMicrophoneUsageDescription`，中文说明清楚
  （"用于录制语音笔记并转写整理——录音只在你主动点击开始时进行"），符合 Apple 对权限描述
  "具体说明用途"的要求，不用改。

### 7. ✅ Sign in with Apple（不适用，无需处理）
- 项目是纯邮箱/密码登录，**没有**接入 Google/Facebook 等第三方登录，所以 Guideline 4.8
  的"第三方登录必须同时提供 Sign in with Apple"不适用，这条可以跳过。

### 8. ✅ 数据传输加密
- 全部走 HTTPS，没有明文传输，无需额外处理（对应第5项的申报选项）。

---

## 注意：这份清单不能替代真正的 App Review 结果

以上判断基于当前代码 + 公开的 Apple Review Guideline 常见拒绝原因，**不是 Apple 官方审核结论**。
真正提交后 Apple 仍可能给出清单之外的反馈，尤其是主观类条款（4.2 最低功能性、2.3.1 元数据准确性）。
这份清单的目的是**在提交前排除掉已知的、代码/配置层面能提前修好的硬伤**，减少无谓的拒绝-重提循环，
不代表"过了这份清单就一定通过审核"。
