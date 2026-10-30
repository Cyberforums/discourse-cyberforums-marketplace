#!/usr/bin/env python3
"""生成 direction-A.html（round-1 第二批）。
组件 DOM、class 与 data-mc-* 钩子是给 cf-frontend 的唯一标记契约；B / C 以后只换 direction-*.css。
字段按 ~/grokbot-memory/teams/cyberforums/API-CONTRACT-cf-woo-r1.md（负责人 10-30 00:35 拍板）对齐。
用法：python3 build_previews.py
"""
import itertools
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
_n = itertools.count(1)


def uid(prefix):
    return f"{prefix}-{next(_n)}"


def svg(path, sw="1.4", vb="16"):
    return (f'<svg viewBox="0 0 {vb} {vb}" width="{vb}" height="{vb}" fill="none" stroke="currentColor" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">{path}</svg>')


ICON = {
    "back": svg('<path d="M10 3L5 8l5 5"/>', "1.6"),
    "image": svg('<rect x="1.5" y="2.5" width="13" height="11" rx="1"/><circle cx="5.5" cy="6" r="1.2"/><path d="M2 12l4-4 3 3 2-2 3 3"/>'),
    "order": svg('<rect x="2.5" y="1.5" width="11" height="13" rx="1"/><path d="M5 5h6M5 8h6M5 11h3"/>'),
    "pkg": svg('<path d="M12 2.8l8 4.4v9.6l-8 4.4-8-4.4V7.2z"/><path d="M4 7.2l8 4.4 8-4.4M12 11.6v9.6"/>', "1.2", "24"),
    "chev": svg('<path d="M4 6l4 4 4-4"/>'),
}

STATUS = {  # Woo status 原样 → 中文 + 五档色
    "pending": ("待付款", "warning"), "processing": ("处理中", "info"), "on-hold": ("保留", "warning"),
    "completed": ("已完成", "success"), "cancelled": ("已取消", "neutral"), "refunded": ("已退款", "neutral"),
    "failed": ("付款失败", "danger"),
}
# 契约 2.1：actions[] 由后端按 Woo status 给出，前端只渲染；全部是跳 Woo 的链接，聊天内不改单
ACTIONS = {"pending": ["view", "pay"], "failed": ["view", "pay"], "on-hold": ["view", "refund"],
           "processing": ["view", "refund"], "completed": ["view", "refund"], "cancelled": ["view"], "refunded": ["view"]}
ACTION_LABEL = {"pay": "去支付", "view": "查看订单", "refund": "申请退款"}
LONG = "WP 多站点内容同步插件 Pro（含 WooCommerce 商品 / 订单双向同步扩展、多语言站点映射与 3 年优先技术支持）"


def status(code, raw=False):
    label, tone = STATUS[code]
    r = f'<code class="cf-status__raw" data-mc-part="status-raw">{code}</code>' if raw else ""
    return (f'<span class="cf-status" data-mc-part="status" data-mc-status="{code}" data-mc-tone="{tone}">'
            f'<span class="cf-status__dot" aria-hidden="true"></span><span class="cf-status__label">{label}</span></span>{r}')


def tag(label, tone, part, extra=""):
    return (f'<span class="cf-status" data-mc-part="{part}" data-mc-tone="{tone}"{extra}>'
            f'<span class="cf-status__dot" aria-hidden="true"></span><span class="cf-status__label">{label}</span></span>')


def thumb(size="md"):
    return f'<span class="cf-thumb cf-thumb--{size}" data-mc-part="thumb" role="img" aria-label="商品图（示例占位）">{ICON["pkg"]}</span>'


def thumb_missing(ch="单"):
    """缺 thumb 的降级：灰底占位 + 商品首字，不留破图。"""
    return f'<span class="cf-thumb cf-thumb--sm cf-thumb--missing" data-mc-part="thumb" data-mc-state="missing" aria-hidden="true">{ch}</span>'


def skel(w="m"):
    return f'<span class="cf-skeleton cf-skeleton--{w}" aria-hidden="true"></span>'


def actions_html(code, mode="ok", merchant=False):
    """mode: ok = 按 actions[] 渲染；fallback = 缺 actions，只给 view_url；none = 无公网 url，不渲染操作。"""
    if mode == "none":
        return '<p class="cf-card__hint" data-mc-part="actions-none">订单链接暂不可用，请到店铺「我的账户 › 订单」查看。</p>'
    if merchant:
        return '<a class="cf-link" data-mc-part="action" data-mc-action="view" href="#woo-admin-order">在 Woo 后台查看</a>'
    keys = ["view"] if mode == "fallback" else ACTIONS[code]
    out = []
    for k in keys:
        cls = "cf-btn cf-btn--outline" if k == "pay" else "cf-link"
        out.append(f'<a class="{cls}" data-mc-part="action" data-mc-action="{k}" href="#woo-{k}">{ACTION_LABEL[k]}</a>')
    return "".join(out)


def L(html, label):
    """给根 nav / aside 换一个可区分的 aria-label（同页多个同类 landmark 时用）。"""
    return re.sub(r'aria-label="[^"]*"', f'aria-label="{label}"', html, count=1)


def kv(k, v, mono=False):
    m = " cf-side__mono" if mono else ""
    return f'<div class="cf-side__row"><dt class="cf-side__k">{k}</dt><dd class="cf-side__v{m}">{v}</dd></div>'


# ---------- 询商卡 ----------
def inquiry_card(title="WP 多站点内容同步插件 Pro", state="ok", nospec=False):
    spec = "" if nospec else '<p class="cf-inquiry-card__spec" data-mc-part="spec">单站授权 · 1 年更新</p>'
    head = '''<div class="cf-card__head" data-mc-part="head">
    <span class="cf-card__label" data-mc-part="label">咨询商品</span>
    <span class="cf-card__meta cf-inquiry-card__shop" data-mc-part="shop">文派示例店</span>
  </div>'''
    if state == "loading":
        box = '<span class="cf-thumb cf-thumb--md cf-skeleton-box" aria-hidden="true"></span>'
        return f'''<div class="cf-card cf-inquiry-card" data-mc-card="inquiry" data-mc-state="loading" aria-busy="true">
  {head}
  <div class="cf-card__body" data-mc-part="body"><div class="cf-inquiry-card__product">{box}<div class="cf-inquiry-card__info">{skel("l")}{skel("s")}{skel("m")}</div></div></div>
  <p class="cf-visually-hidden">商品信息加载中</p>
</div>'''
    if state == "error":
        return f'''<div class="cf-card cf-inquiry-card" data-mc-card="inquiry" data-mc-state="error">
  {head}
  <div class="cf-card__body" data-mc-part="body"><p class="cf-card__error" data-mc-part="error">商品信息暂时读不到（可能已下架或接口超时）。</p></div>
  <div class="cf-card__actions" data-mc-part="actions"><a class="cf-link" href="#">打开商品链接</a><button class="cf-textbtn" type="button">重试</button></div>
</div>'''
    return f'''<div class="cf-card cf-inquiry-card" data-mc-card="inquiry" data-mc-product="1201">
  {head}
  <div class="cf-card__body" data-mc-part="body">
    <div class="cf-inquiry-card__product" data-mc-part="product">
      {thumb("md")}
      <div class="cf-inquiry-card__info" data-mc-part="info">
        <p class="cf-inquiry-card__title" data-mc-part="title" title="{title}">{title}</p>
        {spec}
        <p class="cf-inquiry-card__facts" data-mc-part="facts">
          <span class="cf-inquiry-card__price" data-mc-part="price"><span class="cf-inquiry-card__currency">¥</span>199.00</span>
          <span class="cf-inquiry-card__sku" data-mc-part="sku">SKU WPS-PRO-1</span>
        </p>
      </div>
    </div>
    <p class="cf-inquiry-card__note" data-mc-part="note">您好，想确认这款支持 WordPress 6.6 吗？单站授权能换域名吗？</p>
  </div>
  <div class="cf-card__actions" data-mc-part="actions">
    <a class="cf-link" data-mc-part="action" data-mc-action="view" href="#">查看商品</a>
  </div>
</div>'''


# ---------- 订单卡（对话流内） ----------
def order_card(code="processing", no="10077", item="WP 多站点内容同步插件 Pro", count=1, amount="¥199.00",
               time="10-29 21:38", state="ok", nothumb=False, noitem=False, nocount=False, actions="ok", merchant=False, contract=False):
    """contract=True 表示订单数据带契约 actions[]；正文订单卡默认只有「查看订单」。"""
    head = f'''<div class="cf-card__head" data-mc-part="head">
    <span class="cf-card__label" data-mc-part="label">订单</span>
    <span class="cf-order-card__no" data-mc-part="order-no">#{no}</span>
    <time class="cf-card__meta" data-mc-part="created">{time} 下单</time>
  </div>'''
    if state == "loading":
        return f'''<div class="cf-card cf-order-card" data-mc-card="order" data-mc-state="loading" aria-busy="true">
  <div class="cf-card__head" data-mc-part="head"><span class="cf-card__label">订单</span>{skel("s")}</div>
  <div class="cf-card__body" data-mc-part="body"><div class="cf-order-card__main"><span class="cf-thumb cf-thumb--sm cf-skeleton-box" aria-hidden="true"></span><div class="cf-order-card__info">{skel("l")}{skel("s")}</div></div></div>
  <p class="cf-visually-hidden">订单加载中</p>
</div>'''
    if state == "error":
        return f'''<div class="cf-card cf-order-card" data-mc-card="order" data-mc-state="error">
  {head}
  <div class="cf-card__body" data-mc-part="body"><p class="cf-card__error" data-mc-part="error">订单详情读取失败，Woo 接口未响应。</p></div>
  <div class="cf-card__actions" data-mc-part="actions"><button class="cf-textbtn cf-textbtn--link" type="button">重试</button></div>
</div>'''
    if noitem:
        title = '<p class="cf-order-card__title cf-order-card__title--fallback" data-mc-part="first-item" data-mc-state="missing">商品明细见订单页</p>'
    else:
        title = f'<p class="cf-order-card__title" data-mc-part="first-item" title="{item}">{item}</p>'
    more = "" if (nocount or count <= 1) else f'<span class="cf-order-card__more" data-mc-part="item-count">共 {count} 件</span>'
    th = thumb_missing("单" if noitem else item[0]) if (nothumb or noitem) else thumb("sm")
    st = {"ok": "", "fallback": ' data-mc-state="actions-fallback"', "none": ' data-mc-state="actions-none"'}[actions]
    acts = actions_html(code, actions if (contract or actions != "ok") else "fallback", merchant)
    foot = "" if merchant else f'<div class="cf-card__actions" data-mc-part="actions">{acts}</div>'
    if merchant:   # 商家视角：订单号即 admin_url 链接；「在 Woo 后台查看」只在右栏保留一处（S5）
        head = head.replace(f'<span class="cf-order-card__no" data-mc-part="order-no">#{no}</span>',
                            f'<a class="cf-link cf-order-card__no" data-mc-part="order-no" data-mc-action="view" href="#woo-admin-order">#{no}</a>')
    return f'''<div class="cf-card cf-order-card" data-mc-card="order" data-mc-order="{no}" data-mc-status="{code}"{st}>
  {head}
  <div class="cf-card__body" data-mc-part="body">
    <div class="cf-order-card__main">
      {th}
      <div class="cf-order-card__info">{title}{more}</div>
      <div class="cf-order-card__state">{status(code)}<span class="cf-order-card__amount" data-mc-part="amount"><span class="cf-order-card__amount-k">实付</span>{amount}</span></div>
    </div>
  </div>
  {foot}
</div>'''


# ---------- 订单行：my-orders 与 commerce-context.orders[] / vendor-orders 同构 ----------
def order_row(code="processing", no="10077", item="", count=1, amount="", date="", state="ok", nothumb=False,
              noitem=False, nocount=False, actions="ok", merchant=False, compact=False):
    cls = "cf-order-row" + (" cf-order-row--compact" if compact else "")
    if state == "loading":
        return (f'<li class="{cls}" data-mc-card="order-row" data-mc-state="loading" aria-busy="true">'
                f'<div class="cf-order-row__head" data-mc-part="head">{skel("s")}</div>'
                f'<div class="cf-order-row__body" data-mc-part="body"><span class="cf-thumb cf-thumb--sm cf-skeleton-box" aria-hidden="true"></span>'
                f'<div class="cf-order-row__info">{skel("l")}{skel("m")}</div></div><span class="cf-visually-hidden">订单加载中</span></li>')
    if noitem:
        title = '<p class="cf-order-row__title cf-order-row__title--fallback" data-mc-part="first-item" data-mc-state="missing">商品明细见订单页</p>'
    else:
        title = f'<p class="cf-order-row__title" data-mc-part="first-item" title="{item}">{item}</p>'
    cnt = "" if nocount else f'<p class="cf-order-row__count" data-mc-part="item-count">共 {count} 件</p>'
    th = thumb_missing("单" if noitem else item[0]) if (nothumb or noitem) else thumb("sm")
    st = {"ok": "", "hide": "", "fallback": ' data-mc-state="actions-fallback"', "none": ' data-mc-state="actions-none"'}[actions]
    foot = "" if (actions == "hide" or merchant) else f'<div class="cf-order-row__actions" data-mc-part="actions">{actions_html(code, actions, merchant)}</div>'
    no_html = (f'<a class="cf-link cf-order-row__no" data-mc-part="order-no" data-mc-action="view" href="#woo-admin-order">#{no}</a>' if merchant
               else f'<span class="cf-order-row__no" data-mc-part="order-no">#{no}</span>')
    return f'''<li class="{cls}" data-mc-card="order-row" data-mc-order="{no}" data-mc-status="{code}"{st}>
  <div class="cf-order-row__head" data-mc-part="head">{no_html}<time class="cf-order-row__date" data-mc-part="created">{date}</time><span class="cf-order-row__status">{status(code)}</span></div>
  <div class="cf-order-row__body" data-mc-part="body">{th}<div class="cf-order-row__info">{title}{cnt}</div><span class="cf-order-row__amount" data-mc-part="amount">{amount}</span></div>
  {foot}
</li>'''


def order_list(rows="", state="ok", label="订单"):
    if state == "empty":
        return '<div class="cf-order-list__msg" data-mc-part="list-empty" data-mc-state="empty"><p>在本店还没有订单。</p><a class="cf-link" href="#">去逛逛</a></div>'
    if state == "empty-merchant":
        return '<div class="cf-order-list__msg" data-mc-part="list-empty" data-mc-state="empty"><p>该客户在本店还没有订单。</p></div>'
    if state == "error":
        return ('<div class="cf-order-list__msg cf-order-list__msg--error" data-mc-part="list-error" data-mc-state="error">'
                '<p>订单读取失败（Woo 接口未响应）。</p><button class="cf-textbtn cf-textbtn--link" type="button">重试</button></div>')
    if state == "loading":
        rows = order_row(state="loading") + order_row(state="loading")
    return f'<ul class="cf-order-list" data-mc-part="order-list" aria-label="{label}">{rows}</ul>'


# ---------- 系统事件：居中一行浅灰小字（只用契约现有事件类型） ----------
def event(kind, no, text, time, st=None):
    """st = 系统卡自带的 woo_status：status_changed 用 to_status，order_paid 记 processing，order_card 记发卡时状态。"""
    subj = f"订单 #{no} " if no else ""
    sa = f' data-mc-status="{st}"' if st else ""
    oa = f' data-mc-order="{no}"' if no else ""
    return (f'<p class="cf-event" data-mc-event="{kind}"{oa}{sa} role="status">'
            f'<span class="cf-event__text">{subj}{text}</span><span class="cf-event__sep" aria-hidden="true">·</span>'
            f'<time class="cf-event__time">{time}</time></p>')


# ---------- 订单芯片条 ----------
CHIPS = [("10077", "completed", "¥199.00", True), ("10052", "on-hold", "¥89.00", False), ("10031", "completed", "¥318.00", False),
         ("10019", "pending", "¥39.00", False), ("10008", "cancelled", "¥129.00", False), ("9987", "refunded", "¥59.00", False),
         ("9970", "failed", "¥19.90", False)]


def chip(no, code, amount, tagged=False, current=False):
    t = '<span class="cf-order-chip__tag" data-mc-part="chip-tag">本商品</span>' if tagged else ""
    cur = ' aria-current="true"' if current else ""
    return (f'<button class="cf-order-chip" data-mc-part="order-chip" data-mc-order="{no}" type="button"{cur} aria-label="把订单 #{no} 发到对话">'
            f'<span class="cf-order-chip__no">#{no}</span>{status(code)}<span class="cf-order-chip__amount">{amount}</span>{t}</button>')


def order_rail(state="ok", n=3):
    label = '<span class="cf-order-rail__label">我的订单</span>'
    if state == "empty":
        inner = f'{label}<p class="cf-order-rail__msg" data-mc-part="rail-empty">在本店还没有订单</p><a class="cf-link cf-order-rail__all" href="#">去逛逛</a>'
    elif state == "loading":
        sk = "".join('<span class="cf-order-chip cf-order-chip--skeleton" aria-hidden="true"></span>' for _ in range(3))
        inner = f'{label}<div class="cf-order-rail__chips" aria-busy="true">{sk}</div><span class="cf-visually-hidden">订单加载中</span>'
    elif state == "error":
        inner = f'{label}<p class="cf-order-rail__msg cf-order-rail__msg--error" data-mc-part="rail-error">订单加载失败</p><button class="cf-textbtn cf-textbtn--link" type="button">重试</button>'
    elif state == "collapsed":
        inner = (f'<button class="cf-order-rail__toggle" type="button" aria-expanded="false" data-mc-part="rail-toggle">我的订单 · {len(CHIPS)} 单{ICON["chev"]}</button>'
                 f'<span class="cf-order-rail__peek">最近：#10077 {status("completed")}</span>')
    else:
        chips = "".join(chip(no, c, a, tagged=t, current=t) for no, c, a, t in CHIPS[:n])
        alln = f" {n}" if n > 5 else ""
        inner = f'{label}<div class="cf-order-rail__chips" data-mc-part="rail-chips">{chips}</div><a class="cf-link cf-order-rail__all" data-mc-part="rail-all" href="#my-orders">全部{alln}</a>'
    return f'<nav class="cf-order-rail" data-mc-part="order-rail" data-mc-state="{state}" aria-label="我的订单（本店）">{inner}</nav>'


# ---------- 消息 ----------
def msg(side, text, time, inner=None, failed=False):
    who = "我" if side == "mine" else "文派示例店"
    initial = "我" if side == "mine" else "文"
    body = inner if inner else f'<div class="cf-bubble" data-mc-part="bubble">{text}</div>'
    meta = (f'<p class="cf-msg__meta cf-msg__meta--error" data-mc-part="msg-meta">发送失败 · <button class="cf-textbtn cf-textbtn--link" type="button">重发</button></p>'
            if failed else f'<p class="cf-msg__meta cf-visually-hidden" data-mc-part="msg-meta"><time>{time}</time></p>')
    st = ' data-mc-state="failed"' if failed else ""
    return f'''<div class="cf-msg cf-msg--{side}" data-mc-part="msg" data-mc-side="{side}"{st}>
      <span class="cf-avatar cf-msg__avatar" aria-hidden="true">{initial}</span>
      <div class="cf-msg__main"><p class="cf-msg__name" data-mc-part="msg-name">{who}</p>{body}{meta}</div>
    </div>'''


# ---------- 侧栏：事件时间线（事件 / Woo 状态分两列） ----------
def timeline(rows):
    trs = []
    for t, e, k, s in rows:
        st = status(s) if s else '<span class="cf-side__na">—</span>'
        trs.append(f'<tr data-mc-event="{k}"><td class="cf-side__time">{t}</td><td>{e}</td><td>{st}</td></tr>')
    body = "".join(trs)
    return ('<table class="cf-side__timeline"><thead><tr><th scope="col">时间</th><th scope="col">事件</th><th scope="col">订单状态</th></tr></thead>'
            f'<tbody>{body}</tbody></table>')


TIMELINE = [("10-29 21:38", "发订单卡", "order_card", "pending"), ("10-29 21:42", "已付款", "order_paid", "processing"),
            ("10-30 09:27", "状态更新为「已完成」", "status_changed", "completed")]


def side(state="ok"):
    if state == "none":
        return '''<aside class="cf-side" data-mc-part="side" data-mc-state="none" aria-label="订单当前态">
  <section class="cf-side__section"><h3 class="cf-side__title">当前订单</h3><p class="cf-side__empty">这次咨询还没有关联订单。买家下单或发订单卡后会出现在这里。</p></section></aside>'''
    if state == "error":
        return '''<aside class="cf-side" data-mc-part="side" data-mc-state="error" aria-label="订单当前态">
  <section class="cf-side__section"><h3 class="cf-side__title">当前订单</h3><p class="cf-side__empty cf-side__empty--error">读取 Woo 订单失败。</p><button class="cf-textbtn cf-textbtn--link" type="button">重试</button></section></aside>'''
    facts = kv("订单号", "#10077", True) + kv("订单状态", status("completed")) + kv("实付", "¥199.00", True)
    return f'''<aside class="cf-side" data-mc-part="side" aria-label="订单当前态">
  <section class="cf-side__section" data-mc-part="side-current"><h3 class="cf-side__title">当前订单</h3><dl class="cf-side__facts">{facts}</dl><a class="cf-link" href="#woo-view">在 Woo 查看</a></section>
  <section class="cf-side__section" data-mc-part="side-timeline"><h3 class="cf-side__title">事件</h3>{timeline(TIMELINE)}</section>
</aside>'''


# ---------- 挂件部件 ----------
def product_strip(sent=False):
    if sent:   # 询商卡已发出：商品条收成一行，去掉「发给商家」，避免和卡片重复
        return ('<div class="cf-product-strip cf-product-strip--sent" data-mc-part="product-strip" data-mc-state="sent">'
                '<p class="cf-product-strip__title" title="WP 多站点内容同步插件 Pro">正在咨询：WP 多站点内容同步插件 Pro</p>'
                '<span class="cf-product-strip__price">¥199.00</span><span class="cf-product-strip__done">已发给商家</span></div>')
    return f'''<div class="cf-product-strip" data-mc-part="product-strip" aria-label="正在咨询的商品">
    {thumb("sm")}
    <div class="cf-product-strip__info"><p class="cf-product-strip__title" title="WP 多站点内容同步插件 Pro">WP 多站点内容同步插件 Pro</p><p class="cf-product-strip__price">¥199.00</p></div>
    <a class="cf-link cf-product-strip__send" data-mc-part="product-send" href="#">发给商家</a>
  </div>'''


def contact():
    return '''<details class="cf-contact" data-mc-part="contact">
    <summary class="cf-contact__summary">留联系方式<span class="cf-contact__hint">选填 · 回复会同时发到邮箱</span></summary>
    <div class="cf-contact__fields">
      <label class="cf-field"><span class="cf-field__label">称呼</span><input class="cf-field__input" name="name" autocomplete="nickname" /></label>
      <label class="cf-field"><span class="cf-field__label">邮箱</span><input class="cf-field__input" name="email" type="email" autocomplete="email" /></label>
      <button class="cf-btn cf-btn--outline" type="button">保存</button>
    </div>
  </details>'''


def quick_replies(items):
    out = []
    for k, t in items:
        if k in ("view", "refund"):   # 跳 Woo 的链接：不发消息、不产生事件行
            out.append(f'<a class="cf-quick__item" data-mc-part="quick" data-mc-quick="{k}" data-mc-action="{k}" href="#woo-{k}">{t}</a>')
        else:                          # 发一句固定文本
            out.append(f'<button class="cf-quick__item" data-mc-part="quick" data-mc-quick="{k}" type="button">{t}</button>')
    body = "".join(out)
    return f'<div class="cf-quick" data-mc-part="quick-replies" aria-label="快捷问题">{body}</div>'


def composer(qr, placeholder="输入消息，Enter 发送"):
    i = uid("cf-input")
    return f'''<div class="cf-composer-dock" data-mc-part="composer-dock">
  {quick_replies(qr)}
  <form class="cf-composer" data-mc-part="composer" onsubmit="return false">
    <div class="cf-composer__tools">
      <button class="cf-iconbtn" type="button" aria-label="发图片">{ICON["image"]}</button>
      <button class="cf-iconbtn" type="button" aria-label="选订单发送">{ICON["order"]}</button>
    </div>
    <label class="cf-visually-hidden" for="{i}">输入消息</label>
    <textarea id="{i}" class="cf-composer__input" rows="1" placeholder="{placeholder}"></textarea>
    <button class="cf-btn cf-btn--send cf-composer__send" type="submit">发送</button>
  </form>
  </div>'''


SHOP_SUB = '<span data-mc-part="reply-hint">工作日约 2 小时内回复</span>'   # shop.reply_hint（可选，空则整行隐藏）；不画任何在线状态


def widget_shell(main, title="文派示例店", sub=SHOP_SUB, top="", thread=None, page=None, label="挂件会话"):
    attrs = ' data-mc-surface="widget"'
    if thread:
        attrs += f' data-mc-thread="{thread}"'
    if page:
        attrs += f' data-mc-page="{page}"'
    sub_html = f'<p class="cf-widget__sub">{sub}</p>' if sub else ""
    return f'''<section class="cf-widget"{attrs} aria-label="{label}">
  <header class="cf-widget__head" data-mc-part="widget-head">
    <button class="cf-iconbtn" type="button" aria-label="返回">{ICON["back"]}</button>
    <div class="cf-widget__who"><h1 class="cf-widget__name">{title}</h1>{sub_html}</div>
  </header>
  {top}
  <div class="cf-widget__layout">
  <div class="cf-widget__main">
  {main}
  </div>
  </div>
</section>'''


def convo(thread_html, qr, placeholder="输入消息，Enter 发送"):
    return f'<div class="cf-thread" data-mc-part="thread" aria-live="polite">{thread_html}</div>{composer(qr, placeholder)}'


# ---------- ③ 留资表单 ----------
def field(fid, label, name, typ, value, auto, error=None):
    err_id = f"{fid}-err"
    inv = f' aria-invalid="true" aria-describedby="{err_id}"' if error else ""
    val = f' value="{value}"' if value else ""
    err = f'<p class="cf-field__error" id="{err_id}" data-mc-part="field-error">{error}</p>' if error else ""
    st = ' data-mc-state="invalid"' if error else ""
    return (f'<div class="cf-field" data-mc-part="field-{name}"{st}><label class="cf-field__label" for="{fid}">{label}<span class="cf-field__req">必填</span></label>'
            f'<input class="cf-field__input" id="{fid}" name="{name}" type="{typ}" autocomplete="{auto}" required{val}{inv} />{err}</div>')


def lead_form(state="idle"):
    n = next(_n)
    head = (f'<div class="cf-card__head" data-mc-part="head"><span class="cf-card__label" id="lf-t-{n}" data-mc-part="label">留下联系方式</span>'
            '<span class="cf-card__meta">回复会同时发到邮箱</span></div>')
    if state in ("success", "bridge"):
        if state == "success":
            body = '<p class="cf-alert" data-mc-tone="success" role="status" data-mc-part="lead-success">已保存。商家的回复会发到 x***@example.com，也会显示在这里。</p>'
            act = '<button class="cf-textbtn cf-textbtn--link" type="button">修改联系方式</button>'
        else:
            body = '<p class="cf-lead-form__bridge" data-mc-part="lead-bridge">已用论坛账号 xiaowang 登录，无需填写。回复会通知到论坛私信和邮箱。</p>'
            act = '<button class="cf-textbtn cf-textbtn--link" type="button">换个邮箱</button>'
        return f'''<section class="cf-card cf-lead-form" data-mc-card="lead-form" data-mc-state="{state}" aria-labelledby="lf-t-{n}">
  {head}
  <div class="cf-card__body" data-mc-part="body">{body}</div>
  <div class="cf-card__actions" data-mc-part="actions">{act}</div>
</section>'''
    name_v = "" if state == "idle" else "小王"
    email_v = {"idle": "", "invalid": "xiaowang@"}.get(state, "xiaowang@example.com")
    err = "邮箱格式不对，例如 name@example.com" if state == "invalid" else None
    alert = ('<p class="cf-alert" data-mc-tone="danger" role="alert" data-mc-part="lead-error">提交失败：网络或服务暂时不可用，填写的内容已保留。</p>'
             if state == "error" else "")
    hp = (f'<div class="cf-lead-form__hp" aria-hidden="true" data-mc-part="honeypot"><label for="lf-hp-{n}">网址（请留空）</label>'
          f'<input id="lf-hp-{n}" name="website" type="text" tabindex="-1" autocomplete="off" /></div>')
    hidden = '<input type="hidden" name="form_started_at" value="2026-10-30T09:28:00+08:00" />'
    btns = {"submitting": '<button class="cf-btn cf-btn--outline" type="submit" disabled>提交中…</button>',
            "error": '<button class="cf-btn cf-btn--outline" type="submit">重试提交</button>'}
    btn = btns.get(state, '<button class="cf-btn cf-btn--outline" type="submit">保存联系方式</button>')
    busy = ' aria-busy="true"' if state == "submitting" else ""
    f_name = field(f"lf-name-{n}", "称呼", "name", "text", name_v, "name")
    f_mail = field(f"lf-email-{n}", "邮箱", "email", "email", email_v, "email", err)
    return f'''<form class="cf-card cf-lead-form" data-mc-card="lead-form" data-mc-state="{state}" aria-labelledby="lf-t-{n}" novalidate{busy} onsubmit="return false">
  {head}
  <div class="cf-card__body" data-mc-part="body">
    {alert}{f_name}{f_mail}{hp}{hidden}
    <p class="cf-lead-form__note" data-mc-part="lead-note">只用于回复这次咨询，不公开、不群发。</p>
  </div>
  <div class="cf-card__actions" data-mc-part="actions">{btn}</div>
</form>'''


# ---------- ①②③ 挂件 ----------
def widget(kind):
    if kind == "inquiry":
        thread = f'''<p class="cf-daychip" data-mc-part="daychip">今天 21:30</p>
    {msg("mine", "", "21:30", inner=inquiry_card())}
    {msg("theirs", "支持 6.6，已在 6.6.2 上测过。单站授权可以在后台自助换绑一次域名。", "21:33")}
    {msg("mine", "现在下单今天能拿到授权码吗？", "21:35")}
    <p class="cf-daychip" data-mc-part="daychip">21:36</p>
    {msg("theirs", "可以，付款后 10 分钟内自动发到邮箱。", "21:36")}
    {msg("mine", "好的，我去拍。", "21:37", failed=True)}'''
        qr = [("stock", "问库存"), ("invoice", "能开发票吗"), ("deliver", "多久发货")]
        return widget_shell(convo(thread, qr), top=product_strip(sent=True) + contact(), thread="inquiry", label="咨询商品")
    if kind == "order":
        c2 = order_card("completed", no="10031", item="中文字体包 · 思源宋体商用授权", count=3, amount="¥318.00", time="10-28 09:58", nothumb=True, contract=True)
        thread = f'''<p class="cf-daychip" data-mc-part="daychip">10-29 21:38</p>
    {msg("mine", "", "21:38", inner=order_card("completed", time="10-29 21:38", contract=True))}
    {event("order_paid", "10077", "已付款", "10-29 21:42", "processing")}
    <p class="cf-daychip" data-mc-part="daychip">今天 09:20</p>
    {msg("mine", "昨晚付的款，授权码还没收到，麻烦看下。", "09:20")}
    {msg("theirs", "抱歉，邮件被拦截了。已重新发送，并同步放到「我的账户 › 下载」。", "09:26")}
    {event("status_changed", "10077", "状态更新为「已完成」", "09:27", "completed")}
    <p class="cf-daychip" data-mc-part="daychip">09:40</p>
    {msg("mine", "", "09:40", inner=c2)}
    {msg("mine", "这单里的字体包想退掉，可以吗？", "09:41")}
    {msg("theirs", "可以。点订单卡上的「申请退款」，在订单页提交就行，我这边 1 个工作日内处理。", "09:44")}'''
        qr = [("invoice", "开发票"), ("refund", "申请退款"), ("view", "查看订单")]
        return widget_shell(convo(thread, qr), top=order_rail("ok", 7), thread="order", sub="", label="订单售后")
    thread = f'''<p class="cf-daychip" data-mc-part="daychip">今天 09:28</p>
    {msg("theirs", "你好，这里是文派示例店。想了解哪款插件或主题？", "09:28")}
    {msg("theirs", "", "09:28", inner=lead_form("idle"))}'''
    qr = [("catalog", "有哪些插件"), ("invoice", "能开发票吗"), ("custom", "定制开发")]
    return widget_shell(convo(thread, qr, "也可以直接提问，发送时会带上联系方式"), thread="presales", label="售前咨询")


# ---------- 售后进度 ----------
def steps(esc="pending", since="10-30 09:41", vertical=False):
    st2 = "current" if esc == "pending" else "done"
    st3 = "todo" if esc == "pending" else "done"
    items = [("买家发起售后", "done", since), ("商家处理中", st2, ""), ("处理完成", st3, "10-30 11:02" if esc == "done" else "")]
    out = []
    for i, (label, s, t) in enumerate(items):
        if i:
            out.append('<li class="cf-steps__sep" aria-hidden="true">›</li>')
        tm = f'<time class="cf-steps__time">{t}</time>' if t else ""
        cur = ' aria-current="step"' if s == "current" else ""
        out.append(f'<li class="cf-steps__item" data-mc-part="step" data-mc-state="{s}"{cur}><span class="cf-steps__dot" aria-hidden="true"></span>{label}{tm}</li>')
    v = " cf-steps--vertical" if vertical else ""
    body = "".join(out)
    return f'<ol class="cf-steps{v}" data-mc-part="steps" data-mc-state="{esc}" aria-label="售后进度">{body}</ol>'


# ---------- 子页面 ----------
MY = [("completed", "10077", "WP 多站点内容同步插件 Pro", 1, "¥199.00", "10-29 21:38", {}),
      ("pending", "10019", "SEO 结构化数据插件", 1, "¥39.00", "10-29 08:12", {}),
      ("on-hold", "10052", "WooCommerce 微信支付网关", 1, "¥89.00", "10-28 19:40", {}),
      ("completed", "10031", "中文字体包 · 思源宋体商用授权", 3, "¥318.00", "10-28 09:58", {"nothumb": True}),
      ("cancelled", "10008", LONG, 1, "¥129.00", "10-27 15:12", {}),
      ("refunded", "9987", "古腾堡区块合集", 1, "¥59.00", "10-20 11:02", {}),
      ("failed", "9970", "图片压缩插件", 1, "¥19.90", "10-18 13:05", {})]


def page_my_orders():
    rows = "".join(order_row(*o[:6], **o[6]) for o in MY)
    main = (f'<div class="cf-page" data-mc-part="page">{order_list(rows, label="我的订单")}'
            '<p class="cf-page__note">付款、退款、改单会打开店铺的订单页。</p></div>')
    return widget_shell(main, title="我的订单", sub="文派示例店 · 7 单", page="my-orders", label="我的订单")


def detail_items(names, total=None):
    li = "".join(f'<li class="cf-page__item" data-mc-part="item">{thumb_missing(n[0])}<span class="cf-page__item-name" title="{n}">{n}</span></li>' for n in names)
    total = total or len(names)
    note = (f'<p class="cf-page__note">共 {total} 件，这里列出前 {len(names)} 件，完整清单见订单页。</p>' if total > len(names) else "")
    return f'''<section class="cf-page__section" data-mc-part="detail-items">
    <h3 class="cf-page__title">商品 · 共 {total} 件</h3>
    <ul class="cf-page__items">{li}</ul>{note}
  </section>'''


def page_order_detail():
    facts = kv("下单", "10-28 09:58", True) + kv("付款", "10-28 10:00", True) + kv("实付", "¥318.00", True)
    items = detail_items(["思源宋体商用授权（单机）", "思源黑体商用授权（单机）", "文派字体子集化工具 · 1 年"])
    main = f'''<div class="cf-page" data-mc-part="page">
  <section class="cf-page__section" data-mc-part="detail-status" data-mc-order="10031" data-mc-status="completed">
    <div class="cf-page__headrow"><span class="cf-page__no">#10031</span>{status("completed")}</div>
    <dl class="cf-side__facts">{facts}</dl>
  </section>
  {items}
  <p class="cf-page__note">订单状态以店铺订单页为准。付款、退款、改单会打开店铺的订单页。</p>
</div>
<div class="cf-page__dock" data-mc-part="actions">
  <button class="cf-textbtn cf-textbtn--link cf-page__dock-left" type="button" data-mc-action="send-card">发到对话</button>
  {actions_html("completed")}
</div>'''
    return widget_shell(main, title="订单 #10031", sub="文派示例店 · 10-28 下单", page="order-detail", label="订单详情")


def page_aftersale():
    row = order_list(order_row("completed", "10031", "中文字体包 · 思源宋体商用授权", 3, "¥318.00", "10-28 09:58", nothumb=True, actions="hide"))
    main = f'''<div class="cf-page" data-mc-part="page">
  <section class="cf-page__section" data-mc-part="aftersale-progress">
    <h3 class="cf-page__title">售后进度</h3>
    {steps("pending", vertical=True)}
    <p class="cf-page__note">转人工后商家会在对话里回复；退款完成后，这里会显示「已退款」。</p>
  </section>
  <section class="cf-page__section" data-mc-part="aftersale-order">
    <h3 class="cf-page__title">关联订单</h3>
    {row}
  </section>
  <section class="cf-page__section" data-mc-part="aftersale-howto">
    <h3 class="cf-page__title">怎么退款</h3>
    <p class="cf-page__note">点「申请退款」会打开店铺的订单页，在那里提交。</p>
  </section>
</div>
<div class="cf-page__dock" data-mc-part="actions">
  <a class="cf-link cf-page__dock-left" href="#">回到对话</a>
  <a class="cf-link" data-mc-action="view" href="#woo-view">查看订单</a>
  <a class="cf-btn cf-btn--outline" data-mc-action="refund" href="#woo-refund">申请退款</a>
</div>'''
    return widget_shell(main, title="售后 · 订单 #10031", sub="文派示例店", thread="aftersale", page="aftersale", label="售后")


# ---------- ④ 商家三栏（Discourse PM） ----------
INBOX = [
    ("aftersale", "chen.m", "售后", "这单里的字体包想退掉，可以吗？", "09:41", 1, True),
    ("presales", "访客 · 7f3a9c", "售前", "想做一个中英双语站，插件怎么搭配比较好？预算 500 以内，最好今天能给个方案", "09:30", 1, True),
    ("order", "lin_dev", "订单", "昨晚付的款，授权码还没收到，麻烦看下。", "09:20", 0, True),
    ("inquiry", "xiaowang", "询商", "另外有没有教育优惠？", "昨天", 2, True),
    ("inquiry", "zhou_wp", "询商", "你：单站版可以随时升级多站，差价补齐即可。", "昨天", 0, False),
    ("order", "访客 · 2b91e0", "订单", "你：授权码已重新发送，请查收邮箱。", "10-27", 0, False),
]


def inbox(current="inquiry", state="ok", nounread=True):   # unread 字段未补前不显示角标
    head = ('<header class="cf-inbox__head" data-mc-part="inbox-head"><h2 class="cf-inbox__title">店铺私信</h2>'
            '<div class="cf-inbox__filters" role="group" aria-label="筛选">'
            '<button class="cf-inbox__filter" type="button" aria-pressed="false">待回复 4</button>'
            '<button class="cf-inbox__filter" type="button" aria-pressed="true">全部</button></div></header>')
    if state == "empty":
        body = '<div class="cf-inbox__msg" data-mc-part="inbox-empty"><p>还没有私信。买家从挂件或论坛发起咨询后会出现在这里。</p></div>'
    elif state == "error":
        body = ('<div class="cf-inbox__msg cf-inbox__msg--error" data-mc-part="inbox-error"><p>收件箱读取失败。</p>'
                '<button class="cf-textbtn cf-textbtn--link" type="button">重试</button></div>')
    elif state == "loading":
        one = f'<li><span class="cf-inbox__row cf-inbox__row--skeleton" aria-hidden="true"><span class="cf-avatar cf-inbox__avatar cf-skeleton-box"></span>{skel("m")}{skel("s")}{skel("l")}</span></li>'
        body = f'<ul class="cf-inbox__list" data-mc-part="inbox-list" aria-busy="true">{one * 4}</ul><p class="cf-visually-hidden">收件箱加载中</p>'
    else:
        items, seen = [], False
        for kind, name, label, ex, t, unread, pending in INBOX:
            cur = ""
            if kind == current and not seen:
                cur, seen = ' aria-current="page"', True
            un = (f'<span class="cf-inbox__unread" data-mc-part="unread">{unread}<span class="cf-visually-hidden"> 条未读</span></span>' if (unread and not nounread) else "")
            pd = tag("待回复", "warning", "pending") if pending else ""
            items.append(f'''<li><a class="cf-inbox__row" href="#" data-mc-part="inbox-row" data-mc-thread="{kind}"{cur}>
        <span class="cf-avatar cf-inbox__avatar" aria-hidden="true">{name[0]}</span>
        <span class="cf-inbox__who"><span class="cf-inbox__name">{name}</span><span class="cf-inbox__kind">{label}</span></span>
        <time class="cf-inbox__time">{t}</time>
        <span class="cf-inbox__excerpt" data-mc-part="excerpt" title="{ex}">{ex}</span>
        <span class="cf-inbox__flags">{un}{pd}</span>
      </a></li>''')
        lis = "".join(items)
        body = f'<ul class="cf-inbox__list" data-mc-part="inbox-list">{lis}</ul>'
    return f'<nav class="cf-inbox" data-mc-part="inbox" data-mc-state="{state}" aria-label="店铺私信收件箱">{head}{body}</nav>'


MSIDE = {   # 历史订单来自 vendor-orders，已排除当前订单（F5）
    "inquiry": dict(user="xiaowang", email="x***@example.com", kind=("询商", "inquiry"), current=None,
                    timeline=[("10-29 21:30", "发起咨询", "inquire", None), ("10-29 21:30", "带商品快照", "product_ctx", None)],
                    orders=[("on-hold", "10102", "WooCommerce 微信支付网关", 1, "¥89.00", "10-26"),
                            ("refunded", "9950", "古腾堡区块合集", 1, "¥59.00", "10-02")]),
    "order": dict(user="lin_dev", email="l***@example.org", kind=("订单", "order"), current=("10088", "processing", "¥199.00"),
                  timeline=[("10-29 21:38", "发订单卡", "order_card", "pending"), ("10-29 21:42", "已付款", "order_paid", "processing")],
                  orders=[("completed", "10035", "SEO 结构化数据插件", 1, "¥39.00", "10-12"),
                          ("failed", "9961", "图片压缩插件", 1, "¥19.90", "10-05")]),
    "aftersale": dict(user="chen.m", email="c***@example.net", kind=("售后", "aftersale"), current=("10064", "completed", "¥318.00"),
                      esc=("pending", "10-30 09:41"),
                      timeline=[("10-28 09:58", "发订单卡", "order_card", "pending"), ("10-28 10:00", "已付款", "order_paid", "processing"),
                                ("10-28 10:35", "状态更新为「已完成」", "status_changed", "completed")],
                      orders=[("cancelled", "10045", LONG, 1, "¥129.00", "10-02")]),
}


def merchant_side(topic, sid, guest=False, orders_state="ok"):
    c = MSIDE[topic]
    if guest:
        who = '<span data-mc-part="buyer-guest">访客 · <span class="cf-side__hash">7f3a9c</span></span>'
        ident = "加盐邮箱哈希（前 6 位）"
    else:
        user = c["user"]
        who = f'<a class="cf-link" href="#" data-mc-part="buyer-user">@{user}</a>'
        ident = "论坛用户"
    em = c["email"]
    email = f'<span data-mc-part="email-masked">{em}</span>'
    kl, kc = c["kind"]
    cur = kv("会话类型", kl)
    esc = c.get("esc")
    if esc:
        cur += kv("售后进度", "处理中")
    if c["current"]:
        no, code, amt = c["current"]
        cur += kv("订单号", f"#{no}", True) + kv("订单状态", status(code)) + kv("实付", amt, True)
        extra = '<a class="cf-link" href="#woo-admin-order" data-mc-action="view">在 Woo 后台查看</a>'
    else:
        extra = '<p class="cf-side__empty">这次咨询还没有关联订单。</p>'
    if orders_state == "ok":
        hist = order_list("".join(order_row(*o, compact=True, merchant=True) for o in c["orders"]), label="历史订单")
    elif orders_state == "empty":
        hist = order_list(state="empty-merchant")
    else:
        hist = order_list(state="error")
    buyer = kv("买家", who) + kv("标识", ident) + kv("邮箱", email, True)
    tl = timeline(c["timeline"])
    return f'''<aside class="cf-side" id="{sid}" data-mc-part="side" aria-label="客户与订单">
  <section class="cf-side__section" data-mc-part="side-buyer"><h3 class="cf-side__title">客户</h3><dl class="cf-side__facts">{buyer}</dl></section>
  <section class="cf-side__section" data-mc-part="side-current"><h3 class="cf-side__title">当前状态</h3><dl class="cf-side__facts">{cur}</dl>{extra}</section>
  <section class="cf-side__section" data-mc-part="side-timeline"><h3 class="cf-side__title">事件</h3>{tl}</section>
  <section class="cf-side__section" data-mc-part="side-orders"><h3 class="cf-side__title">该客户在本店的历史订单</h3>{hist}</section>
</aside>'''


def pm_post(name, role, time, body):
    r = f'<span class="cf-pm-post__role" data-mc-part="role">{role}</span>' if role else ""
    return f'''<li class="cf-pm-post" data-mc-part="pm-post">
      <p class="cf-pm-post__meta"><span class="cf-avatar cf-avatar--sm" aria-hidden="true">{name[0]}</span><span class="cf-pm-post__name">{name}</span>{r}<time class="cf-pm-post__time">{time}</time></p>
      <div class="cf-pm-post__body" data-mc-part="pm-body">{body}</div>
    </li>'''


HINT = ('<p class="cf-pm__hint" data-mc-part="pm-hint">改单、退款请在 Woo 后台处理，处理后的状态会自动同步到这里。'
        '</p>')


def pm_conf(topic):
    if topic == "inquiry":
        stock = tag("有货", "success", "stock", ' data-mc-stock="instock"')
        ctx = (f'<div class="cf-pm-ctx" data-mc-part="ctx-product" data-mc-product="1201">{thumb("sm")}<div class="cf-pm-ctx__info">'
               f'<p class="cf-pm-ctx__title">WP 多站点内容同步插件 Pro</p><p class="cf-pm-ctx__meta"><span class="cf-pm-ctx__price">¥199.00</span>{stock}'
               '<span data-mc-part="snapshot">快照 10-29 21:30 · 价格以商品页为准</span></p></div><a class="cf-link" href="#">查看商品</a></div>')
        stream = (pm_post("xiaowang", "买家", "10-29 21:30", inquiry_card())
                  + pm_post("文派示例店", "商家（你）", "10-29 21:33", "<p>支持 6.6，已在 6.6.2 上测过。单站授权可以在后台自助换绑一次域名。</p>")
                  + pm_post("xiaowang", "买家", "10-29 21:35", "<p>现在下单今天能拿到授权码吗？</p>")
                  + pm_post("xiaowang", "买家", "10-29 21:36", "<p>另外有没有教育优惠？</p>"))
        return dict(crumb="私信 · 询商", title="咨询：WP 多站点内容同步插件 Pro", buyer="xiaowang", ctx=ctx, stream=stream, hint="",
                    peek='询商 · 无关联订单')
    if topic == "order":
        ctx = ""   # F5：不再置顶当前订单，流内订单卡 + 右栏当前状态已足够
        stream = (pm_post("lin_dev", "买家", "10-29 21:38", order_card("processing", no="10088", time="10-29 21:38", merchant=True))
                  + '<li class="cf-pm__events">' + event("order_paid", "10088", "已付款", "10-29 21:42", "processing") + "</li>"
                  + pm_post("lin_dev", "买家", "10-30 09:20", "<p>昨晚付的款，授权码还没收到，麻烦看下。</p>"))
        return dict(crumb="私信 · 订单", title="订单咨询：WP 多站点内容同步插件 Pro", buyer="lin_dev", ctx=ctx, stream=stream, hint=HINT,
                    peek="#10088 " + status("processing") + " · ¥199.00")
    c2 = order_card("completed", no="10064", item="中文字体包 · 思源宋体商用授权", count=3, amount="¥318.00", time="10-28 09:58", nothumb=True, merchant=True)
    ctx = steps("pending")
    stream = (pm_post("chen.m", "买家", "10-28 09:58", c2)
              + '<li class="cf-pm__events">' + event("order_paid", "10064", "已付款", "10-28 10:00", "processing")
              + event("status_changed", "10064", "状态更新为「已完成」", "10-28 10:35", "completed") + "</li>"
              + pm_post("chen.m", "买家", "10-30 09:41", "<p>这单里的字体包想退掉，可以吗？</p>"))
    return dict(crumb="私信 · 售后", title="售后咨询：中文字体包 · 思源宋体商用授权", buyer="chen.m", ctx=ctx, stream=stream, hint=HINT,
                peek="售后处理中 · #10064 " + status("completed"))


def merchant_pm(topic, sid):
    c = pm_conf(topic)
    i = uid("cf-pm-input")
    ctx_html = f'<div class="cf-pm__context" data-mc-part="topic-context">{c["ctx"]}</div>' if c["ctx"] else ""
    return f'''<section class="cf-pm" data-mc-surface="shop-pm" data-mc-topic="{topic}" aria-label="店铺私信（精简皮肤）">
  <header class="cf-pm__head" data-mc-part="pm-head">
    <div class="cf-pm__headrow">
      <a class="cf-link cf-mc__back" href="#" data-mc-part="back-inbox">{ICON["back"]}收件箱</a>
      <div class="cf-pm__headmain"><p class="cf-pm__crumb">{c["crumb"]}</p><h1 class="cf-pm__title">{c["title"]}</h1></div>
      <button class="cf-btn cf-btn--outline cf-mc__sidetoggle" type="button" aria-expanded="false" aria-controls="{sid}" data-mc-part="side-toggle">客户与订单</button>
    </div>
    <p class="cf-pm__peek" data-mc-part="side-peek">{c["peek"]}</p>
  </header>
  {ctx_html}
  <ol class="cf-pm__stream" data-mc-part="pm-stream">{c["stream"]}</ol>
  <form class="cf-pm__composer" data-mc-part="pm-composer" onsubmit="return false">
    <label class="cf-visually-hidden" for="{i}">回复</label>
    <input id="{i}" class="cf-pm__input" placeholder="回复 @{c["buyer"]}…" />
    <button class="cf-btn cf-btn--send" type="submit">发送</button>
  </form>
  {c["hint"]}
</section>'''


def merchant(topic):
    sid = uid("mc-side")
    return f'''<div class="cf-mc" data-mc-surface="merchant-pm" data-mc-topic="{topic}">
  <header class="cf-mc__bar" data-mc-part="mc-bar"><span class="cf-mc__brand">Cyberforums</span><span>私信 › 店铺收件箱</span><span class="cf-mc__whoami">文派示例店 · 商家</span></header>
  <div class="cf-mc__cols">{inbox(topic)}{merchant_pm(topic, sid)}{merchant_side(topic, sid)}</div>
</div>'''


# ---------- 预览页 ----------
def cell(cap, html, wide=False):
    w = " cf-preview__cell--wide" if wide else ""
    return f'<div class="cf-preview__cell{w}"><p class="cf-preview__cap">{cap}</p>{html}</div>'


def frame(html, cls=""):
    return f'<div class="cf-preview__frame {cls}">{html}</div>'


def grid(cells):
    return '<div class="cf-preview__grid">' + "".join(cells) + "</div>"


def parts1():
    multi = "".join([event("order_paid", "10031", "已付款", "10-28 10:00", "processing"),
                     event("status_changed", "10031", "状态更新为「保留」", "10-28 10:01", "on-hold"),
                     event("status_changed", "10031", "状态更新为「处理中」", "10-28 10:20", "processing"),
                     event("status_changed", "10031", "状态更新为「已完成」", "10-28 10:35", "completed"),
                     event("status_changed", "10031", "状态更新为「已退款」", "10-30 11:02", "refunded")])
    statuses = "".join(f'<span class="cf-preview__status">{status(k, raw=True)}</span>' for k in STATUS)
    return grid([
        cell("芯片条 · 无订单", frame(L(order_rail("empty"), "我的订单（示例：无订单）"))),
        cell("芯片条 · 加载中", frame(L(order_rail("loading"), "我的订单（示例：加载中）"))),
        cell("芯片条 · 接口失败", frame(L(order_rail("error"), "我的订单（示例：接口失败）"))),
        cell("芯片条 · 7 单（横向滚动；「全部」进我的订单）", frame(L(order_rail("ok", 7), "我的订单（示例：7 单）"), "cf-preview__frame--narrow")),
        cell("芯片条 · 7 单收起态（移动端默认）", frame(L(order_rail("collapsed"), "我的订单（示例：收起）"), "cf-preview__frame--narrow")),
        cell("对话 · 空", frame('<div class="cf-thread cf-thread--empty" data-mc-state="empty"><p class="cf-thread__empty">向商家提问吧，商家会尽快回复。</p></div>')),
        cell("商品条 · 未发送（带「发给商家」）", frame(product_strip())),
        cell("商品条 · 询商卡已发出 → 收成一行（S3）", frame(product_strip(sent=True))),
        cell("询商卡 · 商品名超长（两行截断）", inquiry_card(LONG)),
        cell("询商卡 · 加载中", inquiry_card(state="loading")),
        cell("询商卡 · 读取失败 / 已下架", inquiry_card(state="error")),
        cell("订单卡 · 默认（正文无 actions[]）→ 只有查看订单", order_card("pending", no="10019", item="SEO 结构化数据插件", amount="¥39.00")),
        cell("订单卡 · 待付款 + 带 actions[] → 查看订单 + 去支付（唯一描边按钮）", order_card("pending", no="10019", item="SEO 结构化数据插件", amount="¥39.00", contract=True)),
        cell("订单卡 · 处理中 + 带 actions[] → 查看订单 / 申请退款（都跳 Woo）", order_card("processing", contract=True)),
        cell("订单卡 · 已完成 + 多件", order_card("completed", no="10031", item="中文字体包 · 思源宋体商用授权", count=3, amount="¥318.00", time="10-28 09:58")),
        cell("订单卡 · 已取消 + 超长名 → 只有查看订单", order_card("cancelled", no="10008", item=LONG, amount="¥129.00", time="10-27 15:12")),
        cell("订单卡 · 加载中", order_card(state="loading")),
        cell("订单卡 · 读取失败", order_card(state="error")),
        cell("订单卡 · 缺 thumb → 灰底首字", order_card("refunded", no="9987", item="古腾堡区块合集", amount="¥59.00", time="10-20 11:02", nothumb=True)),
        cell("系统事件 · 同一单多次变状态（每次一行，不改旧行）", frame(multi, "cf-preview__frame--thread")),
        cell("侧栏 · 无关联订单", L(side("none"), "订单当前态（示例：无关联订单）")),
        cell("侧栏 · 读取失败", L(side("error"), "订单当前态（示例：读取失败）")),
        cell("Woo 状态 → 中文（五档）", f'<p class="cf-preview__statuses">{statuses}</p>', wide=True),
    ])


def parts2():
    R = lambda **kw: order_list(order_row(**kw))
    base = dict(code="processing", no="10077", item="WP 多站点内容同步插件 Pro", count=1, amount="¥199.00", date="10-29 21:38")
    many = detail_items(["思源宋体商用授权", "思源黑体商用授权", "霞鹜文楷商用授权", "站酷字体包", "阿里巴巴普惠体包", "文派字体子集化工具"], total=8)
    return grid([
        cell("订单行 · 处理中（actions = 查看订单 / 申请退款）", R(**base)),
        cell("订单行 · 待付款（去支付 = 唯一描边按钮）", R(**dict(base, code="pending", no="10019", item="SEO 结构化数据插件", amount="¥39.00"))),
        cell("订单行 · 缺 thumb → 灰底首字", R(**dict(base, nothumb=True))),
        cell("订单行 · 缺 first_item → 「商品明细见订单页」", R(**dict(base, noitem=True))),
        cell("订单行 · 缺 item_count → 不显示件数", R(**dict(base, nocount=True))),
        cell("订单行 · 缺 actions → 只给 view_url「查看订单」", R(**dict(base, actions="fallback"))),
        cell("订单行 · 无公网 url → 不渲染操作", R(**dict(base, actions="none"))),
        cell("订单行 · 四个可选字段全缺", R(**dict(base, noitem=True, nocount=True, actions="fallback"))),
        cell("我的订单 · 加载中", order_list(state="loading")),
        cell("我的订单 · 空", frame(order_list(state="empty"))),
        cell("我的订单 · 读取失败", frame(order_list(state="error"))),
        cell("订单卡 · 付款失败 + 带 actions[] → 查看订单 + 去支付", order_card("failed", no="9970", item="图片压缩插件", amount="¥19.90", time="10-18 13:05", contract=True)),
        cell("订单卡 · 缺 first_item（无 actions[] → 只有查看订单）", order_card("refunded", no="9987", amount="¥59.00", time="10-20 11:02", noitem=True, actions="fallback")),
        cell("订单详情 · 超过 6 件（items[] 截 6，item_count 给真实件数）", many),
        cell("售后进度 · 处理中", f'<div class="cf-page__section">{steps("pending")}</div>'),
        cell("售后进度 · 已完成", f'<div class="cf-page__section">{steps("done")}</div>'),
        cell("收件箱 · 加载中", frame(L(inbox(state="loading"), "店铺私信收件箱（示例：加载中）"))),
        cell("收件箱 · 空", frame(L(inbox(state="empty"), "店铺私信收件箱（示例：空）"))),
        cell("收件箱 · 读取失败", frame(L(inbox(state="error"), "店铺私信收件箱（示例：读取失败）"))),
        cell("商家侧栏 · 访客（短哈希；邮箱只给脱敏值）", frame(L(merchant_side("order", uid("mc-side"), guest=True), "客户与订单（示例：访客）"))),
        cell("商家侧栏 · 历史订单为空", frame(L(merchant_side("inquiry", uid("mc-side"), orders_state="empty"), "客户与订单（示例：历史订单为空）"))),
        cell("商家侧栏 · 历史订单读取失败", frame(L(merchant_side("inquiry", uid("mc-side"), orders_state="error"), "客户与订单（示例：历史订单读取失败）"))),
        cell("收件箱 · 以后 merchant/threads 补上 unread 后显示未读数", frame(L(inbox("order", nounread=False), "店铺私信收件箱（示例：有 unread）"))),
        cell("询商卡 · 缺 variant_label → 不显示规格行", inquiry_card(nospec=True)),
        cell("挂件头 · reply_hint 为空 → 整行隐藏，只显示店名", frame('<header class="cf-widget__head" data-mc-part="widget-head"><button class="cf-iconbtn" type="button" aria-label="返回">' + ICON["back"] + '</button><div class="cf-widget__who"><p class="cf-widget__name">文派示例店</p></div></header>')),
        cell("事件时间线 · 真正缺值时状态列「—」（正常用系统卡自带的 woo_status）", frame('<div class="cf-side__section">' + timeline([("10-29 21:38", "发订单卡", "order_card", None), ("10-29 21:42", "已付款", "order_paid", None)]) + "</div>")),
    ])


def presales_states():
    caps = [("idle", "待填写"), ("invalid", "校验错误（aria-invalid + 错误说明）"), ("submitting", "提交中"),
            ("error", "提交失败（内容保留，可重试）"), ("success", "成功（回显脱敏邮箱）"), ("bridge", "已登录（session/bridge 免填）")]
    return grid([cell(c, frame(lead_form(s), "cf-preview__frame--thread")) for s, c in caps])


SCRIPT = '''<script>
(function () {
  var html = document.documentElement, stage = document.querySelector(".cf-preview__stage");
  var q = new URLSearchParams(location.search), screen = q.get("screen");
  if (q.get("vp") === "mobile") stage.setAttribute("data-viewport", "mobile");
  if (screen) {
    document.body.setAttribute("data-screen", screen);
    document.querySelectorAll("[data-mc-screen]").forEach(function (s) {
      if (s.getAttribute("data-mc-screen") === screen) s.setAttribute("data-active", "");
    });
  }
  document.querySelectorAll(".cf-thread, .cf-pm__stream").forEach(function (t) { t.scrollTop = t.scrollHeight; });
  document.querySelector('[data-mc-action="theme"]').addEventListener("click", function () {
    html.setAttribute("data-theme", html.getAttribute("data-theme") === "dark" ? "light" : "dark");
  });
  document.querySelector('[data-mc-action="viewport"]').addEventListener("click", function () {
    stage.setAttribute("data-viewport", stage.getAttribute("data-viewport") === "mobile" ? "desktop" : "mobile");
  });
  if (q.get("audit") === "hit") {   // 点击区实测：a / button / summary 的命中区（含 ::after 扩展）
    var cs = getComputedStyle(html), min = parseFloat(cs.getPropertyValue("--cf-hit-min")), touch = parseFloat(cs.getPropertyValue("--cf-hit-touch"));
    var need = q.get("vp") === "mobile" ? touch : min, bad = [], n = 0;
    document.querySelectorAll("[data-active] a, [data-active] button, [data-active] summary").forEach(function (el) {
      var r = el.getBoundingClientRect();
      if (!r.width || !r.height || el.closest(".cf-visually-hidden, [aria-hidden=true]")) return;
      n++;
      var a = getComputedStyle(el, "::after"), ext = 0;
      if (a.position === "absolute" && a.content !== "none") ext = Math.max(0, -parseFloat(a.top) || 0) + Math.max(0, -parseFloat(a.bottom) || 0);
      if (r.height + ext + 0.5 < need || r.width + 0.5 < min) bad.push((el.textContent.trim().slice(0, 6) || el.getAttribute("aria-label")) + "=" + Math.round(r.width) + "x" + Math.round(r.height + ext));
    });
    var out = document.createElement("pre"); out.id = "hit-audit";
    out.textContent = "HIT " + (bad.length ? "FAIL" : "OK") + " need=" + need + " n=" + n + (bad.length ? " " + bad.join(" | ") : "");
    document.body.appendChild(out);
  }
})();
</script>'''


def page():
    secs = [
        ("inquiry", "mobile", "① 咨询商品（data-mc-thread=inquiry）", widget("inquiry")),
        ("aftersales", "mobile", "② 订单售后（data-mc-thread=order；进入售后后 thread_kind 变 aftersale）", widget("order")),
        ("presales", "mobile", "③ 售前留资（data-mc-thread=presales；无商品、无订单）", widget("presales")),
        ("presales-states", "desktop", "③ 留资表单 · 全部状态", presales_states()),
        ("merchant-inquiry", "desktop", "④ 商家三栏 · 询商私信（data-mc-topic=inquiry）", merchant("inquiry")),
        ("merchant-order", "desktop", "④ 商家三栏 · 订单私信（data-mc-topic=order）", merchant("order")),
        ("merchant-aftersale", "desktop", "④ 商家三栏 · 售后私信（data-mc-topic=aftersale）", merchant("aftersale")),
        ("post-qa", "mobile", "帖子 · 问答帖（data-mc-topic=qa）", topic_qa()),
        ("post-product", "mobile", "帖子 · 商品发布帖（data-mc-topic=product；商品卡由 JS 实时渲染）", topic_product()),
        ("post-discussion", "mobile", "帖子 · 普通讨论帖（data-mc-topic=discussion；Discourse 默认，只套 token）", topic_discussion()),
        ("my-orders", "mobile", "子页 · 我的订单", page_my_orders()),
        ("order-detail", "mobile", "子页 · 订单详情", page_order_detail()),
        ("aftersale-page", "mobile", "子页 · 售后", page_aftersale()),
        ("parts", "desktop", "组件与边缘态（一）", parts1()),
        ("parts3", "desktop", "帖子组件：商品卡各状态 / cooked 占位 / 问答未解决", parts3()),
        ("parts2", "desktop", "组件与边缘态（二）：订单行降级 / 收件箱 / 商家侧栏 / 售后进度", parts2()),
    ]
    body = "\n".join(f'''<section class="cf-preview__section" data-mc-screen="{s}" data-mc-vp="{vp}">
    <h2 class="cf-preview__h">{t}</h2>
    <h1 class="cf-sr-only">{t.split("（")[0]}</h1>
    {h}
  </section>''' for s, vp, t, h in secs)
    return f'''<!DOCTYPE html>
<html lang="zh-CN" data-direction="A" data-theme="light">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>方向 A · 货架 IM — Cyberforums 商务界面 round-1</title>
<script>if (new URLSearchParams(location.search).get("theme") === "dark") document.documentElement.setAttribute("data-theme", "dark");</script>
<link rel="stylesheet" href="tokens.css" />
<link rel="stylesheet" href="preview.css" />
<link rel="stylesheet" href="base.css" />
<link rel="stylesheet" href="direction-A.css" />
</head>
<body class="cf-preview">
<header class="cf-preview__bar">
  <div class="cf-preview__intro">
    <p class="cf-preview__kicker"><a class="cf-link" href="index.html">round-1 总览</a> · 方向 A · 第二批</p>
    <h1 class="cf-preview__title">货架 IM</h1>
    <p class="cf-preview__desc">手机淘宝 IM 式：灰底对话、白卡细边、价格做主信息；状态用浅底深字小标签。移动端是全屏会话；商家在 Discourse PM 上用三栏。</p>
  </div>
  <div class="cf-preview__tools">
    <span class="cf-preview__sample">示例数据</span>
    <button class="cf-btn cf-btn--outline" type="button" data-mc-action="theme">切换亮 / 暗</button>
    <button class="cf-btn cf-btn--outline" type="button" data-mc-action="viewport">桌面 / 移动宽度</button>
  </div>
</header>
<main class="cf-preview__stage" data-viewport="desktop">
{body}
</main>
{SCRIPT}
</body>
</html>
'''


# ---------- 论坛帖子版式：data-mc-topic = qa | product | discussion ----------
# 帖子正文（cooked）只用 9 个白名单属性；商品卡由 theme JS 读 products/{id} 实时渲染，插在 cooked 之外（.cf-post__embed）。
from html import escape


def post(name, role, time, cooked, embed="", accepted=False, extra=""):
    r = f'<span class="cf-post__role">{role}</span>' if role else ""
    acc = tag("已采纳", "success", "accepted") if accepted else ""
    emb = f'<div class="cf-post__embed" data-mc-part="embed">{embed}</div>' if embed else ""
    cls = "cf-post cf-post--accepted" if accepted else "cf-post"
    return f'''<li class="{cls}" data-mc-part="post">
  <p class="cf-post__meta"><span class="cf-avatar cf-avatar--sm" aria-hidden="true">{name[0]}</span><span class="cf-post__name">{name}</span>{r}{acc}<time class="cf-post__time">{time}</time></p>
  <div class="cf-post__cooked">{cooked}</div>{emb}
  <p class="cf-post__actions"><button class="cf-textbtn" type="button">回复</button>{extra}</p>
</li>'''


def topic(kind, title, crumb, meta, posts, top=""):
    i = uid("cf-topic-input")
    return f'''<div class="cf-topic" data-mc-surface="topic" data-mc-topic="{kind}">
  <header class="cf-topic__head" data-mc-part="topic-head"><p class="cf-topic__crumb">{crumb}</p><h1 class="cf-topic__title">{title}</h1><p class="cf-topic__meta">{meta}</p></header>
  {top}
  <ol class="cf-topic__posts" data-mc-part="topic-posts">{posts}</ol>
  <form class="cf-topic__reply" data-mc-part="topic-reply" onsubmit="return false"><label class="cf-visually-hidden" for="{i}">回复本帖</label><input id="{i}" class="cf-pm__input" placeholder="回复本帖…" /><button class="cf-btn cf-btn--send" type="submit">回复</button></form>
</div>'''


def topic_qa(solved=True):
    q = "<p>WP 多站点内容同步插件 Pro 在 WordPress 6.6 + PHP 8.3 下同步到子站时提示「REST 请求超时」，有人遇到过吗？</p><p>子站 3 个，商品约 2000 个。</p>"
    a1 = "<p>第一次全量同步 2000 个商品会超时。到「同步设置 › 批量大小」改成 50，再勾选「后台队列」，就不会卡在 REST 超时上。</p>"
    a2 = "<p>我这边也遇到过，改了批量大小后正常了。</p>"
    st = tag("已解决", "success", "qa-state") if solved else tag("待解答", "warning", "qa-state")
    meta = f"{st}<span>3 个回答 · 128 次浏览</span>"
    top = ('''<section class="cf-topic__solved" data-mc-part="solution" aria-label="已采纳的回答">
    <p class="cf-topic__solved-head"><span class="cf-topic__solved-label">已采纳的回答</span><span class="cf-post__name">文派示例店</span><span class="cf-post__role">商家</span></p>
    <p class="cf-topic__solved-body">第一次全量同步 2000 个商品会超时。到「同步设置 › 批量大小」改成 50，再勾选「后台队列」……</p>
    <a class="cf-link" href="#post-2">跳到这条回答</a>
  </section>''' if solved else "")
    pick = "" if solved else '<button class="cf-textbtn cf-textbtn--link" type="button">采纳为答案</button>'
    posts = (post("lin_dev", "提问者", "10-29 20:12", q) + post("文派示例店", "商家", "10-29 20:40", a1, accepted=solved, extra=pick)
             + post("zhou_wp", "", "10-29 21:05", a2))
    return topic("qa", "多站点同步 2000 个商品时 REST 请求超时怎么办？", "文派示例店 › 问答", meta, posts, top)


STOCK = {"instock": ("有货", "success"), "outofstock": ("缺货", "warning"), "onbackorder": ("可预订", "info")}


def product_card(state="ok", stock="instock", nospec=False):
    head = ('<div class="cf-card__head" data-mc-part="head"><span class="cf-card__label" data-mc-part="label">商品</span>'
            '<span class="cf-card__meta" data-mc-part="shop">文派示例店</span></div>')
    if state == "gone":   # products/{id} 返回 404：JS 不替换，cooked 里的占位链接原样保留
        return '<p><a class="cf-link" href="#" data-mc-card="product" data-mc-product="1201" data-mc-state="gone">WP 多站点内容同步插件 Pro</a></p>'
    if state == "loading":
        return f'''<div class="cf-card cf-product-card" data-mc-card="product" data-mc-product="1201" data-mc-state="loading" aria-busy="true">
  {head}
  <div class="cf-card__body" data-mc-part="body"><div class="cf-product-card__main"><span class="cf-thumb cf-thumb--lg cf-skeleton-box" aria-hidden="true"></span><div class="cf-product-card__info">{skel("l")}{skel("s")}{skel("m")}</div></div></div>
  <p class="cf-visually-hidden">商品信息加载中</p>
</div>'''
    if state == "error":
        return f'''<div class="cf-card cf-product-card" data-mc-card="product" data-mc-product="1201" data-mc-state="error">
  {head}
  <div class="cf-card__body" data-mc-part="body"><p class="cf-product-card__title" data-mc-part="title">WP 多站点内容同步插件 Pro</p><p class="cf-card__error" data-mc-part="error">价格和库存暂时读不到（Woo 接口未响应）。</p></div>
  <div class="cf-card__actions" data-mc-part="actions"><a class="cf-link" data-mc-part="action" data-mc-action="view" href="#">打开商品链接</a><button class="cf-textbtn cf-textbtn--link" type="button">重试</button></div>
</div>'''
    label, tone = STOCK[stock]
    stock_html = tag(label, tone, "stock", f' data-mc-stock="{stock}"')
    spec = "" if nospec else '<p class="cf-product-card__spec" data-mc-part="spec">单站授权 · 1 年更新</p>'
    return f'''<div class="cf-card cf-product-card" data-mc-card="product" data-mc-product="1201">
  {head}
  <div class="cf-card__body" data-mc-part="body">
    <div class="cf-product-card__main">{thumb("lg")}<div class="cf-product-card__info">
      <p class="cf-product-card__title" data-mc-part="title">WP 多站点内容同步插件 Pro</p>{spec}
      <p class="cf-product-card__facts"><span class="cf-product-card__price" data-mc-part="price"><span class="cf-inquiry-card__currency">¥</span>199.00</span>{stock_html}</p>
    </div></div>
  </div>
  <div class="cf-card__actions" data-mc-part="actions"><a class="cf-link" data-mc-part="action" data-mc-action="view" href="#">查看商品</a><a class="cf-btn cf-btn--outline" data-mc-part="action" data-mc-action="inquire" href="#">咨询商家</a></div>
</div>'''


def topic_product(state="ok"):
    intro = "<p>3.2 版支持 WooCommerce 9.3，多语言站点映射改成可视化配置。有问题直接在帖子里问。</p>"
    if state == "gone":
        first = post("文派示例店", "商家", "10-28 10:00", intro + product_card("gone"))
    else:
        first = post("文派示例店", "商家", "10-28 10:00", intro, embed=product_card(state))
    posts = (first + post("xiaowang", "", "10-29 21:20", "<p>老授权能免费升级到 3.2 吗？</p>")
             + post("文派示例店", "商家", "10-29 21:33", "<p>授权期内免费升级，到期后续费即可。</p>"))
    meta = '<span>商品发布 · 文派示例店</span><span>2 条回复 · 302 次浏览</span>'
    return topic("product", "WP 多站点内容同步插件 Pro 3.2 发布", "文派示例店 › 商品发布", meta, posts)


def topic_discussion():
    posts = (post("zhou_wp", "", "10-27 14:02", "<p>大家的 Woo 站都用什么缓存方案？我用对象缓存 + 页面缓存，购物车偶尔串号。</p>")
             + post("lin_dev", "", "10-27 15:30", "<p>购物车和结账页要排除页面缓存；带 <code>woocommerce_items_in_cart</code> Cookie 的请求也要绕过。</p>")
             + post("文派示例店", "商家", "10-27 16:10", "<p>补充一句：对象缓存一般没问题，串号多半出在页面缓存。</p>"))
    return topic("discussion", "Woo 站点缓存方案讨论", "综合讨论", "<span>3 条回复 · 56 次浏览</span>", posts)


def parts3():
    src = escape('<p><a href="https://…/product/wp-sync-pro" data-mc-card="product" data-mc-product="1201">WP 多站点内容同步插件 Pro</a></p>')
    return grid([
        cell("商品卡 · 有货（instock）", product_card("ok", "instock")),
        cell("商品卡 · 缺货（outofstock）", product_card("ok", "outofstock")),
        cell("商品卡 · 可预订（onbackorder）", product_card("ok", "onbackorder")),
        cell("商品卡 · 缺 variant_label → 整行隐藏", product_card("ok", "instock", nospec=True)),
        cell("商品卡 · 加载中（骨架）", product_card("loading")),
        cell("商品卡 · 读取失败（保留标题 + 打开链接 + 重试）", product_card("error")),
        cell("商品卡 · 已下架（404）→ 降级为普通链接", frame('<div class="cf-post__cooked cf-preview__pad">' + product_card("gone") + "</div>")),
        cell("cooked 占位：只用 data-mc-card / data-mc-product，JS 读 products/{id} 后在 cooked 之外插卡片", f'<pre class="cf-preview__code">{src}</pre>', wide=True),
        cell("问答帖 · 未解决（无采纳块；提问者可「采纳为答案」）", frame(topic_qa(False)), wide=True),
    ])


if __name__ == "__main__":
    (HERE / "direction-A.html").write_text(page(), encoding="utf-8")
    print("wrote direction-A.html")
