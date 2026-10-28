# discourse-cyberforums-marketplace

Cyberforums 商城的论坛插件。设计见 linuxjoy `docs/plans/2026-10-28-marketplace-multi-vendor-native-design.md`。

第一期做的事（全部由站点设置 `cyberforums_marketplace_enabled` 控制，默认关）：

- 新建 `shop-` 开头的群组时，自动套用店铺组设置（只组员可见、组员/版主/管理员可发私信、新成员默认关注、关闭自由加入），并把组 id 追加到 `pm_tags_allowed_for_groups`。
- 灯鹿实名门槛：不在“实名组”（默认 `deerlogin-verified`）的人被加进店铺组会立即移出并写管理日志；离开实名组会被移出所有店铺组。没有管理员例外；实名组不存在时一律拒绝。
- 店铺资料存为群组自定义字段（`mc_vendor_id`、`mc_enabled`、`mc_display_name`、`mc_sla_hours`、`mc_order_sla_hours`、`mc_rate_limit`、`mc_wp_store_id`、`mc_brand`、`mc_product_hint`），可通过群组更新接口编辑；只对管理人员和本组成员可见。
- `GET /marketplace/vendors.json`（仅管理员 / 管理员 API 密钥）：所有店铺组的资料、店主/客服、是否实名、校验问题。给聊天中转服务读。
- `POST /marketplace/guests.json`（仅管理员 API 密钥，另需 `cyberforums_marketplace_guest_api_enabled`）：为评论访客创建/查找暂存用户，替代 product-comments 的 `ensure-guest.rb`。与旧脚本不同：**不会改动真实会员的名字**。

未做（第二期）：每店 SLA 超时提醒任务、会话闲置任务、群组设置页里的店铺资料表单。

## 测试

在论坛开发环境里：

```bash
LOAD_PLUGINS=1 bin/rspec plugins/discourse-cyberforums-marketplace/spec
```

## 安装

需要改论坛 `app.yml` 加 `git clone` 本仓库并重建容器（会停站几分钟），**必须 Feng 批准**。
