import { apiInitializer } from "discourse/lib/api";

/**
 * Restore card chrome when sanitizer stripped classes but kept data-mc-event.
 * Structural walk matches BFF render_sys_card_html / format_product_context_card.
 */
function decorateMcSysCards(element) {
  element.querySelectorAll("[data-mc-event]").forEach((card) => {
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
    // head is first element child that is a DIV without nested row DIVs of 2 spans? —
    // BFF: head, optional media, body, optional actions, foot(p)
    let i = 0;
    const head = kids[i];
    if (head && head.tagName === "DIV" && !head.querySelector("div > span")) {
      head.classList.add("mc-sys-card__head");
      i += 1;
    }
    const maybeMedia = kids[i];
    if (maybeMedia && maybeMedia.tagName === "DIV" && maybeMedia.querySelector("img")) {
      maybeMedia.classList.add("mc-sys-card__media");
      const img = maybeMedia.querySelector("img");
      if (img) {
        img.classList.add("mc-sys-card__img");
      }
      i += 1;
    }
    const body = kids[i];
    if (body && body.tagName === "DIV") {
      body.classList.add("mc-sys-card__body");
      if (ev === "inquire") {
        const parts = body.querySelectorAll(":scope > div");
        if (parts[0]) {
          parts[0].classList.add("mc-sys-card__sub");
        }
        if (parts[1]) {
          parts[1].classList.add("mc-sys-card__salute");
        }
        if (parts[2]) {
          parts[2].classList.add("mc-sys-card__prose");
        }
        if (parts[3]) {
          parts[3].classList.add("mc-sys-card__facts");
        }
      } else {
        body.querySelectorAll(":scope > div").forEach((row) => {
          row.classList.add("mc-sys-card__row");
          const spans = row.querySelectorAll(":scope > span");
          if (spans[0]) {
            spans[0].classList.add("mc-sys-card__k");
          }
          if (spans[1]) {
            spans[1].classList.add("mc-sys-card__v");
          }
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

function syncCommercePmFlag() {
  const has = !!document.querySelector(
    ".cooked [data-mc-event], .d-editor-preview [data-mc-event]"
  );
  document.documentElement.classList.toggle("mc-commerce-pm", has);
}

export default apiInitializer("1.8.0", (api) => {
  api.decorateCookedElement(
    (element) => {
      decorateMcSysCards(element);
      syncCommercePmFlag();
    },
    {
      id: "cyberforums-mc-sys-card",
      onlyStream: false,
    }
  );

  api.onPageChange(() => {
    // Clear first; decorateCookedElement re-sets when stream paints.
    document.documentElement.classList.remove("mc-commerce-pm");
    window.requestAnimationFrame(syncCommercePmFlag);
  });
});
