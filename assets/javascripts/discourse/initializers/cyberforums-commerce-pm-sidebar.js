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
  const buyer = ctx.buyer || {};
  if (buyer.display_name) {
    const u = buyer.discourse_username
      ? ` · @${esc(buyer.discourse_username)}`
      : "";
    kids.push(
      `<div class="mc-commerce__buyer">${esc(buyer.display_name)}${u}</div>`
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
    const badgeToken = (status) => {
      const s = String(status || "")
        .trim()
        .toLowerCase()
        .replace(/^wc-/, "");
      const map = {
        pending: "pending",
        processing: "processing",
        "on-hold": "hold",
        completed: "done",
        cancelled: "cancel",
        refunded: "refund",
        failed: "fail",
        "checkout-draft": "draft",
      };
      return map[s] || "muted";
    };
    const rows = orders
      .slice(0, 5)
      .map((o) => {
        const labelText = o.status_label || o.status || "—";
        const badge = `<span class="mc-badge mc-badge--${esc(
          badgeToken(o.status)
        )}">${esc(labelText)}</span>`;
        const bits = [`#${esc(o.number || o.id)}`];
        if (o.total) {
          bits.push(
            (o.currency ? esc(o.currency) + " " : "") + esc(o.total)
          );
        }
        let view = "";
        const url = o.view_url || o.permalink || "";
        if (
          /^https?:\/\//i.test(url) &&
          !/localhost|127\.0\.0\.1|\[::1\]/i.test(url)
        ) {
          view = ` <a class="mc-commerce__link" href="${esc(
            url
          )}" target="_blank" rel="noopener">查看</a>`;
        }
        return `<div class="mc-commerce__order">${badge} ${bits.join(
          " · "
        )}${view}</div>`;
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

function siteSettingsEnabled(api) {
  let siteSettings = null;
  try {
    siteSettings = api.container.lookup("service:site-settings");
  } catch (e) {
    siteSettings = null;
  }
  if (!siteSettings) {
    try {
      siteSettings = api.container.lookup("site-settings:main");
    } catch (e) {
      siteSettings = null;
    }
  }
  return !!(
    siteSettings &&
    siteSettings.cyberforums_marketplace_pm_commerce_sidebar_enabled
  );
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
    } catch (e) {
      // Never surface admin onPageChange banner for commerce sidebar.
      try {
        mountPanel("");
      } catch (e2) {
        /* ignore */
      }
    }
  });
});
