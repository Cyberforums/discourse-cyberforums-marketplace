# Cyberforums 商务界面 · 设计 round-1（cf-design）

> **用户已拍板方案 A（10-30）**，本稿为 round-1 定稿。
> 状态：方向 A（货架 IM）**第二批**：① 咨询商品、② 订单售后（按负责人 10-30 定稿修订）、③ 售前留资、④ 商家三栏（Discourse PM，含询商 / 订单 / 售后三种私信版式），以及子页面「我的订单 / 订单详情 / 售后」。全部为**示例数据**。
> 这些是本地设计稿：没有提交，没有 `git add`，也没有切分支；插件里那 3 个未提交文件没有碰。
> 字段按 `~/grokbot-memory/teams/cyberforums/API-CONTRACT-cf-woo-r1.md`（负责人 10-30 00:35 拍板）对齐。

## 审计 round-1 修改（cf-audit 86 分，按 design-audit/round-1/FIXES.md）

| 项 | 怎么改的 |
|---|---|
| F1 点击区 | 新增 token 组 `hit`：`--cf-hit-min`（24px）和 `--cf-hit-touch`（44px），CSS 里没有 px 字面量。文字链 `.cf-link` 和文字按钮 `.cf-textbtn` 改成 inline-flex，并设 `min-height: var(--cf-hit-min)`；按钮、芯片、快捷问题、筛选和折叠头也都不低于 min。挂件在手机全屏时（`@container widget (max-width: 30rem)`），文字链和图标钮的最小高度提到 touch；带边框的小块（按钮、芯片、快捷问题）用 `::after` 上下扩展到 touch，外观不变；滚动容器补了 padding，防止扩展区被裁掉。selfcheck 第 11 条用 Chrome 实测每屏所有 a / button / summary。 |
| F2 钩子 | 已经全部是 `data-mc-*`。selfcheck 第 8 条扫 HTML、CSS 和生成脚本，旧前缀 0 处。allowlist 清单见钩子一节，待 cf-frontend 核对。 |
| F3 补图 | 挂件 6 页（①②③、我的订单、订单详情、售后）补了桌面亮 / 暗整页图，桌面上显示为右侧浮层面板，高度用 `--cf-size-widget-desktop-h`。商家三栏补了窄屏暗色。每页四套截图齐全。 |
| F4 页面结构 | 挂件顶栏的店名 / 页名改成 `h1`，商家 PM 标题改成 `h1`，组件页加了视觉隐藏的 `h1`。所有 nav 和 aside 都有 aria-label，同屏重名 0（parts 里的示例加「（示例：…）」后缀区分）。 |
| S1 时间戳 | 消息不再逐条挂时间，改成居中的时间段分隔，同一段 5 分钟内只出现一次；每条仍保留视觉隐藏的 `<time>` 供读屏使用；发送失败照常显示。 |
| S2 暗色卡面 | 新增 token `card-bg` / `card-border`。暗色下卡面对会话底 1.30，边框对会话底 1.99，都 ≥1.25（`surfaceChecks`），没有加阴影。卡面上的文字另加了 8 组 AA 检查。 |
| S3 重复商品 | 询商卡发出后，商品条收成一行（「正在咨询：… ¥199.00 · 已发给商家」），去掉「发给商家」和缩略图（`data-mc-state="sent"`）。 |
| S4 品牌感 | 本轮未做。 |

### 复核（两批 90 分）后的修改

| 项 | 怎么改的 |
|---|---|
| F1 / F3 复核 | 审计看到的 21px 和缺桌面图来自修复前的版本。现在 selfcheck 第 11 条实测 25 屏全部通过（手机 ≥44、桌面 ≥24）；挂件 6 页和帖子 3 页四套截图齐全。 |
| F5 订单去重 | 商家订单页去掉顶部置顶的当前订单（售后页也去掉了置顶的关联订单行，只留进度）；右栏历史订单排除当前单。当前单在一屏里只出现在流内订单卡和右栏「当前状态」两处，另外系统事件行里会提到订单号。PM 标题改成商品名，不再写订单号。 |
| S5 后台链接 | 「在 Woo 后台查看」每屏只留右栏一处；流内订单卡和历史订单行没有操作段，订单号本身链接到 `admin_url`；输入框下的提示也去掉了链接。 |
| S6 事件表 | 订单页右栏事件表为发卡、付款 2 行，流内也是这 2 条（询商页的事件是询商和带商品快照）；售后页为 3 行，与流内一致，不是遗漏。 |
| F6 在线状态 | ①③ 和子页面的顶栏都去掉了「● 在线」，只保留 `reply_hint`（示例「工作日约 2 小时内回复」）；② 的 `reply_hint` 为空，整行隐藏。表单提示「商家离线时…」改成「回复会同时发到邮箱」。selfcheck 第 13 条检查 HTML 里不出现「在线」「离线」或绿点。 |
| 示例数据自洽 | ② 的 #10077 在对话里已完成，所以顶部芯片、折叠条、流内订单卡和「我的订单」都显示「已完成」；快捷问题「催发货」换成「开发票」。商家三栏换成另外 3 位买家的订单（xiaowang：#10102 / #9950；lin_dev：#10088 / #10035 / #9961；chen.m：#10064 / #10045），不再和 ② 买家的订单号撞号；事件表、系统行、卡片、右栏的状态一致。 |
| h1 | 每个 `?screen=` 区块第一个子元素都是 `<h1 class="cf-sr-only">`（标准 sr-only：1px、clip / clip-path、不用 display:none / hidden，也不在 iframe 里），同时保留挂件 / PM / 话题自己的可见 h1。selfcheck 第 9 条逐屏检查。本机没有装 axe，请审计方再跑一次。 |
| F7 开发说明 | 界面上删掉两句：商品卡底部「价格和库存实时读取 Woo（1 分钟缓存），不写进帖子。」和商家右栏「vendor-orders · 不含当前订单 · 最近 5 单 · 不含明文邮箱与地址」，内容挪进下面字段表。另外又扫出来一并挪走或改写：商家右栏「会话类型」后的 `order` / `inquiry` 原值、「售后进度」后的 `pending` 原值、「状态（Woo）」后的 `processing` 等原值（改叫「订单状态」，只显示中文标签）、「标识：Discourse 用户名」（改成「论坛用户」）、侧栏事件表列名「状态（Woo）」（改成「订单状态」）、订单详情页状态旁的 `completed` 原值；买家页三处说明「只读展示，数据来自 Woo」「订单状态以 Woo 为准，这里只读展示」「退款结果以 Woo 订单状态为准…这里同步」改成面向买家的话（「会打开店铺的订单页」「退款完成后，这里会显示『已退款』」）；PM 输入框下提示「…以系统行同步到这里」改成「…会自动同步到这里」；每屏 sr-only h1 去掉括号里的 `data-mc-*` 注释。selfcheck 第 15 条检查。 |
| 正文标签 | 卡片和帖子正文的 `article` / `header` / `footer` 全部改成 `div`，卡内商品名的 `h4` 改成 `p`（顺带关掉 S8）。见「渲染位置」一节的标签约定。selfcheck 第 14 条检查。 |
| 白名单 | cooked 只用 9 个属性，`stock` 已删；渲染位置表加了「标签」列，见上面钩子一节。selfcheck 第 12 条检查。 |

## 文件

| 文件 | 作用 |
|---|---|
| `tokens.json` | 统一 token 的唯一来源：亮 / 暗两套颜色（含 `card-bg` / `card-border`）、字号、行高、间距、圆角（≤8px）、边框、阴影（只有 focus 环）、尺寸（含 `inbox` / `commerce-side` / `merchant-h` / `widget-desktop-h`）、点击区 `hit`（`--cf-hit-min` / `--cf-hit-touch`）、动效；`surfaceChecks` 管暗色卡面 ≥1.25 |
| `../../../assets/stylesheets/common/cf-tokens.css` | 插件内的 token 副本，`build_tokens.py` 同时生成，与 `tokens.css` 字节一致（selfcheck 第 16 条）；文件头注明生成物、源为本目录 `tokens.json`、归 cf-design。`plugin.rb` 注册归 cf-frontend，这里没动 |
| `tokens.css` | 由 `build_tokens.py` 生成（`:root` 是亮色，`[data-theme="dark"]` 是暗色），不要手改 |
| `build_tokens.py` | `python3 build_tokens.py` 生成 tokens.css 并输出 WCAG 报告：文字 ≥4.5，非文字 ≥3 |
| `build_previews.py` | 生成 `direction-A.html`（全部页面与边缘态都从这里出） |
| `base.css` | 共用组件结构层；本批新增段落以 `BATCH2-START` 注释开头 |
| `direction-A.css` | 方向 A 的皮肤；方向级覆盖写成 `--cf-a-*` 变量，值仍引用全局 token |
| `preview.css` | 预览页外壳和截图模式（`?screen=<id>&vp=mobile&theme=dark`，id 见 index.html 导航图） |
| `direction-A.html` / `index.html` | 预览页；index.html 有「入口 → 页面」导航图 |
| `selfcheck.sh` | 扫硬编码颜色、px、非 token 字号、结构选择器、渐变 / 毛玻璃 / 上浮、阴影、内联样式、旧 `data-cf-` 前缀；检查表单 label、honeypot `aria-hidden`、钩子取值、重复 id；跑 AA 与最小字号 |
| `screenshots/` | 见文末「截图」 |
| `_wip/` | 方向 B / C 的 CSS 草稿（钩子前缀已同步改为 `data-mc-`），**本批不评审** |

## 上一轮（10/29）各版回顾

| 版本 | 做了什么 | 用户评价 |
|---|---|---|
| 初版系统卡 | 蓝渐变、4px 左色条、浅蓝底、圆角阴影、实心按钮 | 「好多了，但……太像 AI 垃圾」 |
| A 细线工单（上线过） | 细左边线、小号大写标题、下划线文字链 | 「这太丑了」（太空、发灰） |
| v1 B–F：B 收件箱条、C 静音面板 + 待首响、D 等宽账页、E 一行系统提示、F 缩略图商品行 | 组件库式的对照页 | 没选，用户又要求「重新设计几个版本」，并追问「就没有更优雅舒适的……仿小票」 |
| （更早一组 B 软面板 / C 服务台 / D 商品优先 / E Linear 静风） | 画布链接打不开，图片没送达 | 用户没看到 |
| R1 热敏小票 | 锯齿边、虚线、等宽字 | 被选中，和 R3 组合 |
| R2 餐厅客单 | 衬线店名 + 点划线（当时最推荐） | 没选 |
| R3 短笺 | 用完整句子，左侧压线 | 被选中，和 R1 组合 |
| R4 展签 / R5 价签纸 | 博物馆标签 / 价格做主视觉 | 没选 |
| **R1+R3（现网）** | 锯齿 clip-path、居中店名、衬线斜体问候、等宽 11.5px、投影 | 用户说「就是你说的类型」，之后上线。审计基线 64/100 |

结论：用户反感的是「模板味」，也就是渐变、色条、实心蓝和胶囊徽章；他想要的是「像实物一样克制、读起来舒服」。A 方向从第二点出发，又不照搬小票的锯齿和投影。

## 方向 A · 货架 IM

- **定位**：手机淘宝 IM 的会话页。灰底对话，白色卡片加细边；商品卡横排，价格做主信息；订单芯片条可以横向滑动；移动端是全屏会话。
- **为什么选它**：章程定了「买家主路径 = 挂件 IM 皮」。国内买家最熟悉淘宝式会话，学习成本最低，信息密度也最高。
- **和上一轮的区别**：不靠装饰制造「物件感」，层级只靠排版、细线和留白。去掉了锯齿、投影、衬线斜体和整卡等宽字。系统事件不再做成卡片。
- **风险**：太像淘宝可能显得没有品牌感，暂时只靠一个品牌蓝和字体来补。Discourse 的 cooked 内容会剥掉 class，需要 decorate JS 按 `data-mc-*` 回填 class，详见钩子一节。

### 审计基线（round-0，64/100）的问题，A 逐条怎么处理

> 下面依据负责人转述的基线要点；`BASELINE-round0.md` 原文本批没有逐行读完。

| 基线问题 | A 的处理 |
|---|---|
| 品牌蓝有两个（`#356aea` 和硬编码 `#2f6fed`） | 合并为 `--cf-color-brand` `#2b58c4`（在 `#356aea` 基础上加深，保证浅底文字过 AA）；暗色用 `#93b0f5` |
| 状态色没有 token 化 | 分五档：灰 neutral / 蓝 info / 橙 warning / 绿 success / 红 danger，各有 `-fg` / `-bg` / `-border` 三个 token |
| 最小字号 9.6px | 最小档是 `--cf-font-size-caption` 12px，组件 CSS 里没有 px 字面量 |
| 暗色下发送钮文字、占位符、副标题、边框对比度不够 | 发送钮文字 `text-link` 落在 `brand-subtle` 上，暗色 6.68；占位符用 `text-tertiary`，暗色在 surface 上 6.04；副标题用 `text-secondary`，8.57；输入框边框用 `border-input`，暗色 3.67:1 |
| 毛玻璃胶囊悬浮钮、大阴影、悬停上浮 | 不使用。没有 backdrop-filter，没有 translateY，阴影只保留 focus 环 |
| 面板大圆角加 64px 阴影 | 圆角最大 8px（`--cf-radius-lg`），面板无阴影，移动端直接全屏、圆角为 0 |
| 系统卡三色粗顶边条，已付款整块绿底 | 系统事件改成居中一行浅灰小字，例如「订单 #10077 已付款 · 21:42」，没有色条也没有色块 |
| 实心蓝营销按钮、圆形实心蓝发送钮 | 全站没有实心蓝按钮。发送钮是矩形、浅蓝底配蓝字，带「发送」文字；「去支付」是描边按钮，其余操作都是文字链 |
| 四色彩底胶囊徽章 | 状态是浅底深字的直角小标签（圆角 2px），不是胶囊，一张卡最多一个 |
| 输入框没有 label，发送钮没有文字 | 每个输入框都有 `<label>`（视觉隐藏），图标按钮都有 `aria-label`，发送钮有文字 |
| 移动端是浮层卡片 | 改成淘宝式全屏会话：顶栏、商品条、芯片条固定在顶部，输入区固定在底部，只有对话区滚动，高度用 100dvh |

### 已画的内容

**对 ①② 的修订（负责人定稿）**
- 状态变化事件行统一写成「订单 #10077 状态更新为「已完成」」。
- 「申请退款」是跳 Woo 的文字链（订单卡、快捷栏、订单行、子页都一样），**聊天里不画成事件行**。`refund_requested`、`nudge_ship`、`shipped` 三种事件行已删除；事件行只用契约现有的 `inquire / product_ctx / order_card / order_paid / status_changed`。
- 「催发货」仍是快捷问题：发一句固定文本，不产生事件行。
- 订单卡的操作改成按后端 `actions[]` 渲染，去掉了「再次咨询」。
- ② 的会话根是 `data-mc-thread="order"`；发生 escalate 或订单变 refunded / cancelled / failed 后，`thread_kind` 切成 `aftersale`。

**③ 售前留资**（`data-mc-thread="presales"`，`?screen=presales`）
- 没有商品条和芯片条。店铺先打招呼，再在对话里放一张「留下联系方式」表单卡（头 / 字段 / 操作三段）。
- 称呼、邮箱必填；每个输入都有可见 `<label>`；错误用 `aria-invalid` + `aria-describedby` 关联；honeypot 放在 `aria-hidden="true"` 的视觉隐藏块里，`tabindex="-1"`；带隐藏的 `form_started_at`。提交即 `inquire` 首条消息，不新增接口。
- 全部状态（`?screen=presales-states`）：待填写、校验错误、提交中、提交失败（内容保留，可重试）、成功（回显脱敏邮箱）、已登录（走 `session/bridge` 免填）。

**④ 商家三栏**（Discourse PM，`?screen=merchant-inquiry|merchant-order|merchant-aftersale`）
- 左栏：店铺私信收件箱。每行有头像、买家标识、会话类型、时间、最后一条消息摘要（单行截断）、未读数、「待回复」标签；当前会话用 `aria-current="page"`。WP 收件箱已冻结，不画。
- 中栏：店铺精简皮肤的 PM 对话。标题下的上下文区按 `data-mc-topic` 切换：
  - `inquiry`：商品快照行（图、名、价、库存 `stock_status`、快照时间提示）。
  - `order`：不再置顶当前订单（F5）；流内订单卡和右栏「当前状态」已经够用。
  - `aftersale`：售后进度（买家发起 › 商家处理中 › 处理完成，来自 `aftersale.escalation`）+ 关联订单行。
  - 商家视角的订单卡和订单行只给「在 Woo 后台查看」；订单 / 售后版式底部提示「改单、退款请在 Woo 后台处理」。
- 右栏：commerce 侧栏，依次是客户（Discourse 用户名，界面上标为「论坛用户」，访客显示「访客 · 短哈希」；邮箱只给 `email_masked`）、当前状态（会话类型、订单号、订单状态、实付；`thread_kind` 和 Woo 状态原值只放在 `data-mc-*` 上，界面不显示）、事件时间线（事件和 Woo 状态分两列）、该客户在本店的历史订单（`vendor-orders`，与订单行同构，最多 5 单，**不含当前订单**，不含明文邮箱和地址）。
- 窄屏降级：容器宽度 < 68rem 时侧栏折叠，PM 头部出现「客户与订单」按钮（`aria-expanded` / `aria-controls`）和一行状态摘要；< 46rem 时收件箱也收起，换成「‹ 收件箱」返回链接。

**子页面**（挂件内，手机全屏）
- 我的订单（`data-mc-page="my-orders"`）：订单行列表，操作按 `actions[]` 渲染。
- 订单详情（`order-detail`）：状态（中文 + Woo 原值）、下单 / 付款时间、实付、商品清单（`items[]` 最多 6 条，`item_count` 给真实件数）；底部「发到对话 / 查看订单 / 申请退款」。
- 售后（`aftersale`，同时带 `data-mc-thread="aftersale"`）：售后进度、关联订单、退款说明；「申请退款」跳 Woo。
- 没有物流数据，不画「查物流」；所有改单操作只跳 Woo（`view_url` 或 `actions[].url`）。

**组件与边缘态**
- `?screen=parts`：芯片条（无订单 / 加载 / 失败 / 7 单 / 收起）、对话空、询商卡（超长 / 加载 / 失败）、订单卡（各状态的 actions、多件、超长、加载、失败、缺图）、同一单多次变状态、侧栏（无订单 / 失败）、五档状态。
- `?screen=parts2`：订单行（正常、待付款、缺 thumb / first_item / item_count / actions、无公网 url、四项全缺、加载）、我的订单（空 / 失败）、订单卡缺字段、订单详情超过 6 件、售后进度（处理中 / 已完成）、收件箱（加载 / 空 / 失败）、商家侧栏（访客、历史订单空 / 失败）。

## 组件 → class / data 钩子（给 cf-frontend）

钩子前缀统一为 `data-mc-*`（上一批的旧前缀已全部改名；token 前缀 `--cf-*` 不变）。CSS 只选 class，HTML 同时带 `data-mc-*`：Discourse cooked 会剥掉 class，decorate JS 按 `data-mc-*` 回填（现网 `data-mc-event` 已是先例）。禁用 nth-child 等结构选择器。

### 渲染位置（帖子正文 cooked vs JS 外壳）

按 cf-frontend 白名单：**帖子正文只放行 9 个属性**（`data-mc-card/part/state/status/tone/event/order/product/action`）。`data-mc-stock` 不在白名单：库存只出现在 JS 实时渲染的商品卡和 PM 商品快照里，不进 cooked。下表由 `direction-A.html` 自动统计（cooked 范围 = 询商卡、订单卡、系统事件行、`.cf-post__cooked`），selfcheck 第 12 条保证 cooked 里没有第 10 个属性。

**标签约定**：帖子正文和所有卡片（询商卡、订单卡、订单行、留资表单、JS 商品卡）**只用 `div` / `p` / `span` / `a` / `button` / `time` 等通用标签，不用 `article` / `header` / `footer`**，卡片根、头段、操作段的语义只靠 `data-mc-card` / `data-mc-part`（selfcheck 第 14 条）。卡内商品名也不用标题标签（`p`）。JS 渲染的外壳（挂件顶栏、PM 顶栏、收件箱头、商家三栏顶栏、话题头、侧栏 `aside` / `nav` / `section`）保留语义标签，它们不经过 cooked。

**帖子正文（cooked，走白名单）**

| 属性 | 全部取值 | 标签 | 用在 |
|---|---|---|---|
| `data-mc-card` | `inquiry` `order` `product` | `a` `div` | 卡片根：询商卡 / 订单卡；商品帖 cooked 占位链接（`product`） |
| `data-mc-part` | `action` `actions` `amount` `body` `created` `error` `facts` `first-item` `head` `info` `item-count` `label` `note` `order-no` `price` `product` `shop` `sku` `spec` `status` `thumb` `title` | `a` `div` `p` `span` `time` | 卡片内各段（`head` 头段、`body` 体段、`actions` 操作段等） |
| `data-mc-state` | `actions-fallback` `error` `gone` `loading` `missing` | `a` `div` `p` `span` | 加载 / 失败 / 已下架 等状态 |
| `data-mc-status` | `cancelled` `completed` `failed` `on-hold` `pending` `processing` `refunded` | `div` `p` `span` | Woo 状态原值（状态标签、系统卡快照） |
| `data-mc-tone` | `danger` `info` `neutral` `success` `warning` | `span` | 状态色档 |
| `data-mc-event` | `inquire` `order_card` `order_paid` `product_ctx` `status_changed` | `p` `tr` | 系统卡事件类型 |
| `data-mc-order` | 订单号（纯数字，如 `10077`） | `div` `p` | 订单号 |
| `data-mc-product` | 商品 ID（纯数字，如 `1201`） | `a` `div` | 商品 ID |
| `data-mc-action` | `pay` `refund` `view` | `a` | 操作链接 / 按钮 |

**帖子正文的 aria / role**（Discourse sanitizer 会剥掉，由 decorate JS 按 `data-mc-*` 补回，不进白名单）

| 属性 | 取值 | 标签 | decorate 怎么补 |
|---|---|---|---|
| `role` | `article` | `div` | 给卡片根（`[data-mc-card]`）补 `role="article"`；头段 `[data-mc-part="head"]`、操作段 `[data-mc-part="actions"]` **不补 role** |
| `aria-busy` | `true` | `div` | 加载态：JS 渲染时自己加 |
| `aria-hidden` | `true` | `span` `svg` | 装饰图标、骨架：补 `aria-hidden="true"` |
| `aria-label` | 商品名 / 「商品图」等文案 | `span` | 缩略图占位：按商品名补 |
| `role` | `img` `status` | `p` `span` | 缩略图补 `img`、系统事件行补 `status` |

`svg` 图标在 cooked 里同样会被剥掉，由 decorate JS 注入。

**只在 JS 渲染的外壳里用（不进 cooked）**

| 属性 | 全部取值 | 标签 | 挂在 |
|---|---|---|---|
| `data-mc-page` | `aftersale` `my-orders` `order-detail` | `section` | 挂件子页面根 |
| `data-mc-quick` | `catalog` `custom` `deliver` `invoice` `refund` `stock` `view` | `a` `button` | 快捷问题 |
| `data-mc-side` | `mine` `theirs` | `div` | commerce 侧栏分区 |
| `data-mc-stock` | `instock` `onbackorder` `outofstock` | `span` | JS 商品卡、PM 商品快照的库存标签 |
| `data-mc-surface` | `merchant-pm` `shop-pm` `topic` `widget` | `div` `section` | 外壳根 |
| `data-mc-thread` | `aftersale` `inquiry` `order` `presales` | `a` `section` | 挂件会话根、收件箱行（= `thread_kind`） |
| `data-mc-topic` | `aftersale` `discussion` `inquiry` `order` `product` `qa` | `div` `section` | PM 根、商家三栏、论坛话题根 |

`data-mc-screen` / `data-mc-vp` 只在预览页用。

**正文订单卡的操作（负责人 10-30 定）**：帖子正文里的订单卡默认只有「查看订单」；「去支付」「申请退款」只在订单数据带契约 `actions[]` 时输出。预览里带这两个操作的示例（parts「待付款 / 处理中 / 付款失败 + 带 actions[]」、② 对话里的 #10077 / #10031）都是 actions[] 有值的情况；parts 里保留了「默认（正文无 actions[]）→ 只有查看订单」。右栏、挂件订单芯片 / 我的订单 / 订单详情这些实时区域不受此限，按状态出操作。条件说明只写在这里和 parts 标注里，不进用户界面。

**询商卡**：没有「来自 xx」，买家身份由 PM 作者和右栏给出。结构：图、商品名、规格（可选）、价格、SKU、`data-mc-action="view"` 的「查看商品」链接。

### 顶层钩子

| 钩子 | 取值 | 挂在 |
|---|---|---|
| `data-mc-thread` | `inquiry\|order\|aftersale\|presales`（= 契约 `thread_kind`） | 挂件会话根 `.cf-widget`、收件箱行 `.cf-inbox__row` |
| `data-mc-topic` | PM：`inquiry\|order\|aftersale`；帖子：`qa\|product\|discussion` | 论坛 PM 根 `.cf-pm`、商家三栏 `.cf-mc`、话题根 `.cf-topic` |
| `data-mc-card` | `inquiry\|order\|order-row\|lead-form\|product` | 卡片根（头 / 体 / 操作三段；商家视角的订单卡和订单行没有操作段，订单号本身就是后台链接，见 S5） |
| `data-mc-page` | `my-orders\|order-detail\|aftersale` | 挂件子页面根 |
| `data-mc-surface` | `widget\|shop-pm\|merchant-pm\|topic` | 外壳 |

### 组件表

| 组件 | class | data 钩子 |
|---|---|---|
| 卡片三段 | `.cf-card` › `__head`（`__label`、`__meta`）/ `__body` / `__actions`；`__error`、`__hint` | `data-mc-part="head\|body\|actions\|error\|actions-none"`，`data-mc-state="loading\|error\|actions-fallback\|actions-none"` |
| 询商卡 | `.cf-inquiry-card` + `__product` `__info` `__title` `__spec` `__facts` `__price` `__currency` `__sku` `__note` `__shop` | `data-mc-product`，`data-mc-part="product\|info\|title\|spec\|facts\|price\|sku\|note\|shop\|action"` |
| 订单卡 | `.cf-order-card` + `__no` `__main` `__info` `__title`（`--fallback`）`__more` `__state` `__amount` `__amount-k` | `data-mc-order`，`data-mc-status`（Woo 原值），`data-mc-part="order-no\|created\|first-item\|item-count\|amount\|thumb\|action"`，`data-mc-action="pay\|view\|refund"` |
| 订单行 | `.cf-order-list`（`__msg`、`__msg--error`）、`.cf-order-row`（`--compact`）+ `__head` `__no` `__date` `__status` `__body` `__info` `__title`（`--fallback`）`__count` `__amount` `__actions` | `data-mc-card="order-row"`、`data-mc-order`、`data-mc-status`；`data-mc-part="order-list\|list-empty\|list-error\|head\|body\|actions\|order-no\|created\|first-item\|item-count\|amount\|thumb\|action"`；`data-mc-state="loading\|missing\|actions-fallback\|actions-none"` |
| 状态标签 | `.cf-status`、`__dot`、`__label`、`__raw` | `data-mc-status`、`data-mc-tone="neutral\|info\|warning\|success\|danger"`；也用于「待回复」（`data-mc-part="pending"`）和库存（`data-mc-part="stock"` + `data-mc-stock`，**仅 JS 渲染的卡片**） |
| 系统事件行 | `.cf-event`、`__text`、`__sep`、`__time` | `data-mc-event="inquire\|product_ctx\|order_card\|order_paid\|status_changed"`，`data-mc-order` |
| 挂件外壳 | `.cf-widget`、`__head` `__who` `__name` `__sub` `__online` `__layout` `__main` | `data-mc-surface="widget"`、`data-mc-thread`、`data-mc-page`；`data-mc-part="widget-head"` |
| 商品条 | `.cf-product-strip`（`--sent`）、`__info` `__title` `__price` `__send` `__done` | `data-mc-part="product-strip\|product-send"`，`data-mc-state="sent"`（询商卡发出后收成一行） |
| 订单芯片条 | `.cf-order-rail`、`__label` `__chips` `__all` `__msg` `__toggle` `__peek`；`.cf-order-chip`（`--skeleton`）`__no` `__amount` `__tag` | `data-mc-part="order-rail\|rail-chips\|order-chip\|rail-all\|rail-toggle\|chip-tag\|rail-empty\|rail-error"`，`data-mc-state="ok\|empty\|loading\|error\|collapsed"` |
| 留联系方式（① 折叠） | `.cf-contact`、`__summary` `__hint` `__fields` | `data-mc-part="contact"` |
| 留资表单（③） | `.cf-lead-form` + `__hp` `__note` `__bridge`；`.cf-field` `__label` `__req` `__input` `__error`；`.cf-alert` | `data-mc-card="lead-form"`、`data-mc-state="idle\|invalid\|submitting\|error\|success\|bridge"`；`data-mc-part="field-name\|field-email\|field-error\|honeypot\|lead-error\|lead-success\|lead-bridge\|lead-note"`；`.cf-alert[data-mc-tone="danger\|success"]` |
| 对话 / 消息 | `.cf-thread`（`--empty`）、`.cf-daychip`、`.cf-msg`（`--mine` / `--theirs`）`__avatar` `__main` `__name` `__meta`；`.cf-bubble` | `data-mc-side`，`data-mc-state="failed"`，`data-mc-part="thread\|msg\|bubble\|msg-meta\|daychip"` |
| 快捷问题 | `.cf-quick`、`.cf-quick__item` | `data-mc-quick="stock\|invoice\|deliver\|catalog\|custom\|refund\|view"`；`refund` / `view` 是跳 Woo 的链接，带 `data-mc-action` |
| 输入区 | `.cf-composer-dock`、`.cf-composer` `__tools` `__input` `__send` | `data-mc-part="composer-dock\|composer"` |
| 售后进度 | `.cf-steps`（`--vertical`）+ `__item` `__dot` `__time` `__sep` | `data-mc-part="steps\|step"`；整条 `data-mc-state="pending\|done"`，每步 `done\|current\|todo`；当前步 `aria-current="step"` |
| 子页面 | `.cf-page` + `__section` `__title` `__headrow` `__no` `__note` `__items` `__item` `__item-name` `__dock` `__dock-left` | `data-mc-part="page\|detail-status\|detail-items\|item\|aftersale-progress\|aftersale-order\|aftersale-howto\|actions"`；`data-mc-action="send-card"`（发到对话，不改单） |
| 商家三栏外壳 | `.cf-mc` + `__bar` `__brand` `__whoami` `__cols` `__sidetoggle` `__back` | `data-mc-surface="merchant-pm"`、`data-mc-topic`；`data-mc-part="mc-bar\|side-toggle\|back-inbox"` |
| PM 收件箱 | `.cf-inbox` + `__head` `__title` `__filters` `__filter` `__list` `__row`（`--skeleton`）`__avatar` `__who` `__name` `__kind` `__time` `__excerpt` `__flags` `__unread` `__msg` | `data-mc-part="inbox\|inbox-head\|inbox-list\|inbox-row\|excerpt\|unread\|pending\|inbox-empty\|inbox-error"`，行上带 `data-mc-thread`；当前行 `aria-current="page"`；筛选按钮 `aria-pressed` |
| 店铺 PM（精简皮肤） | `.cf-pm` + `__head` `__headrow` `__headmain` `__crumb` `__title` `__peek` `__context` `__stream` `__events` `__composer` `__input` `__hint`；`.cf-pm-post` `__meta` `__name` `__role` `__time` `__body`；`.cf-pm-ctx` `__info` `__title` `__meta` `__price` | `data-mc-surface="shop-pm"`、`data-mc-topic`；`data-mc-part="pm-head\|side-peek\|topic-context\|ctx-product\|snapshot\|pm-stream\|pm-post\|pm-body\|role\|pm-composer\|pm-hint"` |
| commerce 侧栏 | `.cf-side` + `__section` `__title` `__facts` `__row` `__k` `__v` `__mono` `__timeline` `__time` `__empty` `__na` `__foot` `__hash` | `data-mc-part="side\|side-buyer\|side-current\|side-timeline\|side-orders\|buyer-user\|buyer-guest\|email-masked"`，`data-mc-state="none\|error"`；时间线行带 `data-mc-event` |
| 按钮 / 链接 | `.cf-btn`（`--outline` / `--send`）、`.cf-textbtn`（`--link`）、`.cf-link`、`.cf-iconbtn` | 没有实心按钮；「去支付」是唯一的描边操作按钮 |
| 论坛话题（帖子版式） | `.cf-topic` + `__head` `__crumb` `__title` `__meta` `__solved`（`-head` `-label` `-body`）`__posts` `__reply`；帖子 `.cf-post` + `__meta` `__name` `__role` `__time` `__cooked` `__embed` `__actions` | 根 `data-mc-surface="topic"` + `data-mc-topic="qa\|product\|discussion"`；`data-mc-part="topic-head\|solution\|topic-posts\|post\|embed\|topic-reply"`（外壳，JS 加）；采纳标记 `data-mc-part="accepted"` |
| 商品卡（JS 实时渲染） | `.cf-card.cf-product-card` + `__main` `__info` `__title` `__spec` `__facts` `__price` `__note`；`.cf-thumb--lg` | `data-mc-card="product"` `data-mc-product` `data-mc-state="loading\|error\|gone"`；库存 `data-mc-stock="instock\|outofstock\|onbackorder"`；操作 `data-mc-action="view\|inquire"` |

## 每个组件需要的数据字段（对齐 cf-woo 契约 r1）

标记：**有** = 现网已有；**契约已定** = 负责人 10-30 00:35 拍板，可选字段；**待确认** = 需要对应成员回复。

| 组件 | 字段 | 状态 |
|---|---|---|
| 询商卡 / 商品条 / PM 商品快照 | `product.id` `title` `url` `image` `price` `currency` `sku` | 有 |
| | `product.stock_status`、`product.snapshot_at` | 契约已定（可选）；库存只在 JS 渲染的卡片里显示（`data-mc-stock` 不进 cooked） |
| | `product.variant_label`（规格，如「单站授权 · 1 年更新」） | **契约已定（可选）**：缺失时整行隐藏（parts2、parts3） |
| 订单卡 / 订单行（`my-orders` 与 `commerce-context.orders[]` 同形） | `id` `number` `status` `status_label` `total` `currency` `items[]`（截 6）`view_url` `date_created` | 有（A 稿原写 `created_at`，已改为 `date_created`） |
| | `thumb`、`first_item`（字符串）、`item_count`、`actions[]`（`key` / `label` / `url`） | **契约已定（可选）** |
| | `date_paid` | 契约已定（可空，空时显示「—」） |
| | 降级：缺 `thumb` → 灰底首字；缺 `first_item` →「商品明细见订单页」；缺 `item_count` → 不显示件数；缺 `actions` → 只给 `view_url`「查看订单」；没有公网 url → 不渲染操作，提示去「我的账户」 | 已画（parts2） |
| actions 规则 | pending / failed → view, pay；on-hold / processing / completed → view, refund；cancelled / refunded → view | 契约已定；设计定稿后复核 |
| 会话类型 | `thread_kind`：`inquiry\|order\|aftersale\|presales` | 契约已定 |
| 系统事件行 | `inquire / product_ctx / order_card / order_paid / status_changed` | 有；`shipped`、`refund_requested` 不存在，已从设计里删除 |
| 侧栏时间线 / 系统事件行 | Woo status 快照 | **已有**：系统卡自带 `data-mc-status`（`woo_status` 映射中文）：`status_changed` 取 `to_status`，`order_paid` 记 `processing`，`order_card` 记发卡时状态。「—」只用于真正缺值（如询商事件本来没有订单）。系统事件行也带上了 `data-mc-status` |
| 售后 | `aftersale.escalation`（none / pending / done）、`aftersale.since` | 契约已定 |
| | `aftersale_reason`（退款 / 投诉…） | 以后再加，本批不画 |
| 留资 | `name`、`email` 必填，`honeypot`、`form_started_at`、`captcha_token` 照旧（`inquire`）；登录用户走 `GET /v1/session/bridge` | 有 |
| 商家收件箱 | `thread_kind`、`last_message_excerpt`（≤60 字）、`last_message_at` | 契约已定 |
| | `unread` | **现在没有**，以后补在 `merchant/threads`（int）。默认不显示角标，只看「待回复」；parts2 画了补上之后的样子 |
| | 待回复状态与排序 | 有（`merchant_inbox.py`） |
| 商家侧栏 · 客户 | `email_masked` | 有（仅商家视角） |
| | 买家标识：登录 = Discourse 用户名；访客 = 加盐邮箱哈希 | **已定**：页面显示「访客 · 哈希前 6 位」 |
| 商家侧栏 · 历史订单 | `GET marketplace-chat/v1/vendor-orders?vendor_id=&buyer=&limit=5`，行结构同订单行；最近 5 单、**不含当前订单**（F5）、不含明文邮箱与地址（原右栏底部「vendor-orders · …」说明，F7 挪到这里） | 契约已定 |
| | 订单链接 | **已定**：vendor-orders 只给商家用，链接字段是 `admin_url`（Woo 后台订单编辑页），这个接口没有 `view_url`。商家侧每屏只在右栏「当前状态」保留一处「在 Woo 后台查看」，其他位置都用订单号链接（S5）。买家侧订单链接来自买家自己的订单接口（`actions[].url`），与 vendor-orders 无关 |
| 挂件头 | `shop.reply_hint` | **可选文本**，为空时整行隐藏（② 示例就是空的）；只有服务时效时显示「约 N 小时内回复」。`shop.online` **不做**：全项目不画在线状态，也没有绿点（selfcheck 第 13 条） |
| 快捷问题 | 前端固定文案，不新增接口；「申请退款 / 查看订单」用 `actions[].url` / `view_url` | — |
| 商品发布帖 · 商品卡 | 价格和库存实时读取 Woo（1 分钟缓存），不写进帖子（原卡片底部说明，F7 挪到这里）。cooked 只存占位链接 `<a data-mc-card="product" data-mc-product="{id}">`；JS 读 `GET marketplace-chat/v1/products/{id}`（公开只读，60s 缓存）取 `title` `image` `price` `variant_label` `stock_status` `url` | 契约已定；加载中 / 失败 / 已下架（404 → 保留普通链接）已画（parts3） |

## 现有硬编码颜色 → 新 token（迁移建议）

依据 Mac 工作区里的 `assets/stylesheets/cyberforums-commerce-pm-sidebar.scss`，含未提交改动，2026-10-30 读取，共 20 行：

| 行 | 现值 | 用途 | 换成 |
|---|---|---|---|
| 81 / 82 | `rgba(196,122,26,.16)` / `#8a5408` | 橙徽章底 / 字 | `--cf-color-warning-bg` / `--cf-color-warning-fg` |
| 86 / 87 | `rgba(47,111,237,.14)` / `#1d4fbf` | 蓝徽章 | `--cf-color-info-bg` / `--cf-color-info-fg` |
| 91 / 92 | `rgba(122,106,79,.16)` / `#5c4e36` | 灰徽章 | `--cf-color-neutral-bg` / `--cf-color-neutral-fg` |
| 96 / 97 | `rgba(31,138,76,.14)` / `#146338` | 绿徽章 | `--cf-color-success-bg` / `--cf-color-success-fg` |
| 103 / 104 | `rgba(194,59,46,.14)` / `#9a2a20` | 红徽章 | `--cf-color-danger-bg` / `--cf-color-danger-fg` |
| 136 / 142 | `#1f8a4c` / `#c47a1a` | 已付款 / 状态变更的左色条 | **删除**：事件改为居中一行灰字 `.cf-event` |
| 214 / 215 / 216 | `#222` / `#666` / `#bdbdbd` | 小票墨色 / 次要文字 / 虚线 | `--cf-color-text-primary` / `--cf-color-text-secondary` / `--cf-color-border-strong` |
| 224 | `#fbfaf6` | 小票纸底 | `--cf-color-bg-surface` |
| 229 / 230 | `rgba(0,0,0,.04)` / `rgba(40,30,10,.08)` 阴影 | 小票投影 | **删除**（`--cf-shadow-none`） |
| 337 / 346 | `#3a3a3a` / `#2a2a2a` | 问候语 / 正文 | `--cf-color-text-primary` |

同一个文件里还有 px 字号字面量：11.5px、12.5px、10px、13px、11px。全部换成 `--cf-font-size-caption`（12）或 `--cf-font-size-body-sm`（13），**不再出现小于 12 的字号**。`clip-path` 锯齿整块删除。

挂件 `static/widget.css`（公网 `?v=20261029c` 版）的映射：

| 现值 | 换成 |
|---|---|
| `#356aea`、`#2f6fed`（×6） | `--cf-color-brand` / `--cf-color-text-link` |
| `#1f8a4c`、`#2f9e44` | `--cf-color-success-fg` |
| `#c47a1a`、`#8a5408` | `--cf-color-warning-fg` |
| `#c45c5c`、`#c23b2e`、`#9a2a20`、`#780000` | `--cf-color-danger-fg` |
| `#fff`（×14） | `--cf-color-bg-surface`；放在品牌底上时用 `--cf-color-text-on-brand` |
| `--mc-ink` / `--mc-muted` / `--mc-faint` / `--mc-line` / `--mc-paper` / `--mc-tile` / `--mc-hover` / `--mc-focus` 及其暗色值 | `text-primary` / `text-secondary` / `text-tertiary`（原 `faint #b0aaa3` 在白底上对比度不足，作废）/ `border-default` / `bg-surface` / `bg-subtle` / `bg-hover` / `border-focus` |

圆角也要收：现有 0.75–1.05rem 和 13 处 999px，改为 ≤ `--cf-radius-lg`；`999px` 只保留给圆点和头像。

## 自检

`sh selfcheck.sh`（2026-10-30）：**自检通过**。
- CSS（base / direction-A / preview）：硬编码颜色 0、px 字面量 0、非 token 字号 0、nth-child / 子代组合符 0、渐变 / 毛玻璃 / translateY 0；阴影只有 focus 环。
- HTML：无内联样式；旧 `data-cf-` 前缀 0 处；27 个输入控件全部有 label；5 处 honeypot 全部 `aria-hidden="true"`；无重复 id；16 个截图屏每屏都有 h1（sr-only）；21 个 nav / aside 全部有 aria-label，同屏没有重名；`data-mc-thread` / `data-mc-topic` / `data-mc-event` 取值都在约定范围内。
- 对比度（44 对文字、9 对非文字，亮暗各一遍）：亮色文字最低 4.88（text-tertiary on bg-muted），非文字最低 3.35（border-input on bg-subtle）；暗色文字最低 4.98（text-tertiary on bg-selected），非文字最低 3.06（border-input on card-bg）；暗色卡面对会话底 1.30，卡边对会话底 1.99（≥1.25）。最小字号 12px。
- 点击区实测（Chrome headless，25 屏，全部通过）：手机屏（vp=mobile）≥44，桌面屏 ≥24，数据见 `selfcheck.sh` 第 11 条输出。
- 帖子正文白名单：cooked 范围内 523 个元素，9 个属性以外的 `data-mc-*` 0 处（第 12 条）。
- 在线状态：HTML 中「在线」「离线」和绿点 0 处（第 13 条）。
- 正文标签：卡片 / 正文范围 1204 个元素，`article` / `header` / `footer` 0 个（第 14 条）。
- 插件 token 副本：`assets/stylesheets/common/cf-tokens.css` 与 `tokens.css` 字节一致（第 16 条）。
- 开发说明：各截图屏（不含 parts 展示页和预览标注）可见文本里的接口名、字段名、缓存说明、数据来源说明 0 处（第 15 条）。

## 截图（screenshots/）

- 挂件 6 页，四套齐：`A-{inquiry, aftersales, presales, my-orders, order-detail, aftersale-page}-{mobile, desktop}-{light, dark}.png`（手机为 520 宽画面套 390 宽手机框；桌面为 1440 宽，挂件是右侧浮层面板）
- 商家三栏：`A-merchant-{inquiry, order, aftersale}-desktop-{light, dark}.png`；窄屏降级：`A-merchant-narrow-{1024, 700}-{light, dark}.png`
- 帖子 3 种，四套齐：`A-post-{qa, product, discussion}-{mobile, desktop}-{light, dark}.png`
- 状态与边缘态：`A-presales-states-desktop-{light, dark}.png`、`A-parts-desktop-{light, dark}.png`、`A-parts2-desktop-{light, dark}.png`、`A-parts3-desktop-{light, dark}.png`（商品卡各状态、cooked 占位、问答未解决）

## 下一批

- 帖子版式已画（本次）：问答帖（采纳块 + 已解决 / 待解答）、商品发布帖（JS 商品卡：有货 / 缺货 / 可预订 / 缺规格 / 加载 / 失败 / 下架降级）、普通讨论帖（Discourse 默认，只套 token）。待负责人选定后再细化。
- 售后细分：以后用可选 `aftersale_reason` 区分，`thread_kind` 不新增取值。
- S4 品牌感（顶栏店铺小头像或字标，不加色块）；方向 B / C 迁到新结构。
