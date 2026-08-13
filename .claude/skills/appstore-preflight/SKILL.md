---
name: appstore-preflight
description: 发布到 App Store / TestFlight 之前的合规预检清单（隐私标签、账号删除、审核可测试性等），审计 WatchVoiceIntake 项目代码，更新根目录 APP_STORE_PREFLIGHT_CHECKLIST.md 的通过状态。
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Edit
  - Write
triggers:
  - 发布前检查
  - appstore preflight
  - app store 审核检查
  - 发布前审核
  - 提交审核前检查
---

## 这个 skill 做什么

WatchVoiceIntake 每次准备提交 App Store / TestFlight 之前，跑一遍这个 skill，
核对 `APP_STORE_PREFLIGHT_CHECKLIST.md` 里的每一项：

1. 读取该 checklist 文件（不存在则报错，不要自己瞎编一份）
2. 针对每条"代码可核查项"，实际去读对应源文件确认现状（不要凭记忆判断，
   文件路径已经写在 checklist 里）
3. 针对每条"App Store Connect 后台配置项"（无法从代码里看到），列出来提醒
   用户去后台手动确认，不要假装能验证
4. 用 ✅/⚠️/❌ 标注每一项的当前状态，更新 checklist 文件里对应的状态标记
   和"最后核对日期"
5. 最后给一个总结：有几项是**硬阻断**（不修会大概率被拒或提交不了）、
   几项是**建议修**、几项**已通过**

## 重要边界

- 这个 skill 只做**合规/可提交性**审计，不做功能 QA、不做性能测试、不做
  UI 审查——那些是 `/ios-qa`、`/ios-design-review` 的范围
- 不要在这个 skill 里修改任何业务代码（比如去加账号删除功能）——发现问题
  只报告，改不改、什么时候改，是用户的决定
- App Store Connect 后台的配置项（隐私标签怎么勾的、App Review Information
  里填没填测试账号、Export Compliance 声明选了什么）无法通过读代码验证，
  必须明确告诉用户"这项需要你自己去后台确认"，不能因为代码层面没问题就
  假设后台也配对了
