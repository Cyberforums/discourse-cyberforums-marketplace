# discourse-cyberforums-marketplace

Cyberforums 商城的论坛插件。设计见 linuxjoy `docs/plans/2026-10-28-marketplace-multi-vendor-native-design.md` 第 9 节。

**原则：文派集市（WooCommerce + MarketKing）是事实来源，论坛只镜像。** 全部功能由 `cyberforums_marketplace_enabled` 控制，默认关。

## 功能

- **店铺组镜像（签名 webhook 接收器，默认关）**：`POST /marketplace/woo/vendor`，由 WP 插件 `wenpai-marketplace-forum-sync` 通过 WooCommerce 原生 webhook（主题 `marketking_vendor.updated`）调用。
  - 只接受 `X-WC-Webhook-Signature` = base64(HMAC-SHA256(body, secret)) 正确的请求；可选校验 `X-WC-Webhook-Source`。开关关或密钥为空时返回 404；未签名的 Woo ping（`webhook_id=N`）回 200、不做事。
  - 商家被批准：创建/更新 `shop-<店铺 URL slug>` 群组（新建时套用店铺组预设），按**邮箱**找论坛账号（已激活、非暂存、未封禁）设为组主；找不到就记为“待对应”（显示脱敏邮箱），**不创建账号**。
  - **店主换人**（同一商家的邮箱对应到另一个论坛账号）：新账号加为组主，**旧店主保留不移除**，组上标记 `mc_owner_review`（`notices` 出现 `owner_changed_review`，并记录旧店主用户名 `mc_owner_review_previous`），管理日志动作 `owner: added_previous_kept`，由管理员人工处理；处理完可把 `mc_owner_review` 改回 false。
  - 商家被停用/删除：只把组标记为 `disabled`，从店铺清单隐藏；**不移出任何成员，不删组**。
  - 语义拒绝（slug 缺失/过长/被占用、旧快照等）回 200 + `result: rejected/stale_ignored`，并写管理日志（避免 Woo 连续 5 次失败自动停用 webhook）。
  - 同一商家用分布式锁串行处理；`generated_at` 早于已同步时间的快照忽略。组名永不改名，slug 变化给出 `store_slug_changed` 提示。
  - slug 上限 15 字符（用户名上限 20 − `shop-`）；MarketKing 允许 25，超长会被拒绝并记日志。
- **已取消灯鹿实名门槛**（2026-10-29 Feng 决定：开店人工审核，不再要求 `deerlogin-verified`）。
- 店铺组创建时自动套用店铺组预设（只组员可见、组员/版主/管理员可发私信、新成员默认关注、关闭自由加入），并把组 id 加到 `pm_tags_allowed_for_groups`。被收编的同名旧组不覆盖其已有设置。
- 店铺资料存为群组自定义字段。同步字段（`mc_source`、`mc_status`、`mc_wp_store_id`、`mc_wc_store_slug`、`mc_wc_synced_at`、`mc_display_name`、`mc_owner_pending`、`mc_owner_email_masked`、`mc_owner_review_previous`）只读；管理员可编辑：`mc_enabled`、`mc_sla_hours`、`mc_order_sla_hours`、`mc_rate_limit`、`mc_brand`、`mc_product_hint`、`mc_owner_review`。新同步的店铺聊天默认关（`mc_enabled`）。
- `GET /marketplace/vendors.json`（仅管理员）：店铺清单，默认隐藏停用店铺（`include_disabled=1` 显示），并带 `woo` 同步状态（最后接收/对账时间，超过 36 小时未对账提示）。
- **每店超时提醒（0.3.0，默认关）**：每小时检查一次，到北京时间 `cyberforums_marketplace_sla_reminder_hour` 点后每店每天发一次。按店铺资料 `mc_sla_hours`（未填 24）找出买家等待超时的店铺私信，以 system 私信给该店铺组；没有超时不发；停用店铺跳过。判断规则与原数据查询 2 相同（本店成员=商家；【平台介入】/会话合并/会话闲置/超时提醒、discobot、其他管理人员=中立；其余含 system 代发=买家）。提醒话题本身带 `mc_internal` 标记，不会被再次统计。用来取代“每开一个店克隆一份”的数据查询 2 + 自动化 20。
- **会话闲置（0.3.0，默认关）**：每天一次（`cyberforums_marketplace_stale_hour`，北京时间），店铺私信超过 `cyberforums_marketplace_stale_idle_days`（14）天没有新帖 → 加标签 `cyberforums_marketplace_stale_tag`（`闲置`）并发一条“【会话闲置】”说明；之后有新帖（说明帖本身除外）自动去掉标签。已关闭/归档/内部话题跳过。用来取代 hk-forum `/etc/cron.d/marketplace-chat-stale` → 中转服务 `stale-tick`。动作写管理日志（`cyberforums_marketplace_threads`）。
- `POST /marketplace/guests.json`（仅管理员 API 密钥，另需 `cyberforums_marketplace_guest_api_enabled`）：评论访客暂存用户，不改真实会员名字。

## 站点设置

| 设置 | 默认 | 说明 |
|---|---|---|
| `cyberforums_marketplace_woo_webhook_enabled` | 关 | 接收器开关 |
| `cyberforums_marketplace_woo_webhook_secret` | 空 | 与 Woo webhook 相同的密钥（秘密值，不进仓库/聊天） |
| `cyberforums_marketplace_woo_webhook_source` | 空 | 可选，Woo 站点 `home_url(/)` |
| `cyberforums_marketplace_sla_reminders_enabled` | 关 | 每店超时提醒 |
| `cyberforums_marketplace_sla_reminder_hour` | 9 | 北京时间几点后发 |
| `cyberforums_marketplace_stale_enabled` | 关 | 会话闲置 |
| `cyberforums_marketplace_stale_idle_days` | 14 | 几天无新帖算闲置 |
| `cyberforums_marketplace_stale_hour` | 4 | 北京时间几点后检查 |
| `cyberforums_marketplace_stale_tag` | 闲置 | 标签名 |

## 测试

```bash
LOAD_PLUGINS=1 bin/rspec plugins/discourse-cyberforums-marketplace/spec
```

0.3.0 在 Discourse 2026.10.0（beta，`a4a98d5`，与线上一致）上跑：60 examples, 0 failures；rubocop、stree 无问题。

上线切换（需 Feng 批准）：先开新功能并与旧自动化/定时任务并行一天对比，再停自动化 20、删查询 2、删 `marketplace-chat-stale` 定时任务。

## 安装

需要改论坛 `app.yml` 加 `git clone` 本仓库并重建容器（会停站几分钟），**必须 Feng 批准**。
