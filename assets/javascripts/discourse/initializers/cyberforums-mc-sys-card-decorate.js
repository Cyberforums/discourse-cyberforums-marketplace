import { apiInitializer } from "discourse/lib/api";

/**
 * 帖子正文卡片 decorate（cf-design round-1 方向 A，README「渲染位置」一节，a2592d5）。
 *
 * Discourse cooked 会剥掉 class / role / aria-*，只保留白名单里的 9 个 data-mc-* 属性。
 * 这里按 data-mc-* 把 class 补回来，再补 role / aria：
 *   - 卡片根 [data-mc-card] → role="article"；头段、操作段不补 role
 *   - 加载态 → aria-busy；缺图占位 / 分隔符 → aria-hidden；缩略图 → role="img" + aria-label
 *   - 系统事件行 p[data-mc-event] → role="status"
 * 订单卡状态标签前补发卡时间：「10/28 发卡时 · 待付款」，时间取卡内 time[data-mc-part=created]。
 *
 * 旧版（0.3.x）系统卡 div[data-mc-event] 已经 cook 进库的帖子仍带 mc-sys-card 类，
 * 下面的 decorateLegacySysCards 保留兜底，不再新增样式。
 */

const STATUS = {
  pending: ["待付款", "warning"],
  processing: ["处理中", "info"],
  "on-hold": ["保留", "warning"],
  completed: ["已完成", "success"],
  cancelled: ["已取消", "neutral"],
  refunded: ["已退款", "neutral"],
  failed: ["付款失败", "danger"],
};

const CARD_ROOT_CLASS = {
  inquiry: ["cf-card", "cf-inquiry-card"],
  order: ["cf-card", "cf-order-card"],
};

// 卡片通用三段 + 各卡片自己的段落；key = data-mc-part
const PART_CLASS_COMMON = {
  head: ["cf-card__head"],
  body: ["cf-card__body"],
  actions: ["cf-card__actions"],
  error: ["cf-card__error"],
  label: ["cf-card__label"],
  status: ["cf-status"],
};

const PART_CLASS_BY_CARD = {
  inquiry: {
    shop: ["cf-card__meta", "cf-inquiry-card__shop"],
    product: ["cf-inquiry-card__product"],
    info: ["cf-inquiry-card__info"],
    title: ["cf-inquiry-card__title"],
    spec: ["cf-inquiry-card__spec"],
    facts: ["cf-inquiry-card__facts"],
    price: ["cf-inquiry-card__price"],
    sku: ["cf-inquiry-card__sku"],
    note: ["cf-inquiry-card__note"],
    thumb: ["cf-thumb", "cf-thumb--md"],
  },
  order: {
    "order-no": ["cf-order-card__no"],
    created: ["cf-card__meta"],
    info: ["cf-order-card__info"],
    "first-item": ["cf-order-card__title"],
    "item-count": ["cf-order-card__more"],
    amount: ["cf-order-card__amount"],
    thumb: ["cf-thumb", "cf-thumb--sm"],
  },
};

// 已处理过的节点；不往 DOM 写额外的 data-mc-* 标记
const DONE = new WeakSet();

function add(el, classes) {
  if (el && classes) {
    el.classList.add(...classes);
  }
}

function text(el) {
  return el ? (el.textContent || "").trim() : "";
}

// 「10-28 09:58 下单」/「2026-10-28T09:58」→「10/28」；取不到返回空串
export function monthDay(raw) {
  const s = String(raw || "");
  const m = s.match(/(?:\d{4}-)?(\d{1,2})[-/](\d{1,2})/);
  if (!m) {
    return "";
  }
  return `${Number(m[1])}/${Number(m[2])}`;
}

function decorateStatus(statusEl) {
  add(statusEl, ["cf-status"]);
  const code = statusEl.getAttribute("data-mc-status") || "";
  let labelEl = statusEl.querySelector(":scope > span");
  if (!labelEl) {
    // cooked 里只剩文字时，包一层 label，保持与预览结构一致
    labelEl = document.createElement("span");
    labelEl.textContent = text(statusEl) || (STATUS[code] || [])[0] || "";
    statusEl.textContent = "";
    statusEl.appendChild(labelEl);
  }
  add(labelEl, ["cf-status__label"]);
  if (!statusEl.hasAttribute("data-mc-tone") && STATUS[code]) {
    // 只在 cooked 缺 tone 时按 README 五档补，不覆盖后端给的值
    statusEl.setAttribute("data-mc-tone", STATUS[code][1]);
  }
  return labelEl;
}

function decorateThumb(thumb, cardKind, card) {
  if (thumb.getAttribute("data-mc-state") === "missing") {
    thumb.classList.add("cf-thumb--missing");
    thumb.setAttribute("aria-hidden", "true");
    if (!text(thumb)) {
      // README：缺 thumb → 灰底首字
      const name = text(
        card.querySelector(
          cardKind === "order"
            ? '[data-mc-part="first-item"]'
            : '[data-mc-part="title"]'
        )
      );
      thumb.textContent = name ? Array.from(name)[0] : "";
    }
    return;
  }
  const name = text(
    card.querySelector('[data-mc-part="title"], [data-mc-part="first-item"]')
  );
  thumb.setAttribute("role", "img");
  thumb.setAttribute("aria-label", name || "商品图");
}

function decorateActions(card, cardKind) {
  card.querySelectorAll('[data-mc-part="action"]').forEach((a) => {
    const action = a.getAttribute("data-mc-action");
    if (action === "pay") {
      // README：「去支付」是唯一的描边按钮，其余操作都是文字链
      add(a, ["cf-btn", "cf-btn--outline"]);
    } else {
      add(a, ["cf-link"]);
    }
  });
  if (cardKind === "order") {
    // 正文订单卡：默认只有「查看订单」；去支付 / 申请退款只在 BFF 按契约 actions[] 输出时出现。
    // 这里不按状态自行补或删操作，只保证「查看订单」排在第一位。
    const actions = card.querySelector('[data-mc-part="actions"]');
    const view = actions && actions.querySelector('[data-mc-action="view"]');
    if (view && actions.firstElementChild !== view) {
      actions.insertBefore(view, actions.firstElementChild);
    }
  }
  // 商家视角：订单号本身是链接（S5）
  card
    .querySelectorAll('a[data-mc-part="order-no"]')
    .forEach((a) => add(a, ["cf-link"]));
}

function decorateCard(card) {
  if (DONE.has(card)) {
    return;
  }
  const kind = card.getAttribute("data-mc-card") || "";
  const rootClass = CARD_ROOT_CLASS[kind];
  if (!rootClass) {
    // product 占位链接由商品卡 JS 负责（不在本批）
    return;
  }
  DONE.add(card);
  add(card, rootClass);
  card.setAttribute("role", "article");
  if (card.getAttribute("data-mc-state") === "loading") {
    card.setAttribute("aria-busy", "true");
  }

  const byCard = PART_CLASS_BY_CARD[kind] || {};
  card.querySelectorAll("[data-mc-part]").forEach((el) => {
    const part = el.getAttribute("data-mc-part");
    add(el, byCard[part] || PART_CLASS_COMMON[part]);
  });

  card
    .querySelectorAll('[data-mc-part="thumb"]')
    .forEach((t) => decorateThumb(t, kind, card));

  if (kind === "order") {
    const body = card.querySelector('[data-mc-part="body"]');
    const main = body && body.querySelector(":scope > div");
    add(main, ["cf-order-card__main"]);
    const amount = card.querySelector('[data-mc-part="amount"]');
    add(amount && amount.querySelector(":scope > span"), [
      "cf-order-card__amount-k",
    ]);
    const statusEl = card.querySelector('[data-mc-part="status"]');
    if (statusEl) {
      const stateBox = statusEl.parentElement;
      if (stateBox && stateBox !== main && !stateBox.hasAttribute("data-mc-part")) {
        add(stateBox, ["cf-order-card__state"]);
      }
      const labelEl = decorateStatus(statusEl);
      const md = monthDay(text(card.querySelector('time[data-mc-part="created"]')));
      if (md && !DONE.has(labelEl)) {
        DONE.add(labelEl);
        labelEl.textContent = `${md} 发卡时 · ${text(labelEl)}`;
      }
    }
    const first = card.querySelector('[data-mc-part="first-item"]');
    if (first && first.getAttribute("data-mc-state") === "missing") {
      first.classList.add("cf-order-card__title--fallback");
    }
  } else {
    card
      .querySelectorAll('[data-mc-part="status"]')
      .forEach((s) => decorateStatus(s));
  }

  decorateActions(card, kind);
}

function decorateEventLine(line) {
  if (line.tagName !== "P" || DONE.has(line)) {
    return;
  }
  DONE.add(line);
  add(line, ["cf-event"]);
  line.setAttribute("role", "status");
  line.querySelectorAll(":scope > span").forEach((span) => {
    const t = text(span);
    if (t === "·") {
      add(span, ["cf-event__sep"]);
      span.setAttribute("aria-hidden", "true");
    } else {
      add(span, ["cf-event__text"]);
    }
  });
  line
    .querySelectorAll(":scope > time")
    .forEach((t) => add(t, ["cf-event__time"]));
}

/* ---- 旧版 0.3.x 系统卡（div[data-mc-event]，已 cook 进库的帖子）---- */
function decorateLegacySysCards(element) {
  element.querySelectorAll("div[data-mc-event]").forEach((card) => {
    const ev = card.getAttribute("data-mc-event") || "";
    card.classList.add("mc-sys-card");
    const mod =
      {
        order_card: "card",
        order_paid: "paid",
        status_changed: "status",
        inquire: "inquire",
        product_ctx: "product",
      }[ev] || "";
    if (mod) {
      card.classList.add("mc-sys-card--" + mod);
    }
    const kids = Array.from(card.children);
    if (!kids.length) {
      return;
    }
    let i = 0;
    const head = kids[i];
    if (head && head.tagName === "DIV" && !head.querySelector("div > span")) {
      head.classList.add("mc-sys-card__head");
      i += 1;
    }
    const maybeMedia = kids[i];
    if (maybeMedia && maybeMedia.tagName === "DIV" && maybeMedia.querySelector("img")) {
      maybeMedia.classList.add("mc-sys-card__media");
      add(maybeMedia.querySelector("img"), ["mc-sys-card__img"]);
      i += 1;
    }
    const body = kids[i];
    if (body && body.tagName === "DIV") {
      body.classList.add("mc-sys-card__body");
      if (ev === "inquire") {
        const parts = Array.from(body.querySelectorAll(":scope > div"));
        ["mc-sys-card__sub", "mc-sys-card__salute", "mc-sys-card__prose", "mc-sys-card__facts"].forEach(
          (cls, idx) => add(parts[idx], [cls])
        );
      } else {
        body.querySelectorAll(":scope > div").forEach((row) => {
          row.classList.add("mc-sys-card__row");
          const spans = Array.from(row.querySelectorAll(":scope > span"));
          add(spans[0], ["mc-sys-card__k"]);
          add(spans[1], ["mc-sys-card__v"]);
          row.querySelectorAll("code").forEach((c) => c.classList.add("mc-sys-card__code"));
        });
      }
      i += 1;
    }
    const maybeActions = kids[i];
    if (maybeActions && maybeActions.tagName === "DIV" && maybeActions.querySelector("a")) {
      maybeActions.classList.add("mc-sys-card__actions");
      maybeActions.querySelectorAll("a").forEach((a) => a.classList.add("mc-sys-card__btn"));
      i += 1;
    }
    kids.slice(i).forEach((n) => {
      if (n.tagName === "P") {
        n.classList.add("mc-sys-card__foot");
      }
    });
  });
}

export function decorateMcCooked(element) {
  element.querySelectorAll("[data-mc-card]").forEach(decorateCard);
  element.querySelectorAll("p[data-mc-event]").forEach(decorateEventLine);
  decorateLegacySysCards(element);
}

const COMMERCE_SELECTOR =
  ".cooked [data-mc-event], .cooked [data-mc-card], .d-editor-preview [data-mc-event], .d-editor-preview [data-mc-card]";

function syncCommercePmFlag() {
  const has = !!document.querySelector(COMMERCE_SELECTOR);
  document.documentElement.classList.toggle("mc-commerce-pm", has);
}

export default apiInitializer("1.8.0", (api) => {
  api.decorateCookedElement(
    (element) => {
      decorateMcCooked(element);
      syncCommercePmFlag();
    },
    {
      id: "cyberforums-mc-sys-card",
      onlyStream: false,
    }
  );

  api.onPageChange(() => {
    // 先清掉；帖子流渲染时 decorateCookedElement 会重新设上
    document.documentElement.classList.remove("mc-commerce-pm");
    window.requestAnimationFrame(syncCommercePmFlag);
  });
});
