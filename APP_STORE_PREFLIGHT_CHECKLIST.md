# App Store 发布前合规检查清单

> 用法：每次准备提交 App Store / TestFlight 之前跑一遍 `/appstore-preflight`。
> 状态标记：✅ 已通过 / ⚠️ 建议修但不一定阻断 / ❌ 硬阻断，大概率导致被拒或提交不了 / ⏳ 需要人工去后台确认，代码层面无法判断。

最后核对日期：2026-08-14

---

## 硬阻断项（不修大概率被拒 / 提交不了）

### 1. ✅ 审核可测试性（2026-08-13 已完成）
- **代码现状**：`iOS/LoginView.swift` + `iOS/AuthSession.swift` 是纯邮箱/密码登录，指向私有服务器
  `researchos.shuyinlab.com`，**app 内没有注册流程**。审核员打开 app 第一屏就是登录框，登不进去
  后面所有功能都看不到——跟"Sign in with Apple"无关（那条只在提供第三方 OAuth 登录时才触发，见下方
  第7项），这里单纯是"审核员需要一组能登录的凭证"。
- **已完成**：
  1. 新建了专用空账号 `shuyin.unlimited+applereview@gmail.com`（researchos user_id 37，零真实数据），
     不用暴露用户主账号里的真实笔记
  2. 已填进 App Store Connect → App Review 信息 → Sign-In Information，勾选"需要登录"，已保存
  3. 已在 Notes 里贴了英文说明（降低被 Guideline 4.2/2.3.1 当"私有小工具"卡审核的概率）
- **⚠️ 遗留小事项（不阻断，可选）**：这个账号目前是 **7 天试用期，到期 2026-08-20 10:50**，还不是永久。
  想改成永久要在 NAS 上手动跑一条 SQL（`UPDATE users SET is_legacy_free = 1 WHERE id = 37`，命令见
  `PROJECT_LOG.md` 对应条目），因为改生产数据库被系统权限规则拦截、只能用户自己跑。如果不介意，7 天
  大概率够一轮审核用，到期前重新注册个新空账号换上去也很快。

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

## 商店资料清单（App Store 产品页面素材，2026-08-14 新增）

> 这部分跟第②步"CI 能不能把包传上 TestFlight"完全独立、互不依赖——现在就能准备，不用等技术问题解决。
> TestFlight 内测阶段**不需要**这些东西，只有正式提交 App Review（走完整 App Store 上架流程）才要。

去 App Store Connect → App（vioce intake）→ 分发 → 对应版本页面填，路径就是之前截图看到的那个页面。

### 必填项（❌ 不填就提交不了）

| 项目 | 限制 | 备注 |
|---|---|---|
| App 名称 | 最多 30 字符 | 当前是 "vioce intake"，**建议顺便把拼写错误改成 "Voice Intake"** |
| 副标题（Subtitle） | 最多 30 字符 | 当前是空的，一句话说明 App 是干什么的，比如"语音笔记，自动转写整理" |
| 描述（Description） | 最多 4000 字符 | 说清楚核心功能：Apple Watch 录音 → 自动转写 → AI 整理成笔记 |
| 关键词（Keywords） | 最多 100 字符，逗号分隔 | 影响 App Store 内搜索，不会展示给用户看 |
| 支持网址（Support URL） | 必须是可访问的真实网址 | 可以用 researchos.shuyinlab.com 下的一个页面，哪怕只是一段联系方式/FAQ |
| 隐私政策网址 | 必须可访问 | 跟第③项是同一件事，两处都要填同一个 URL |
| **截图** | 至少 1 组机型，尺寸见下 | 当前完全空白（0/3 预览、0/10 截屏），是目前唯一还没做的硬阻断 |

**截图尺寸**（只需准备 App Store Connect 页面上标红 * 号的那组，其余机型 Apple 现在支持自动缩放生成，不强制每个尺寸单独传）：
- iPhone 6.9"（或页面显示要求的那个最新尺寸）：需要至少 3 张，最多 10 张，格式 PNG/JPG
- 如果 Apple Watch 部分也要求截图：另外准备一组 Watch 界面截图

### 建议项（⚠️ 不填不会被拒，但强烈建议）

| 项目 | 限制 | 备注 |
|---|---|---|
| 促销文本（Promotional Text） | 最多 170 字符 | 唯一一个"不用重新提审"就能随时改的字段，适合放"最近更新了什么" |
| 营销网址（Marketing URL） | 可选 | 没有独立官网的话可以不填 |
| App 预览视频 | 最多 3 个，单个 ≤30 秒 | 完全可选，不做不影响审核 |

### 准备方式建议

- 截图最快的做法：用模拟器跑几个核心界面（录音中、笔记列表、转写结果）截图，不需要真机；App Store Connect 对截图内容审核相对宽松，只要真实反映 App 界面即可，不需要精美的营销设计图
- 文案（名称/副标题/描述/关键词）可以先用 AI 起草中英文两版，反正后续随时能改

---

## 注意：这份清单不能替代真正的 App Review 结果

以上判断基于当前代码 + 公开的 Apple Review Guideline 常见拒绝原因，**不是 Apple 官方审核结论**。
真正提交后 Apple 仍可能给出清单之外的反馈，尤其是主观类条款（4.2 最低功能性、2.3.1 元数据准确性）。
这份清单的目的是**在提交前排除掉已知的、代码/配置层面能提前修好的硬伤**，减少无谓的拒绝-重提循环，
不代表"过了这份清单就一定通过审核"。
