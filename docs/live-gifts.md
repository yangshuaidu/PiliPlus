# 直播间礼物

直播间输入栏和全屏播放控制栏增加“礼物”入口，使用当前主账号读取礼物目录、背包及电池余额。支持给当前房主赠送普通电池礼物和已有背包礼物。发送前展示账号 UID、主播、房间、礼物、数量及费用；背包赠送显示库存消耗和 0 电池费用。

## 实现来源与接口证据

- 基线：上游 `main` 的 `334d758127c8126e7f3bb3df7470b3229bc9b0ee`。
- 在 `main`、公开 `dev` / `dom` 分支中未找到相应赠礼接口；公开 PR [#3145](https://github.com/bggRGjQaUbCoE/PiliPlus/pull/3145) 的 `1f20ad3` 已有客户端实现。模型、目录解析、发送字段和回执校验参考并提取自该 PR，保持 GPL-3.0；未合入其 CDN、小窗、粉丝团、大航海等其他功能。
- 2026-10-03 只读检查官方直播页及其公开脚本：
  - 页面：<https://live.bilibili.com/21452505>
  - 脚本：<https://s1.hdslb.com/bfs/static/blive/blfe-live-room/static/js/app.3b48f866e1563d25d39c.js>
  - 脚本确认普通赠礼使用 `sendGoldMultiUser`，有 `bagID` 时改用 `sendBagMultiUser`；表单包含 `uid`、`gift_id`、`ruid`、`send_ruid`、`gift_num`、`coin_type`、`bag_id`、`biz_id`、`price`、`receive_users` 等。
  - 匿名读取当前房间礼物目录成功，返回 `code=0`，本分支解析出 82 个电池礼物条目，其中 16 个因特殊机制或限制不可赠送。该样本不证明任何账号具备购买权限。

| 用途 | 方法与路径（域名 `https://api.live.bilibili.com`） |
| --- | --- |
| 房间礼物及分组 | GET `/xlive/web-room/v1/giftPanel/roomGiftList` |
| 背包 | GET `/xlive/web-room/v1/gift/bag_list` |
| 电池余额 | GET `/xlive/web-room/v1/index/getInfoByUser` |
| 电池送礼 | POST `/xlive/revenue/v2/gift/sendGoldMultiUser` |
| 背包送礼 | POST `/xlive/revenue/v2/gift/sendBagMultiUser` |

目录请求传入实际房间、主播和已有分区信息。目录合并主列表与 `tab_list`，按礼物 ID 去重。价格与余额保留服务端原始整数 gold，仅在显示时按 100 gold = 1 电池换算；不做人民币换算。背包发送携带 `bag_id`，提交价格为 0，不自动切换成付费购买。

## 提交约束

- 选择和确认绑定具体登录对象；切换主账号、重新登录、关闭面板或确认超过 60 秒后不得提交旧确认。
- 确认前与实际发送前重新读取目录、余额和库存，检查价格、数量、固定数量规则、有效期、指定房间/主播及礼物权限。
- 不把盲盒、抽奖或其他专用支付流程当普通礼物提交；不包含充值、SC 购买、大航海开通或向连麦嘉宾赠礼。
- 专用 Dio 实例保留账号拦截器，移除自动重试和日志拦截器，禁止发送重定向。每次确认至多提交一次；同一账号的并发写入互斥。
- 发送前将操作标记持久化并 flush 到 `liveGiftJournal`，只保存操作元数据，不保存 Cookie 或 CSRF。
- `code=0` 之外还需匹配发送者、接收者、礼物、数量和回执标识才显示成功。超时、格式异常、回执不匹配或保存最终回执失败时显示结果未知，禁止自动重发。
- 未知操作跨面板关闭和重启保留。用户在官方核对记录、库存和余额后，可明确解除该房间的待核对限制；该操作不重发、不把未知结果改成成功。

## 验证

使用隔离的 Flutter 3.47.6 / Dart 3.13.5 SDK 和依赖缓存，应用项目 Windows 构建流程列出的 SDK / Material UI 补丁，没有执行会修改全局 Git 配置的原始补丁脚本。

```sh
flutter test --no-pub --concurrency=1 \
  test/utils/accounts/deleted_account_test.dart \
  test/services/live_gift_service_test.dart \
  test/pages/live_gift_panel_test.dart

flutter build bundle --no-pub --debug --target-platform windows-x64
```

- 32 个测试通过：26 个礼物模型/交易逻辑用例、4 个界面用例、2 个原有账号删除回归用例。
- 界面用例检查付费确认信息、取消不发送、背包 0 电池、非法数量及 360×640 窗口带键盘的布局。
- 完整应用 Dart kernel 与资源 bundle 编译通过。该构建不是可直接安装的 EXE/APK。
- 本机缺少 Android SDK 和 Visual Studio C++ 工具链，未构建原生安装包。
- 未登录真实账号做背包/余额读取验收，未实际赠送礼物或扣费。真实账号接口兼容性、实际回执、库存/余额扣减及各平台运行仍需单独验收。

项目现有 `.gitignore` 使用 `test*` 忽略测试目录；本分支明确纳入上述新增测试和对应的假接口支持文件，未修改全局忽略规则。
