import { apiInitializer } from "discourse/lib/api";

const PANEL_ID = "cyberforums-mc-commerce-aside";

function esc(s) {
  return String(s || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function renderAside(ctx) {
  const kids = [];
  if (ctx.buyer?.display_name) {
    const u = ctx.buyer.discourse_username
      ? ` · @${esc(ctx.buyer.discourse_username)}`
      : "";
    kids.push(
      `<div class="mc-commerce__buyer">${esc(ctx.buyer.display_name)}${u}</div>`
    );
  }
  const p = ctx.product;
  if (p && (p.title || p.image)) {
    const thumb = p.image
      ? `<img class="mc-commerce__thumb" src="${esc(p.image)}" alt="" loading="lazy" />`
      : "";
    let sub = "";
    if (p.price) {
      sub = `${p.currency ? esc(p.currency) + " " : ""}${esc(p.price)}`;
    }
    if (p.sku) {
      sub = `${sub ? sub + " · " : ""}SKU ${esc(p.sku)}`;
    }
    kids.push(
      `<div class="mc-commerce__product">${thumb}<div class="mc-commerce__meta"><div class="mc-commerce__title">${esc(
        p.title || "商品"
      )}</div>${sub ? `<div class="mc-commerce__sub">${sub}</div>` : ""}</div></div>`
    );
  }
  const orders = Array.isArray(ctx.orders) ? ctx.orders : [];
  if (orders.length) {
    const rows = orders
      .slice(0, 5)
      .map((o) => {
        const label = `#${esc(o.number || o.id)}${
          o.status ? " · " + esc(o.status) : ""
        }${
          o.total
            ? " · " +
              (o.currency ? esc(o.currency) + " " : "") +
              esc(o.total)
            : ""
        }`;
        return `<div class="mc-commerce__order">${label}</div>`;
      })
      .join("");
    kids.push(
      `<div class="mc-commerce__orders"><div class="mc-commerce__orders-head">关联订单</div>${rows}</div>`
    );
  }
  const links = ctx.links || {};
  const linkBits = [];
  if (links.merchant_inbox_url && ctx.role === "merchant") {
    linkBits.push(
      `<a class="mc-commerce__link" href="${esc(
        links.merchant_inbox_url
      )}" target="_blank" rel="noopener">商家收件箱</a>`
    );
  }
  if (links.product_url) {
    linkBits.push(
      `<a class="mc-commerce__link" href="${esc(
        links.product_url
      )}" target="_blank" rel="noopener">商品页</a>`
    );
  }
  if (linkBits.length) {
    kids.push(`<div class="mc-commerce__links">${linkBits.join(" · ")}</div>`);
  }
  if (!kids.length) {
    return "";
  }
  return `<aside class="mc-commerce" id="${PANEL_ID}" aria-label="会话上下文">${kids.join(
    ""
  )}</aside>`;
}

function mountPanel(html) {
  const old = document.getElementById(PANEL_ID);
  if (old) {
    old.remove();
  }
  if (!html) {
    return;
  }
  // Discourse PM layouts vary; prefer title area then posts container.
  const title = document.querySelector("#topic-title, .title-wrapper");
  const above = document.querySelector(".topic-above-posts");
  const posts = document.querySelector(".container.posts, .post-stream");
  const wrap = document.createElement("div");
  wrap.innerHTML = html;
  const node = wrap.firstElementChild;
  if (!node) {
    return;
  }
  if (above) {
    above.insertBefore(node, above.firstChild);
  } else if (title && title.parentNode) {
    title.parentNode.insertBefore(node, title.nextSibling);
  } else if (posts) {
    posts.insertBefore(node, posts.firstChild);
  }
}

export default apiInitializer("1.8.0", (api) => {
  api.onPageChange(() => {
    // Plugin JS has no theme `settings` global — read SiteSetting via container.
    const siteSettings =
      api.container.lookup("service:site-settings") ||
      api.container.lookup("site-settings:main");
    if (!siteSettings?.cyberforums_marketplace_pm_commerce_sidebar_enabled) {
      mountPanel("");
      return;
    }
    const topic = api.container.lookup("controller:topic")?.model;
    if (!topic || !topic.get("isPrivateMessage")) {
      mountPanel("");
      return;
    }
    const topicId = topic.get("id");
    if (!topicId) {
      return;
    }

    fetch(`/marketplace/topics/${topicId}/commerce-context.json`, {
      credentials: "same-origin",
      headers: { Accept: "application/json" },
    })
      .then((r) => (r.ok ? r.json() : null))
      .then((ctx) => {
        if (!ctx || !ctx.ok) {
          mountPanel("");
          return;
        }
        mountPanel(renderAside(ctx));
      })
      .catch(() => mountPanel(""));
  });
});
