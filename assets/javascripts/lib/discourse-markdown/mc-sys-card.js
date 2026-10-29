/**
 * 帖子正文（cooked）白名单 —— 按 cf-design round-1 README「渲染位置」一节（a2592d5）。
 *
 * - 只放行 9 个 data-mc-* 属性，取值与可挂的标签照 README 表格逐条列出；
 *   Discourse allowList 的条目是「标签[属性=值]」成对写的，不支持通配，所以这里展开成组合。
 * - 标签只用 div / span / a / img / p / time（img 由 Discourse 默认规则放行，不挂 data-mc-*）。
 * - class、role、aria-*、svg 都不进 cooked：class 和 aria/role 由 decorate JS 按 data-mc-* 补回。
 * - 例外：文件末尾 LEGACY_ALLOW_0_3 是 0.4.x 过渡期保留的旧 class 条目，下一版删除。
 * - JS 外壳才用的 data-mc-page / quick / side / stock / surface / thread / topic 不在这里。
 */

const ANY = null; // 纯数字 ID：允许任意值（sanitizer 仍会转义）

// 属性 → { 取值, 标签 }，与 README「帖子正文（cooked，走白名单）」表一一对应
export const MC_COOKED_ATTRS = {
  "data-mc-card": {
    values: ["inquiry", "order", "product"],
    tags: ["a", "div"],
  },
  "data-mc-part": {
    values: [
      "action",
      "actions",
      "amount",
      "body",
      "created",
      "error",
      "facts",
      "first-item",
      "head",
      "info",
      "item-count",
      "label",
      "note",
      "order-no",
      "price",
      "product",
      "shop",
      "sku",
      "spec",
      "status",
      "thumb",
      "title",
    ],
    tags: ["a", "div", "p", "span", "time"],
  },
  "data-mc-state": {
    values: ["actions-fallback", "error", "gone", "loading", "missing"],
    tags: ["a", "div", "p", "span"],
  },
  "data-mc-status": {
    values: [
      "cancelled",
      "completed",
      "failed",
      "on-hold",
      "pending",
      "processing",
      "refunded",
    ],
    tags: ["div", "p", "span"],
  },
  "data-mc-tone": {
    values: ["danger", "info", "neutral", "success", "warning"],
    tags: ["span"],
  },
  // README 写的是 p / tr；tr 只出现在侧栏时间线（JS 渲染），不进 cooked，这里只放 p
  "data-mc-event": {
    values: [
      "inquire",
      "order_card",
      "order_paid",
      "product_ctx",
      "status_changed",
    ],
    tags: ["p"],
  },
  "data-mc-order": { values: ANY, tags: ["div", "p"] },
  "data-mc-product": { values: ANY, tags: ["a", "div"] },
  "data-mc-action": { values: ["pay", "refund", "view"], tags: ["a"] },
};

export function buildMcAllowList() {
  // time 不在 Discourse 默认标签里，需要单独放行（BFF 的事件行时间是裸 <time>）
  const list = ["time"];
  Object.entries(MC_COOKED_ATTRS).forEach(([attr, spec]) => {
    spec.tags.forEach((tag) => {
      if (spec.values === ANY) {
        list.push(`${tag}[${attr}]`);
      } else {
        spec.values.forEach((v) => list.push(`${tag}[${attr}=${v}]`));
      }
    });
  });
  return list;
}

// ---------------------------------------------------------------------------
// 0.4.x 过渡兼容：origin/main 0acc955 白名单的旧条目原样保留，
// 让旧 BFF 输出的 div[data-mc-event] 系统卡在过渡期内 cook 后仍带 class / data-mc-*。
// 旧帖不 rebake。下一个版本（0.5.0）删掉 LEGACY_ALLOW_0_3 整段。
// ---------------------------------------------------------------------------
export const LEGACY_ALLOW_0_3 = [
  "div.mc-sys-card",
  "div.mc-sys-card--card",
  "div.mc-sys-card--paid",
  "div.mc-sys-card--status",
  "div.mc-sys-card--inquire",
  "div.mc-sys-card--product",
  "div.mc-sys-card__head",
  "div.mc-sys-card__body",
  "div.mc-sys-card__row",
  "div.mc-sys-card__media",
  "div.mc-sys-card__actions",
  "span.mc-sys-card__k",
  "span.mc-sys-card__v",
  "code.mc-sys-card__code",
  "a.mc-sys-card__btn",
  "p.mc-sys-card__foot",
  "p.mc-inquire-body",
  "img.mc-sys-card__img",
  "img[loading=lazy]",
  "span.mc-badge",
  "span.mc-badge--pending",
  "span.mc-badge--processing",
  "span.mc-badge--hold",
  "span.mc-badge--done",
  "span.mc-badge--cancel",
  "span.mc-badge--fail",
  "span.mc-badge--refund",
  "span.mc-badge--draft",
  "span.mc-badge--muted",
  "div[data-mc-event]",
  "div[data-mc-order]",
  "div[data-mc-status]",
];

export function setup(helper) {
  helper.allowList(buildMcAllowList().concat(LEGACY_ALLOW_0_3));
}
