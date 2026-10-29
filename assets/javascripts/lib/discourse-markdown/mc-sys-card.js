/**
 * 帖子正文（cooked）白名单 —— 按 cf-design round-1 README「渲染位置」一节（a2592d5）。
 *
 * - 只放行 9 个 data-mc-* 属性，取值与可挂的标签照 README 表格逐条列出；
 *   Discourse allowList 的条目是「标签[属性=值]」成对写的，不支持通配，所以这里展开成组合。
 * - 标签只用 div / span / a / img / p / time（img 由 Discourse 默认规则放行，不挂 data-mc-*）。
 * - class、role、aria-*、svg 都不进 cooked：class 和 aria/role 由 decorate JS 按 data-mc-* 补回。
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

export function setup(helper) {
  helper.allowList(buildMcAllowList());
}
