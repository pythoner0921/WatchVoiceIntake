# WatchVoiceIntake — Project Log

> Apple Watch 语音备忘录，自动转写+AI整理，直接写入 Research OS 的 AI Intake 笔记系统。Watch 只负责录音和可靠提交，不做任何本地转写/总结。

## 当前状态（最后更新：2026-08-14）

- 🎉 **CI 第一次真正打出了签名正确的 .ipa 并成功导出**——`fastlane/Fastfile`/`project.yml` 里连续 8 个真实 bug 全部修完（`api_key` 未传、描述文件未下载、`CODE_SIGNING_ALLOWED` 被关、`DEVELOPMENT_TEAM` 未传、archive 的 `ApplicationProperties` 字典缺失、`upload_to_testflight` 参数名错误、App 图标从未配置、`CFBundleIconName`/加密合规声明缺失），跟"Apple 账号权限被拒绝"这个此前认定的根因完全无关——账号、付费团队、证书、描述文件、开发者协议逐项核实过都没问题。详见下方 2026-08-14 条目，完整排查过程。
- 🚧 **卡在最后一步：上传 TestFlight 时被服务器无理由拒绝**（`Validation failed. n/a`，`STATE_ERROR.VALIDATION_ERROR`）——两条独立上传路径（`altool`、`xcodebuild -exportArchive destination:upload`）都在同一阶段被拒，报错完全一致且没有具体原因，客户端能查的手段（图标、Info.plist 必需字段、认证方式）都已排除。判断已经到了只有 Apple 后台日志能看到真实原因的地步。
- ✅ **已通过 App Store Connect 网页版"联系我们"，在原工单 `20000133548930` 下发了新邮件**，附上 3 次失败的请求 ID（`14126c9f-...`、`ce81eb14-...`、`49fe6f62-...`）和已排除因素清单，等 Apple 回复。
- ⚠️ 项目前途更不明朗：research-os 侧的 Plan B（VoiceRecordPro + Google Drive 同步，见 `research-os/PROJECT_LOG.md`）**已端到端验证通过并投入日常使用**，仍两条线并行、不主动下线本项目。
- ✅ 新增 `/appstore-preflight` skill + `APP_STORE_PREFLIGHT_CHECKLIST.md`，两项硬阻断都已完成：账号删除入口（代码已修完+编译验证通过）+ 审核测试账号（已建号+已填进 App Store Connect 并保存）
- ⚠️ **审核测试账号权限状态**：`shuyin.unlimited+applereview@gmail.com`（user_id 37）目前是 **7 天试用期，到期 2026-08-20 10:50**，不是永久，非必须修复
- 下一步：纯等 Apple 邮件回复（这次问的是服务器端校验拒绝的具体原因，不是账号权限）。下次会话打开先问用户"Apple 邮件回了没有"。

---

## 关键信息 / 密钥在哪

| 项目 | 位置 |
|---|---|
| GitHub 仓库 | https://github.com/pythoner0921/WatchVoiceIntake |
| 服务器 API | `https://researchos.shuyinlab.com`（同一个 Research OS 主项目，见 `server/watch.js`） |
| Apple Developer 付费 Team ID | `28UXGDR5KC`（Apple Developer Program，个人身份，2027-08-11 续订，2026-08-13 已核实并确认写入 `APPLE_TEAM_ID` secret） |
| Apple 工单 | 案例编号 `20000133548930`，账号 `2415476719@qq.com`，最新一次用户回复见 `APPLE_SUPPORT_REPLY_2026-08-13.md` |
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

### 2026-08-14（续二）— 排除"传错 App"，找到真正上传阻断点并邮件求助 Apple

接续上一条的"software type Undefined"疑点：

- 用浏览器直接登录 App Store Connect 核实，发现确实有个多余的顶层 App 记录 "WatchVoiceIntakeWatch"（Apple ID 6799967312，Bundle ID `com.shuyinlab.watchvoiceintake.watchkitapp`）——按项目架构（Watch 是内嵌单一 target app，不该有独立 App Store 提交流程），这个记录本不该存在，但它的 TestFlight 页面显示"无构建版本"，说明从未真正接收过上传
- 把 `upload_to_testflight` 的 `app_identifier` 换成精确的数字 `apple_id: "6799812210"`（vioce intake 的真实 Apple ID）避免字符串前缀匹配歧义，重跑——**报错完全不变**，证明"传错 App"这个猜测是错的，两次都精确打在 vioce intake 上
- altool 报错文本里写着"the call to the **altool** completed with..."，确认走的是 Apple 已标记废弃的老工具，搜到多个开发者在官方论坛报告过同一个无解的 bug；换用 Xcode 13+ 支持的新路径——`exportOptionsPlist` 里 `destination: upload`，让 `xcodebuild -exportArchive` 直接完成导出+上传，跳过 altool/pilot——**这次真的连上了 Apple 服务器**（`ContentDelivery.log` 显示走到了"Sending SPI analysis"阶段），但在校验阶段收到 `409 STATE_ERROR.VALIDATION_ERROR`，除了一个请求 ID 什么原因都不给
- 顺着这条线查：项目里 `iOS/`、`Watch/` 目录下**从来没有过 `.xcassets`/`AppIcon`**，这是 App Store 上传校验最常见的"无理由拒绝"诱因之一。生成了一个占位图标（1024×1024，Xcode 现代"单尺寸图标"格式），接入 `project.yml` 的 `ASSETCATALOG_COMPILER_APPICON_NAME` —— confirmed 图标真的编译进包了，但**上传校验报错依然一字不差**
- 中途踩了个岔路：为了排除"Xcode 版本导致 Unknown Distribution Error"的假设，之前把 CI 固定在 Xcode 16.2，这次因为要编译 watchOS 图标资源，16.2 版本机器上缺配套的模拟器运行时，报 `No simulator runtime version ... available`——改回"自动选最新已装 Xcode"解决，16.2 那次固定纯粹是已经排除掉的诊断分支，不需要再保留
- 继续加 `CFBundleIconName: AppIcon`（现代资产目录图标必须搭配这个 Info.plist 字段，否则常见静默失败）和 `ITSAppUsesNonExemptEncryption: false`（加密合规声明），重跑——**上传校验报错还是一字不差**，只是请求 ID 换了一个
- 试过用 `xcrun altool --validate-app` 这个更老的校验专用命令找更详细的报错，两种参数写法都返回"无法确定平台"这个和内容无关的报错，确认这个子命令本身在当前 altool 版本下已经不可靠，放弃这条路
- **结论**：图标、`CFBundleIconName`、加密合规声明、账号权限、team、证书、描述文件、认证方式全部核实/修复过，两条完全独立的上传通道（`altool`、`ContentDelivery`）都在同一阶段被拒且报错零细节——已经超出客户端能诊断的范围，只有 Apple 后台日志能看到真实原因
- 直接在浏览器里操作 App Store Connect 网页版"联系我们"，在原工单 `20000133548930` 下发了一封新邮件（不是重开新工单），说明已排除的所有因素、附上 3 次失败请求 ID：`14126c9f-28ee-4e43-8c75-a3db7de580b6`、`ce81eb14-23f6-463e-89bf-cdf08332962c`、`49fe6f62-5c47-4801-b42e-3c5c2f270ccc`，请 Apple 从后台查具体原因

### 2026-08-14（续）— 一路修到 CI 第一次产出真正签名的 .ipa，卡在 App Store Connect 的 App 记录上

接着上面那条继续排查，`api_key` 修复推送后仍失败，往下又连续挖出并修复了 5 个真实 bug（每个都验证过：改一处、推送、触发 CI、看结果，再改下一处）：

1. `build_app` 根本没有 `api_key` 这个参数（fastlane 报错列出了完整可用参数列表，确认没有）——改用 `get_provisioning_profile`（`sigh`）在打包前显式下载安装两个 App Store 描述文件
2. 描述文件下载成功、Archive 仍成功，Export 报错原样不变——查 `project.yml` 发现全局 `CODE_SIGNING_ALLOWED: NO` 从来没有被 release.yml 真正覆盖回 YES（project.yml 里其实早就留了预判这件事的注释），也就是说**所有历史失败的 Archive 从来没有真正签过名**，一直"假装成功"
3. 打开签名后报标准错误"requires a development team"——`project.yml` 只设了 `PROVISIONING_PROFILE_SPECIFIER`，没设 `DEVELOPMENT_TEAM`，`export_team_id` 只影响导出不影响归档，补上
4. 真正开始签名后，Export 依然是同一个 `Unknown Distribution Error`——换了 Xcode 26.3→16.2 两个大版本都一样，排除版本问题；下载 CI 保存的 `.xcdistributionlogs`（verbose 日志），发现**不只 app-store，连 Development 签名等所有分发方式都被拒绝**，说明问题不是权限，是这个 `.xcarchive` 本身没被 Xcode 识别为合法可分发归档包
5. 加调试步骤 dump archive 的 `Info.plist`，确认 `ApplicationProperties` 字典完全缺失（只有 ArchiveVersion/CreationDate/Name/SchemeName）——但 `Products/`、`dSYMs/` 目录下 app 本身真的签好了（`_CodeSignature`、`embedded.mobileprovision`都在）。这是一个有据可查的 Xcode 老 bug：`xcodebuild archive` 纯命令行调用（不经过 Xcode.app 图形界面）经常不会写这个字典，即使签名完全正确。社区验证过的解法：改成先手动 `xcodebuild archive`，再用 `PlistBuddy` 从已签好名的 `.app/Info.plist` 里读值手动补上 `ApplicationProperties`，然后让 `gym`（`build_app`）跳过它自己的 archive 步骤（`skip_build_archive` + `archive_path`），只做 export+upload
6. **补上这个字典后，Export 第一次真正成功**（`Successfully exported and signed the ipa file`）——CI 跑了几十次以来第一次产出真实签名的 .ipa。上传 TestFlight 报 `upload_to_testflight` 参数名错误（`platform` 应为 `app_platform`），修完后又报 `Unable to determine app platform for 'Undefined' software type` (1194)——这次报错来源换了，不是构建脚本的问题，而是 **App Store Connect 里这个 App 记录本身的"软件类型/平台"字段异常**，尝试显式传 `app_identifier` 也没用，说明卡点已经彻底转移到 App Store Connect 网页那一侧的 App 记录状态，不是 CI 能解决的

**教训**：`Unknown Distribution Error` / "账号权限被拒绝"这类看起来像账号问题的报错，实际可能是完全不同层面的构建管线 bug（认证没传、签名被关、team 没传、archive 结构本身缺字段）——每一层看似"合理"的解释都要用真实日志验证，不能停在"看起来像账号问题"就归因到 Apple 那边。这次靠的是持续看 CI 日志细节（尤其是 verbose 分发日志和 archive 内容 dump），而不是猜测。

### 2026-08-14 — 推翻"账号权限被拒绝"根因，真正原因是 Fastfile 里 api_key 没传给 build_app

- 用户反馈"发布一直失败但我们一直在等，这没意义"，重新逐项核实此前记录的"Apple 账号分发权限被拒绝"根因，结果全部核实通过、无一异常：
  - 会员资格页：Team `28UXGDR5KC`，计划 Apple Developer Program（付费），续订至 2027-08-11
  - App Store Connect API Key：当前生效的 `CI Release` key 确认归属这个付费 team，权限"管理"
  - Distribution 证书：归属同一 team，有效期到 2027-08-10
  - Provisioning Profiles：`WatchVoiceIntake AppStore` / `WatchVoiceIntakeWatch AppStore` 两个 App Store 类型描述文件都存在，跟 Fastfile 里引用的名字完全匹配
  - 商务协议页：免费 App 协议状态"有效"（本项目免费，不需要付费 App 协议）
  - GitHub secrets 时间戳交叉核对：`APPLE_TEAM_ID` 在 8/13 触发失败前 7 秒确实被更新过，说明用户确实认真做过账号调整，方向是对的，只是没查到真正卡点
- 真正卡点是重新看 CI 日志里"Debug — dump downloaded provisioning profiles"这步，输出是 `No such file or directory`——export 阶段本地一份描述文件都没有，说明这一步从未真正跟 Apple 服务器认证过
- 回头看 `fastlane/Fastfile`：`api_key = app_store_connect_api_key(...)` 生成的凭证只传给了最后的 `upload_to_testflight`，`build_app`（真正执行 archive+export 的那一步）完全没有传 `api_key`——`xcodebuild -exportArchive` 因此没有任何凭证可用来查询"这个 team 有哪些可用分发方式"，Apple 端返回空集合，Xcode 报 `expected one {} but found app-store`（`{}` 就是那个空集合，不是"app-store 被拒绝"，是"压根没查到任何合法选项"）
- **教训**：报错信息里"账号缺少某权限"式的措辞，不代表真的是账号侧问题——`IDEDistributionMethodManager` 在完全没认证的情况下也会报几乎一样的错。之前三套环境（xcodebuild/fastlane/Xcode Cloud）复现一致，只是因为三套环境都复用了同一个有缺陷的 Fastfile/脚本逻辑，"多环境复现"不能当作"排除脚本 bug"的证据
- 修复：`build_app(...)` 里加一行 `api_key: api_key`，已提交推送，正在触发验证跑一次真实 Release

### 2026-08-13（续六）— 纠正"永久 Pro"误记；测试账号实际已填进 App Store Connect

- 查证发现"续四"那条记录不准确：写进 `subscriptions` 表的那条自定义记录
  （`stripe_subscription_id: 'apple-review-test-account'`）**从未真正生效**——`getAccountStatus()`
  （`server/db.js:541`）只认 `stripe_subscription_id` 以 `sub_` 开头的真实 Stripe 订阅，这条自定义
  ID 被直接跳过，实际生效的是账号自带的 7 天试用期（`trial_ends_at: 2026-08-20T10:50:30Z`）
- 排查过程：先查了本机 `research-os/data/research-os.db`（过期的本地开发库副本，误判账号不存在）→
  用生产 API `POST /api/auth/register` 探测（返回 `email_taken`，证明账号确实存在）→ 用
  `GET /api/admin/users`（`x-admin-key` 头）查到真实状态，确认试用期而非永久 Pro
- **教训**：跨会话/跨进程共享的状态（尤其涉及生产数据库），仅凭 `PROJECT_LOG.md` 里的记录判断"是否
  已完成"是不够的——文字记录可能写了但操作没生效、或操作本身有 bug。凡是能通过 API/命令行独立验证的
  状态，动手改之前先查一遍实际状态，不要直接信任已有文字记录
- 用户在另一个对话窗口尝试"修复成永久"，用的还是同一种不生效的写法（同样的 `subscriptions` 表自定义
  记录），验证后确认没解决问题——**两次尝试路径相同，都没有触达真正生效的字段**
- 正确的修复方式是设 `is_legacy_free = 1`（`server/db.js:565`，代码里本来就是给"永久免费不走 Stripe"
  设计的字段，`getAccountStatus()` 会直接认，不受 trial 时间限制），命令：
  ```
  ssh SHUYIN@192.168.3.5
  sudo /usr/local/bin/docker exec research-os-blue node -e "
  const Database = require('/app/node_modules/better-sqlite3');
  const db = new Database('/app/data/research-os.db');
  db.prepare('UPDATE users SET is_legacy_free = 1 WHERE id = ?').run(37);
  console.log(JSON.stringify(db.prepare('SELECT id, email, is_legacy_free, trial_ends_at FROM users WHERE id = ?').get(37)));
  "
  ```
  这条命令因为是直接写生产数据库，被系统权限规则拦截、AI 助手无法代执行，**需要用户自己在 SSH 里跑**——
  截至本条记录，用户还没跑，账号仍是 7 天试用状态，**这是可选项，不是硬阻断**（审核一轮大概率 7 天够用）
- 用户已经完成 App Store Connect 侧的操作：登录信息（用户名+密码）已填入 Sign-In Information、备注
  英文说明已贴入 Notes、已点保存。checklist 第1项状态改为 ✅ 已完成（权限是否永久是遗留小事项，不影响
  这一项的完成判定）

### 2026-08-13（续四）— 建好 App Review 用的测试账号

- Apple 回了邮件，用户进入下一步审核准备，需要一个"空账号"给 Apple 审核员登录用——不是 Apple ID，是 App 自己连的 research-os 邮箱密码系统（`AuthSession.swift`/`LoginView.swift`，走自建服务器，不是第三方 OAuth）
- 用 research-os 自己的 `/api/auth/register` 注册了一个全新账号：`shuyin.unlimited+applereview@gmail.com`（Gmail `+` 别名，邮件会进用户自己收件箱，但账号本身在系统里完全独立、无任何笔记数据），user_id 37
- 新注册账号默认只有 7 天试用期，过期后语音上传/AI 整理等核心功能会被锁——审核有时会拖过 7 天，锁掉功能可能被误判成 App 故障直接拒审。跟用户确认后，直接给这个账号写了一条永久 Pro 订阅记录（`current_period_end` 2027-08-13，`stripe_subscription_id: 'apple-review-test-account'`，纯本地标记，不走 Stripe、不产生费用）
- 密码只在对话里给了用户，**没有写进这个文件**——这个仓库要推到 GitHub，写进去等于把密码公开
- **App Review Information → Sign-In Information 现在可以直接用这组邮箱+密码填了**，checklist 第1项完成

### 2026-08-13（续）— Apple 支持首次实质回复（免费/付费账户混淆假说），实测排除

- Apple 技术支持（Terry）就案例 `20000133548930` 给出第一个具体、可操作的排查方向：账号
  `2415476719@qq.com` 可能同时关联免费开发者账户和付费 Apple Developer Program 账户，工具可能
  误用了免费身份，并给了一个 Apple 官方论坛的类似案例（`forums/thread/772395`，症状是 Xcode
  用了 "Personal Team" 而非付费 Team）
- 用户提供付费 Team 会员资格截图核实：Team ID `28UXGDR5KC`，Apple Developer Program，个人身份，
  2027-08-11 续订——确认这个账号确实是合法的付费开发者账户
- 排查 CI 侧代码，确认 `fastlane/Fastfile:23` 的 `export_team_id: ENV["APPLE_TEAM_ID"]` 是
  exportArchive 阶段唯一决定"问 Apple 服务器查哪个 Team 的分发资格"的参数，理论上是这条假说
  在 CI 场景下最直接的验证点
- **实测**：用 `gh secret set` 把 `APPLE_TEAM_ID` 显式改成确认过的付费 Team ID `28UXGDR5KC`，
  手动触发 `release.yml`（`workflow_dispatch`，不需要远程 Mac，GitHub 云端 macOS runner 跑的）
  → **报错逐字不变**：Archive 秒成功，Export 阶段 0.1 秒内立刻报同一个
  `IDEDistributionMethodManagerErrorDomain Code=2 "Unknown Distribution Error"`，连时间点都几乎
  一样。**这个假说被本次实测排除**——不是 Team ID 混淆的问题（CI 用 App Store Connect API Key
  认证，本来就不太可能像 Xcode GUI 那样混淆账号身份，这次验证印证了这一点）
- 已整理好中文回复邮件草稿 `APPLE_SUPPORT_REPLY_2026-08-13.md`：列出已核实的 Team ID 信息、
  这次的排除性测试结果、附上完整报错文本，以及此前已经排除过的四个方向（证书/描述文件、Xcode
  版本、工具选择、Team 混淆），明确要求 Apple 工程师从账号后端权限状态而非客户端配置层面排查——
  等用户确认后手动发出
- **给以后的教训**：Apple 支持给的建议即使配了具体案例参考，也可能是根据关键词匹配到的通用模板，
  不代表已经看过这个案例的具体技术细节——回复时最好带上"我已经验证过你的建议、结果如下"这种具体
  证据，逼着支持真正往下一层排查，而不是在同一个假说上来回打太极

### 2026-08-13（续）— 修复账号删除入口硬阻断；澄清 Sign in with Apple 不适用

- 用户确认"只有自己用"跟"Sign in with Apple"是两码事——后者只在提供第三方 OAuth 登录（Google/
  Facebook 等）时才触发（Guideline 4.8），这个 App 走自建邮箱密码账号系统，本来就不适用，之前的
  ✅ 判断不变
- 调研 research-os 后端，发现 `server/index.js:363` **已经有** `DELETE /api/account`（authRequired，
  强制 `confirm: true`、会挡有活跃订阅的账号，调用 `deleteUserSafe`）——这条路本来就存在且带防护，
  只是从没有任何客户端接过它（`research-os/src` 网页端也没接，`server/pages/terms.html` 里"可通过
  App 内置功能删除账号"这句话其实是空头支票）。因为已有防护逻辑，这次不用碰任何"怎么删数据"的
  判断，只是加一层客户端调用，风险比从零写删除逻辑低得多
- `iOS/AuthSession.swift`：新增 `deleteAccount()`，调用上述接口，处理 `active_subscription_exists`
  返回中文提示，成功后自动本地登出；顺带把内部 `LoginError` 枚举改名成 `AuthError`（只在文件内部
  使用，登录/删除共用同一个错误类型，改名不影响任何外部调用）
- `iOS/AccountSettingsView.swift`（新文件）：账号设置页，"退出登录" + "删除账号"（destructive 按钮
  + 二次确认 alert，文案写明"无法撤销"），通过 `ContentView`（`WatchVoiceIntakeApp.swift`）右上角
  新增的人形图标 toolbar 按钮打开
- **未验证**：本机是 Windows，没法本地跑 Xcode 编译，这次改动还没有真正编译过，下次联调远程 Mac
  或触发 CI 时要验证一遍能编译通过、删除流程真的能走通
- `APP_STORE_PREFLIGHT_CHECKLIST.md` 同步更新：第2项（账号删除）标 ✅ 已修复；第1项（审核测试账号）
  补充了具体操作步骤和一段可以直接贴进 App Review Notes 的英文说明（用来降低被 Guideline
  4.2/2.3.1 当"私有工具"卡审核的概率）

### 2026-08-13 — 新增 App Store 发布前合规检查 skill，首次审计发现 2 项硬阻断

- 背景：用户怀疑之前的"审核被拒"跟"录音数据立刻上传服务器"的隐私合规有关，想要一个每次发布前
  能自动检查的清单。审计代码后发现两点需要澄清：
  1. **当前卡住的 CI 分发权限问题（案例 `20000133548930`）跟 App Review 完全无关**——app 从未
     成功打包上传过，从没被人工审核团队看过，两个邮件线程（Apple Technical Support vs 未来可能
     的 App Review 反馈）不是同一回事，不要混着等
  2. **真正扫出来的合规风险，比"数据上传时机"更实质、概率更高的是两条**：
     - App 是纯邮箱/密码登录、指向私有服务器、无注册流程（`AuthSession.swift`/`LoginView.swift`
       注释原文写"this app has exactly one user, its own owner"）——如果提交时 App Store
       Connect 的 App Review Information 没填测试账号，审核员进不去登录墙，这是 Apple
       Guideline 2.1 最常见的拒绝原因之一
     - 支持登录但没有账号删除入口（`AuthSession.swift` 只有 `logout()`），不满足 Apple
       Guideline 5.1.1(v)（2022 起强制）
  - "数据立即上传"这个用户最初怀疑的点，本身审计下来**不是**违规行为——大量云同步类 App 都这样
    做，只要 App Privacy 营养标签如实申报（Audio Data + 关联身份）即可，不是硬阻断
- 新增 `.claude/skills/appstore-preflight/SKILL.md`：项目专属 skill，每次发布前跑一遍，读
  `APP_STORE_PREFLIGHT_CHECKLIST.md` 逐项核对代码现状，更新状态标记，明确区分"代码能验证的项"
  和"必须去 App Store Connect 后台人工确认的项"（skill 不假装能验证后台配置）
- 新增 `APP_STORE_PREFLIGHT_CHECKLIST.md`：8 项检查，2 项 ❌ 硬阻断（测试账号、账号删除入口）、
  3 项 ⏳ 需去后台配置（隐私政策 URL、App Privacy 标签、Export Compliance 加密声明）、3 项 ✅
  已通过（麦克风权限文案、不适用 Sign in with Apple、传输加密）
- **策略问题的答案（用户明确问过）**：不需要等 Apple 确认"被拒"才能动手改。因为这个 app 至今
  没有真正提交成功过，"提交-被拒-改-再提交"这个周期根本还没开始，趁着等分发权限问题解决的这段
  空档，并行把 checklist 里的硬阻断项修完，等分发权限一通，直接一次性提交一个已经合规的版本，
  避免"先用有问题的版本占位提交、再被拒一次、再改"这种多绕一圈的路径

### 2026-08-11 — Apple 技术支持首次回复（仍是模板回复，非实质技术答复）

- 收到 Apple 开发者支持中文团队（客服 Neil）回复邮件，**内容是通用模板**：确认收到工单、引导去 Apple Developer Forums 自助查找答案、给了案例编号、留了预约电话入口——**没有针对"账号级分发权限被拒绝"这个具体问题给出实质性技术回应**，判断是人工客服打开工单后的第一层标准流程，还没真正进入技术排查
- **案例编号（务必保留）：`20000133548930`**
- **已回复**：用中文正文（`APPLE_SUPPORT_REPORT.md` 核心内容改写成口语化中文，说明不是 Forums 可解答的问题，要求技术团队核实账号后端权限状态）回复了该邮件，案例编号 `20000133548930` 保留在邮件线程里。**当前状态：纯等待 Apple 下一次回复**

### 2026-08-11 — 关掉 Xcode Cloud 自动触发，避免等待期间刷屏失败邮件

- 用户发现 Xcode Cloud 每次 push 到 main 都自动触发一次构建（`WatchVoiceIntakeWatch` App 的 `Default` workflow，启动条件是"分支变更"），跑的还是同一个已诊断到底、等 Apple 回复的问题，每次失败都发一封邮件，纯噪音
- **已在 App Store Connect → Xcode Cloud → Default workflow 把顶部开关关掉**，停止自动触发。随时可逆，Apple 回复处理完再打开或手动 Start Build 验证
- **顺带发现一个信息**：该 workflow 的"分发准备"字段当前是"无"（不自动提交 TestFlight/App Store，只单纯 Archive），修改时间是 2026-08-10 22:19（Zhaozhen Tong）。这意味着**这个 workflow 目前的配置根本不会走到"分发被拒绝"那一步**——只做 Archive。如果 2026-08-10 22:19 之后还有失败的构建记录，那失败原因可能不是账号分发权限问题，而是 Archive 阶段本身的问题，跟之前"三套环境完全一致卡在分发权限"的结论对不上，**下次排查前需要先核对这次改动前后的构建记录时间线，不要想当然套用旧诊断结论**
- 决定：Apple 回复、账号问题解决后，处理顺序是——① 把"分发准备"改回 TestFlight（仅限内部测试）② 把 workflow 开关打开 ③ 手动 Start Build 验证

### 2026-08-10 — release.yml 反复失败排查（还在进行中）

这一段完整记下来，避免以后重新踩：

1. **Secret 名字打错**：GitHub Secret 建成了 `APPSTORE_ISSURE_ID`（拼写错误），代码引用的是 `APPSTORE_ISSUER_ID`，两者对不上导致值传空。**改代码去匹配已经打错的 secret 名字**（不要求用户重建），这是故意的，见上面"关键信息"表格
2. **`ExportOptions.plist` 的 `method` 值写错**：一开始写的是 `app-store-connect`，这不是合法值；改成 `app-store`
3. **Archive 产物完全没签名**：`project.yml` 项目级设置里 `CODE_SIGNING_ALLOWED: NO` / `CODE_SIGNING_REQUIRED: NO`（Phase 1 为了让免签名云编译能过而设的），Archive 步骤命令行只覆盖了 `CODE_SIGN_STYLE=Automatic`，没覆盖这两个开关，导致 Archive 产物完全未签名，Export 阶段自然找不到任何可用的分发方式。加上 `CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES` 覆盖后，问题往前推进了一层，暴露出下面第4条真正的核心问题
4. **核心问题（未解决）**：`xcodebuild archive` 报错 "Your team has no devices from which to generate a provisioning profile"，本质是 Xcode 自动签名在执行 Archive 动作时，即便最终目标是 App Store 分发，内部依然会先尝试生成一个"开发用"签名产物作为中间步骤，而**开发类描述文件强制要求账号里至少注册过一台设备**——全新账号一台设备都没注册过，卡死在这一步
   - 试过 `CODE_SIGN_IDENTITY="Apple Distribution"` 强制指定发布签名身份 → 报错变成"自动签名判定为开发签名，但你又手动指定了发布签名身份，两者冲突"，说明这个方向是错的，回退了
   - 试过把 API Key 角色从 App Manager 换成 Admin → 没有解决这个具体错误（但 Admin 权限本身是必须的，证书管理类操作 App Manager 角色确实没权限，这个改动保留）
   - 用 Xcode GUI 登录账号、手动生成了一张 Apple Distribution 证书 → **完全没变化，报错一字不差**，说明"缺证书"从来不是真正的瓶颈，这个方向的判断也是错的
   - 查了 XcodeGen 生成的 `.xcscheme` 确认 Archive 动作本来就正确指向 Release 配置——不是配置问题
   - **最终判断（已修复，待验证）**：`-allowProvisioningUpdates` + `CODE_SIGN_STYLE=Automatic` 这套纯命令行自动签名，对"全新账号、无状态 CI 环境"这个组合本身就不可靠，不管账号里有没有证书都一样卡——这是业界文档记录的已知限制，不是我们能通过调参数解决的。**改用手动签名**：在 Developer Portal 手动创建两个 App Store 类型描述文件（`WatchVoiceIntake AppStore` / `WatchVoiceIntakeWatch AppStore`），`project.yml` 里每个 target 显式指定 `CODE_SIGN_IDENTITY: "Apple Distribution"` + `PROVISIONING_PROFILE_SPECIFIER`，`release.yml` 不再覆盖 `CODE_SIGN_STYLE`（让 project.yml 的 `Manual` 默认值生效），只覆盖 `CODE_SIGNING_ALLOWED/REQUIRED=YES`。`-allowProvisioningUpdates` 保留，用来下载（不是创建）已存在的具名描述文件，这部分是文档确认可靠的操作
   - commit `e020911`，等下一次 `release.yml` 跑完验证

5. **手动签名切换后，Archive 真正成功了**（commit `e020911` 验证通过）——CI 日志确认两个 target 都显示 `Signing Identity: "Apple Distribution: Zhaozhen Tong"` + 正确的描述文件名，这部分问题彻底解决了
6. **但 Export 阶段卡在新问题**：`xcodebuild -exportArchive` 报 "Unknown Distribution Error"（`IDEDistributionMethodManagerErrorDomain Code=2`），紧跟着 "exportOptionsPlist error for key method expected one {} but found app-store"。排查过程（按顺序）：
   - 一开始以为是 `ExportOptions.plist` 的 `signingStyle` 还写着 `automatic`(跟手动签名的实际情况冲突) → 改成 `manual` + 显式 `provisioningProfiles` 映射 → 没解决，报错不变
   - 怀疑 `method` 值本身在 Xcode 16 上从 `app-store` 改名成了 `app-store-connect`（查资料确认过这个改名是真的） → 两个值都试了，报错一模一样 → 说明这次不是这个原因
   - 诊断了 archive 内部 `Info.plist`，发现完全没有 `ApplicationProperties`(正常应该有签名身份/Team/Bundle ID) → 怀疑是主 App target 缺了 `SKIP_INSTALL: NO`(Watch target 之前补过，主 target 一直没补) → 补上后 archive 的 Info.plist **依然没有 ApplicationProperties**，这个方向也是错的（但 `SKIP_INSTALL: NO` 这个改动本身没坏处，保留了）
   - **换用 fastlane**（`build_app` + `upload_to_testflight`）替代手写 `xcodebuild archive`/`exportArchive`/`altool` —— fastlane 内部走的还是同一套 `xcodebuild` 调用，**报错完全相同**，证明问题不在"我们手写脚本哪里写错了"，是更底层的东西
   - 查到 macOS-15 runner 默认的 Xcode 16.4 在 App Store 提交上有已知问题（`actions/runner-images#14165`），怀疑是 Xcode 版本过旧 → 改成自动选这台 runner 上实际装着的最新 Xcode（26.3）→ **报错依然一模一样**，连 Xcode 版本也排除了
   - 诊断"下载到的描述文件实际内容"，发现两个常见缓存目录（`~/Library/MobileDevice/Provisioning Profiles/` 和 `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`）都是空的——`-allowProvisioningUpdates` 用 API Key 认证时不会把描述文件持久化到磁盘，每次 xcodebuild 调用现拉现用，这条诊断路径走不通
   - **张梦截图里发现关键证据**：她本地 Keychain Access 里那张 Apple Distribution 证书标红"证书不受信任"——**缺 Apple 的 WWDR 中间证书**，导致证书链不完整。这解释了为什么 `codesign`（只要私钥匹配就行）能成功，但 `exportArchive` 的信任校验（`IDEDistributionMethodManager`）会挂——补上 WWDR + Root CA 证书 → **报错依然完全不变**，这个方向也没能解决问题，但确实是一个真实存在、已经修复的独立问题（保留了这个修复）
   - **当前排查到的最后结论**：账号是当天才注册批准的，怀疑是 Apple 后端多套系统之间的权限同步延迟（Developer Portal 显示"已通过"≠所有下游服务都同步完），纯粹是时间问题，暂时没有更多技术手段能验证或加速——**下一步就是等几小时到一天后直接重新触发，不用再改配置**

**给以后的教训（用户明确要求记住）**：
1. 这次反复失败的根本原因是**没有先调研 Apple 官方/社区关于"全新账号 + CI 纯命令行签名"的标准流程，就直接凭经验试**，浪费了很多轮。以后遇到"看起来是常见操作但反复报错"的情况，先搜索确认业界标准做法，再动手改，不要每次报错都靠猜测下一个修复点
2. "自动签名"（`CODE_SIGN_STYLE=Automatic` + `-allowProvisioningUpdates`）在真正的无人值守 CI 环境里天生不如"手动签名 + 预先创建好的具名描述文件"可靠——这不是这个项目专属的坑，以后任何新的 iOS/watchOS 项目要接 CI 自动发布，直接从手动签名开始做，不要先尝试自动签名再踩坑
3. **换工具(xcodebuild→fastlane)、换版本(Xcode 16.4→26.3) 报错完全不变，是很强的信号**——说明问题不在"这个特定命令怎么写"，而在更上层(账号状态/服务端权限)，这时候应该停止在命令行参数层面继续试，往账号状态方向查
4. **全新 Apple Developer 账号当天批准后，不要假设所有权限立刻生效**——Developer Portal 网页显示"已通过"只代表最基础的账号状态，App Store 分发相关的权限可能有独立的、更慢的后端同步延迟，遇到怎么调都没用的诡异错误时，这是需要考虑的候选原因，可以先等一等再排查，不用一直烧 CI 构建次数
### 2026-08-10 — Apple Developer 账号 + App Store Connect 设置

- 用户完成：注册 Apple Developer Program（$99/年，Individual）、注册两个 App ID（`com.shuyinlab.watchvoiceintake` / `.watchkitapp`）、App Store Connect 建 App 记录
- 新增 `.github/workflows/release.yml`：手动触发（`workflow_dispatch`），用 App Store Connect API Key 自动签名打包上传 TestFlight，理论上不需要手动导出 `.p12`/`.mobileprovision`

### 2026-08-09/10 — Phase 4 续：iOS 上传队列 + 登录

- 新增 `iOS/UploadQueueManager.swift`：合并好的录音持久化存到 `Documents/PendingUploads`（不是 tmp，重启不丢），失败自动重试，`recordingId` 做幂等键防重复上传
- 新增 `iOS/AuthSession.swift`：Keychain 存 JWT（30天有效期，跟服务器 `authRequired` 中间件一致），`iOS/LoginView.swift` 提供登录界面
- **踩坑（一次真实的疏忽）**：写完 `UploadQueueManager` 后忘了把 `PhoneConnectivityService.swift` 里的占位注释换成真正的 `UploadQueueManager.shared.enqueue(...)` 调用，导致代码"看起来完整"但合并完的录音其实从没进过上传队列。**教训**：改动分布在多个文件时，改完要搜索确认所有引用点都真的接上了，不能只看单个文件编译通过就当作完成
- **踩坑（Windows/Mac 双边编辑同步问题）**：这个项目同时在张梦的 Mac（跑 SSH 命令做真正的编译验证）和本地 Windows（`D:\partition3\Boring_buss\WatchVoiceIntake`，方便用 `gh` push）各有一份工作副本，多次出现"改了一边忘了同步另一边"、"git commit 作者身份在 Mac 上被自动填成张梦的本地账户"等问题。**教训**：以 Mac 上跑通编译验证的那份为准，push 前用 `git bundle` 把 Mac 的精确历史带到 Windows 来推送，不要凭记忆在两边分别重写同一个改动
- **踩坑（Shell 转义）**：早期用 SSH 命令套 heredoc 写 Swift 文件时，Swift 代码里的 `$0`（闭包简写参数）被外层 SSH 双引号命令做了 shell 变量展开，写进文件的内容变成了乱码（`/usr/bin/bash`）。**教训**：往远程写含有 `$`、反引号等字符的代码文件，优先用 `scp` 直接传文件或 base64 编码传输，不要用双引号包裹的 heredoc

### 2026-08-09 — Phase 4：服务器端接入 AI Intake

- 研究了 research-os 现有的会议录音异步处理管线（`server/meetings.js`：上传→AssemblyAI转写→AI总结→写入 pending 队列→客户端拉取合并），照这个成熟模式实现 Watch 语音管线，而不是重新发明
- 新增 `server/watch.js`：`POST /api/watch/voice`——转写(复用 `handleTranscribe` 抽出的 `transcribeAudioBuffer`) → AI整理成笔记(仿照 `handleCasualChatSummarize` 的"永远直接出结果不追问"模式，新建 `organizeWatchTranscript`) → 存入新表 `watch_notes_pending`
- 新表 `watch_notes_pending`：跟 `evolver_drafts`/`meeting_updates` 一样的"服务器只排队、客户端自己拉取合并进 `ros:memos`"规则，服务器永远不直接写 `ros:memos`
- `recordingId`（Watch 生成的 UUID）直接做主键，实现幂等——同一段录音重传不会建重复笔记
- 客户端 `src/pages/Memo.jsx` 新增 `pullWatchNotes()`，App 打开时自动拉取合并，**全程不经过人工确认**（这是产品要求：Watch 笔记要全自动，不像网页版 AI Intake 那样需要检查草稿再点创建）

### 2026-08-09 — Phase 2/3：本地录音 + 多段录音 + Watch→iPhone 传输

- 基础录音测试通过（模拟器）
- 产品需求变更：单次录音改成"暂停/继续说/完成"三态，允许分段录音、最后合并成一条笔记再上传（避免半句话就建碎笔记）
- **重大技术坑**：`AVAssetExportSession`（用于合并多段音频）在 watchOS 上**整体不可用**——所有 `AVAssetExportPreset*` 常量在 SDK 里都标了 `API_UNAVAILABLE(watchos)`，跟 watchOS 部署目标版本无关，watchOS 11 也一样。**解法**：把合并逻辑从 Watch 移到 iPhone（`PhoneConnectivityService`），iOS 端完整支持 `AVAssetExportSession`；Watch 只管录制+发送有序段落（带 `sessionId`/`sequenceIndex`/`segmentCount` 元数据），iPhone 收齐后再合并
- **模拟器已知限制**：iOS/watchOS 模拟器之间 `WCSession.transferFile`（文件传输）经常静默失败，多次测试证实——这是 Apple 模拟器本身的限制，不是代码问题，**不值得花时间排查**，留到真机测试验证

### 2026-08-09 — 远程开发环境搭建

- 用户人在日本，Mac 只有一台旧 2014 MacBook Pro（跑不动现代 Xcode），改用女朋友张梦在中国的新 Mac 远程开发
- 踩坑排查过程（详见对话历史，不赘述）：VNC/屏幕共享黑屏 → 换 AnyDesk 解决远程桌面；SSH 密钥登录配置成功，密钥存在本机 `D:\partition3\Services\ssh_keys\`（不要存在项目仓库或临时 scratchpad 目录，之前一度存错地方）
- **规则**：本项目所有 SSH 命令行工作交给 Claude 做，图形界面操作（登录 Apple ID、Watch 配对信任、点击物理按钮）需要用户/张梦配合远程桌面完成

### 2026-08-09 — Phase 1：项目搭建 + 云端编译

- 建仓库，XcodeGen + GitHub Actions macOS runner 做免费云端编译验证（不需要本地 Mac）
- 踩坑：Watch target 用了过时的 `application.watchapp2` 类型（watchOS 7 之前的双 target 打包格式），跟 watchOS 10+ 部署目标搭配导致 XcodeGen 生成重复输出路径，`xcodebuild` 报 "Multiple commands produce"。**修法**：改成 watchOS 9+ 的标准单 target `application` 类型
- Phase 1 完成：CI 编译通过（未签名）


