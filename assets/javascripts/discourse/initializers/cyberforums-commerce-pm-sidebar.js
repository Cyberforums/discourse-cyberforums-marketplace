import { apiInitializer } from "discourse/lib/api";

/**
 * PM commerce 侧栏（cf-design round-1 方向 A，README 组件表「commerce 侧栏」+ 预览 side() / merchant_side()）。
 *
 * 数据：/marketplace/topics/:id/commerce-context.json（BFF 代理）。现有字段：
 *   role、buyer{display_name, discourse_username, email_masked(仅商家)}、product、orders[]、links。
 * 结构：
 *   商家（role=merchant）aria-label「客户与订单」：客户 / 当前状态 / 事件 /（有 vendor_orders 时）历史订单
 *   买家 aria-label「订单当前态」：当前订单 / 事件
 * 事件时间线：从本页帖子正文里的系统卡读（data-mc-card=inquiry|order、p[data-mc-event]），
 *   「事件」与「订单状态」分两列；时间取所在帖子的发帖时间。
 * 状态：无订单 data-mc-state="none"，读取失败 data-mc-state="error" + 重试。
 * 只用 class / data-mc-*，颜色字号全在 SCSS 里引用 token。
 */

const PANEL_ID = "cyberforums-mc-commerce-aside";

const STATUS = {
  pending: ["待付款", "warning"],
  processing: ["处理中", "info"],
  "on-hold": ["保留", "warning"],
  completed: ["已完成", "success"],
  cancelled: ["已取消", "neutral"],
  refunded: ["已退款", "neutral"],
  failed: ["付款失败", "danger"],
};

const THREAD_KIND = {
  inquiry: "询商",
  order: "订单",
  aftersale: "售后",
  presales: "售前",
};

const EVENT_LABEL = {
  inquire: "发起咨询",
  product_ctx: "带商品快照",
  order_card: "发订单卡",
  order_paid: "已付款",
};

function esc(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function normStatus(s) {
  return String(s || "")
    .trim()
    .toLowerCase()
    .replace(/^wc-/, "");
}

function publicUrl(url) {
  const u = String(url || "");
  return /^https?:\/\//i.test(u) && !/localhost|127\.0\.0\.1|\[::1\]/i.test(u)
    ? u
    : "";
}

function money(total, currency) {
  const t = String(total || "").trim();
  if (!t) {
    return "";
  }
  const c = String(currency || "").trim().toUpperCase() || "CNY";
  return c === "CNY" ? `¥${t}` : `${t} ${c}`;
}

function statusTag(code, label) {
  const st = normStatus(code);
  const [zh, tone] = STATUS[st] || [label || st || "—", "neutral"];
  return (
    `<span class="cf-status" data-mc-part="status" data-mc-status="${esc(st)}" data-mc-tone="${tone}">` +
    `<span class="cf-status__label">${esc(label || zh)}</span></span>`
  );
}

function kv(k, v, mono = false) {
  return (
    `<div class="cf-side__row"><dt class="cf-side__k">${esc(k)}</dt>` +
    `<dd class="cf-side__v${mono ? " cf-side__mono" : ""}">${v}</dd></div>`
  );
}

function section(part, title, inner) {
  return (
    `<section class="cf-side__section" data-mc-part="${part}">` +
    `<h3 class="cf-side__title">${esc(title)}</h3>${inner}</section>`
  );
}

function pad2(n) {
  return String(n).padStart(2, "0");
}

function fmtTime(ms) {
  const d = new Date(Number(ms));
  if (!ms || Number.isNaN(d.getTime())) {
    return "";
  }
  return `${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

function postTime(node) {
  const post = node.closest("article[data-post-id], .topic-post");
  const rel = post && post.querySelector(".relative-date[data-time]");
  return rel ? fmtTime(rel.getAttribute("data-time")) : "";
}

// 从帖子正文读系统卡，组装时间线行
export function collectTimeline(root = document) {
  const rows = [];
  root
    .querySelectorAll(
      '.cooked [data-mc-card="inquiry"], .cooked [data-mc-card="order"], .cooked p[data-mc-event]'
    )
    .forEach((n) => {
      let kind = n.getAttribute("data-mc-event");
      if (!kind) {
        kind = n.getAttribute("data-mc-card") === "inquiry" ? "inquire" : "order_card";
      }
      const st = normStatus(n.getAttribute("data-mc-status"));
      let label = EVENT_LABEL[kind];
      if (kind === "status_changed") {
        label = `状态更新为「${(STATUS[st] || [st || "—"])[0]}」`;
      }
      if (!label) {
        return;
      }
      rows.push({ time: postTime(n), kind, label, status: st });
    });
  return rows;
}

function timelineHtml(rows) {
  const trs = rows
    .map((r) => {
      const st = r.status && STATUS[r.status] ? statusTag(r.status) : '<span class="cf-side__na">—</span>';
      const t = r.time ? esc(r.time) : '<span class="cf-side__na">—</span>';
      return `<tr data-mc-event="${esc(r.kind)}"><td class="cf-side__time">${t}</td><td>${esc(r.label)}</td><td>${st}</td></tr>`;
    })
    .join("");
  return (
    '<table class="cf-side__timeline"><thead><tr><th scope="col">时间</th><th scope="col">事件</th>' +
    `<th scope="col">订单状态</th></tr></thead><tbody>${trs}</tbody></table>`
  );
}

function orderRow(o) {
  const st = normStatus(o.status);
  const no = esc(o.number || o.id);
  const admin = publicUrl(o.admin_url);
  const noHtml = admin
    ? `<a class="cf-link cf-order-row__no" data-mc-part="order-no" data-mc-action="view" href="${esc(admin)}" target="_blank" rel="noopener">#${no}</a>`
    : `<span class="cf-order-row__no" data-mc-part="order-no">#${no}</span>`;
  const date = o.date_created
    ? `<time class="cf-order-row__date" data-mc-part="created">${esc(String(o.date_created).slice(5, 10))}</time>`
    : "";
  const first = o.first_item || (Array.isArray(o.items) && o.items[0]) || "";
  const title = first
    ? `<p class="cf-order-row__title" data-mc-part="first-item">${esc(first)}</p>`
    : '<p class="cf-order-row__title cf-order-row__title--fallback" data-mc-part="first-item" data-mc-state="missing">商品明细见订单页</p>';
  const count = o.item_count ? `<p class="cf-order-row__count" data-mc-part="item-count">共 ${esc(o.item_count)} 件</p>` : "";
  const amount = money(o.total, o.currency);
  return (
    `<li class="cf-order-row cf-order-row--compact" data-mc-card="order-row" data-mc-order="${no}" data-mc-status="${esc(st)}">` +
    `<div class="cf-order-row__head" data-mc-part="head">${noHtml}${date}<span class="cf-order-row__status">${statusTag(st, o.status_label)}</span></div>` +
    `<div class="cf-order-row__body" data-mc-part="body"><div class="cf-order-row__info">${title}${count}</div>` +
    (amount ? `<span class="cf-order-row__amount" data-mc-part="amount">${esc(amount)}</span>` : "") +
    "</div></li>"
  );
}

export function renderAside(ctx, timeline) {
  const merchant = ctx.role === "merchant";
  const orders = Array.isArray(ctx.orders) ? ctx.orders : [];
  // 当前订单：本会话关联订单里最后一单（orders[] 按关联先后排列）
  const cur = orders.length ? orders[orders.length - 1] : null;
  const links = ctx.links || {};
  const sections = [];

  if (merchant) {
    const b = ctx.buyer || {};
    const who = b.discourse_username
      ? `<span data-mc-part="buyer-user">@${esc(b.discourse_username)}</span>`
      : `<span data-mc-part="buyer-guest">${esc(b.display_name || "访客")}</span>`;
    let facts = kv("买家", who) + kv("标识", b.discourse_username ? "论坛用户" : "访客");
    if (b.email_masked) {
      facts += kv("邮箱", `<span data-mc-part="email-masked">${esc(b.email_masked)}</span>`, true);
    }
    sections.push(section("side-buyer", "客户", `<dl class="cf-side__facts">${facts}</dl>`));
  }

  let curFacts = "";
  if (merchant && THREAD_KIND[ctx.thread_kind]) {
    curFacts += kv("会话类型", esc(THREAD_KIND[ctx.thread_kind]));
  }
  let curExtra = "";
  if (cur) {
    curFacts +=
      kv("订单号", `#${esc(cur.number || cur.id)}`, true) +
      kv("订单状态", statusTag(cur.status, cur.status_label));
    const amt = money(cur.total, cur.currency);
    if (amt) {
      curFacts += kv("实付", esc(amt), true);
    }
    if (merchant) {
      const admin = publicUrl(cur.admin_url || links.woo_order_admin);
      if (admin) {
        curExtra = `<a class="cf-link" data-mc-action="view" href="${esc(admin)}" target="_blank" rel="noopener">在 Woo 后台查看</a>`;
      }
    } else {
      const view = publicUrl(cur.view_url);
      if (view) {
        curExtra = `<a class="cf-link" data-mc-action="view" href="${esc(view)}" target="_blank" rel="noopener">在 Woo 查看</a>`;
      }
    }
  } else {
    curExtra = merchant
      ? '<p class="cf-side__empty">这次咨询还没有关联订单。</p>'
      : '<p class="cf-side__empty">这次咨询还没有关联订单。买家下单或发订单卡后会出现在这里。</p>';
  }
  sections.push(
    section(
      "side-current",
      merchant ? "当前状态" : "当前订单",
      (curFacts ? `<dl class="cf-side__facts">${curFacts}</dl>` : "") + curExtra
    )
  );

  // 预览没有「无事件」态：正文里一张系统卡都没有时整段不画
  if (timeline && timeline.length) {
    sections.push(section("side-timeline", "事件", timelineHtml(timeline)));
  }

  // 历史订单：契约 vendor-orders（商家专用、最多 5 单、不含当前订单）。BFF 还没给这个字段时不画。
  if (merchant && Array.isArray(ctx.vendor_orders)) {
    const hist = ctx.vendor_orders
      .filter((o) => !cur || String(o.id) !== String(cur.id))
      .slice(0, 5);
    const inner = hist.length
      ? `<ul class="cf-order-list" data-mc-part="order-list" aria-label="历史订单">${hist.map(orderRow).join("")}</ul>`
      : '<div class="cf-order-list__msg" data-mc-part="list-empty" data-mc-state="empty"><p>该客户在本店还没有订单。</p></div>';
    sections.push(section("side-orders", "该客户在本店的历史订单", inner));
  }

  const state = cur ? "" : ' data-mc-state="none"';
  const label = merchant ? "客户与订单" : "订单当前态";
  return `<aside class="cf-side" id="${PANEL_ID}" data-mc-part="side"${state} aria-label="${label}">${sections.join("")}</aside>`;
}

function renderError() {
  return (
    `<aside class="cf-side" id="${PANEL_ID}" data-mc-part="side" data-mc-state="error" aria-label="订单当前态">` +
    '<section class="cf-side__section"><h3 class="cf-side__title">当前订单</h3>' +
    '<p class="cf-side__empty cf-side__empty--error">读取 Woo 订单失败。</p>' +
    '<button class="cf-textbtn cf-textbtn--link" type="button">重试</button></section></aside>'
  );
}

function mountPanel(html) {
  const old = document.getElementById(PANEL_ID);
  if (old) {
    old.remove();
  }
  if (!html) {
    return null;
  }
  const title = document.querySelector("#topic-title, .title-wrapper");
  const above = document.querySelector(".topic-above-posts");
  const posts = document.querySelector(".container.posts, .post-stream");
  const wrap = document.createElement("div");
  wrap.innerHTML = html;
  const node = wrap.firstElementChild;
  if (!node) {
    return null;
  }
  if (above) {
    above.insertBefore(node, above.firstChild);
  } else if (title && title.parentNode) {
    title.parentNode.insertBefore(node, title.nextSibling);
  } else if (posts) {
    posts.insertBefore(node, posts.firstChild);
  }
  return node;
}

function siteSettingsEnabled(api) {
  let siteSettings = null;
  try {
    siteSettings = api.container.lookup("service:site-settings");
  } catch {
    siteSettings = null;
  }
  if (!siteSettings) {
    try {
      siteSettings = api.container.lookup("site-settings:main");
    } catch {
      siteSettings = null;
    }
  }
  return !!(
    siteSettings &&
    siteSettings.cyberforums_marketplace_pm_commerce_sidebar_enabled
  );
}

function load(topicId) {
  fetch(`/marketplace/topics/${topicId}/commerce-context.json`, {
    credentials: "same-origin",
    headers: { Accept: "application/json" },
  })
    .then((r) => {
      if (r.status === 404) {
        return { notCommerce: true };
      }
      return r.ok ? r.json() : null;
    })
    .then((ctx) => {
      if (ctx && ctx.notCommerce) {
        mountPanel("");
        return;
      }
      if (!ctx || !ctx.ok) {
        const node = mountPanel(renderError());
        const btn = node && node.querySelector(".cf-textbtn");
        if (btn) {
          btn.addEventListener("click", () => load(topicId));
        }
        return;
      }
      mountPanel(renderAside(ctx, collectTimeline()));
      // 帖子流可能晚于接口返回，下一帧再按正文刷新一次时间线
      window.requestAnimationFrame(() => {
        if (document.getElementById(PANEL_ID)) {
          mountPanel(renderAside(ctx, collectTimeline()));
        }
      });
    })
    .catch(() => {
      const node = mountPanel(renderError());
      const btn = node && node.querySelector(".cf-textbtn");
      if (btn) {
        btn.addEventListener("click", () => load(topicId));
      }
    });
}

export default apiInitializer("1.8.0", (api) => {
  api.onPageChange(() => {
    try {
      if (!siteSettingsEnabled(api)) {
        mountPanel("");
        return;
      }
      const topicCtrl = api.container.lookup("controller:topic");
      const topic = topicCtrl && topicCtrl.model;
      if (!topic || !topic.get("isPrivateMessage")) {
        mountPanel("");
        return;
      }
      const topicId = topic.get("id");
      if (!topicId) {
        return;
      }
      load(topicId);
    } catch {
      // 侧栏出错不弹 admin 横幅
      try {
        mountPanel("");
      } catch {
        /* ignore */
      }
    }
  });
});
