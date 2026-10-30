#!/bin/sh
# round-1 自检（第二批）：组件 CSS 不得出现硬编码颜色 / px / 非 token 字号 / 结构选择器 / 渐变 / 毛玻璃 / 上浮；
# HTML 无内联样式、无旧钩子前缀；表单 label、honeypot、钩子取值、id 唯一、每屏 h1、nav/aside 标签；token AA 对比度、暗色卡面 ≥1.25、最小字号；点击区实测。
cd "$(dirname "$0")"
CSS="base.css direction-A.css preview.css"
HTML="direction-A.html index.html"
fail=0
echo "== 1 硬编码颜色 (#hex / rgb / hsl)"; grep -nE '#[0-9a-fA-F]{3,8}\b|rgba?\(|hsla?\(' $CSS && fail=1
echo "== 2 px 字面量"; grep -nE '[0-9.]+px' $CSS && fail=1
echo "== 3 字号必须引用 token"; grep -nE 'font-size:[[:space:]]*[^v[:space:]]' $CSS && fail=1
echo "== 4 结构选择器 (nth-child / first-child / last-child / 子代组合符)"; grep -nE 'nth-child|nth-of-type|first-child|last-child|only-child|[^-]>[[:space:]]*[a-z.\[]' $CSS && fail=1
echo "== 5 渐变 / 毛玻璃 / 上浮"; grep -nE 'gradient|backdrop-filter|blur\(|translateY' $CSS && fail=1
echo "== 6 阴影（只允许 focus 环）"; grep -nE 'box-shadow' $CSS | grep -v 'shadow-focus' && fail=1
echo "== 7 HTML 内联样式 / nth-child"; grep -nE 'style=|nth-child' $HTML && fail=1
echo "== 8 旧钩子前缀 data-cf-（应为 data-mc-）"; grep -nE 'data-cf-' $CSS $HTML build_previews.py && fail=1
echo "== 9 表单 label / honeypot / 钩子取值 / id 唯一 / 每屏 h1 / nav·aside 标签"
python3 - <<'PY' || fail=1
import sys
from html.parser import HTMLParser
class P(HTMLParser):
    def __init__(s):
        super().__init__()
        s.depth = 0; s.fors = set(); s.inputs = []; s.hp = []; s.ids = []
        s.vals = {"thread": set(), "topic": set(), "card": set(), "event": set()}
        s.cur = None; s.sd = 0; s.sec = {}; s.nolabel = []; s.lm = 0
    def handle_starttag(s, tag, attrs):
        a = dict(attrs)
        if tag == "section":
            if a.get("data-mc-screen"):
                s.cur, s.sd = a["data-mc-screen"], 0; s.sec[s.cur] = {"h1": 0, "lm": []}
            elif s.cur: s.sd += 1
        if s.cur and tag == "h1": s.sec[s.cur]["h1"] += 1
        if tag in ("nav", "aside"):
            s.lm += 1
            if not a.get("aria-label"): s.nolabel.append(s.getpos()[0])
            if s.cur: s.sec[s.cur]["lm"].append(a.get("aria-label"))
        if a.get("id"): s.ids.append(a["id"])
        if tag == "label":
            s.depth += 1
            if a.get("for"): s.fors.add(a["for"])
        if tag in ("input", "textarea", "select") and a.get("type") != "hidden":
            s.inputs.append((a.get("id"), s.depth > 0, a.get("aria-label"), s.getpos()[0]))
        if "cf-lead-form__hp" in (a.get("class") or ""):
            s.hp.append(a.get("aria-hidden") == "true")
        for k in s.vals:
            v = a.get("data-mc-" + k)
            if v: s.vals[k].add(v)
    def handle_endtag(s, tag):
        if tag == "label": s.depth -= 1
        if tag == "section" and s.cur:
            if s.sd == 0: s.cur = None
            else: s.sd -= 1
p = P(); p.feed(open("direction-A.html", encoding="utf-8").read())
bad = [i for i in p.inputs if not (i[1] or i[0] in p.fors or i[2])]
dup = sorted({x for x in p.ids if p.ids.count(x) > 1})
ok_t = p.vals["thread"] <= {"inquiry", "order", "aftersale", "presales"}
ok_p = p.vals["topic"] <= {"inquiry", "order", "aftersale", "qa", "product", "discussion"}
ok_e = p.vals["event"] <= {"inquire", "product_ctx", "order_card", "order_paid", "status_changed"}
print(f"输入控件 {len(p.inputs)} 个，缺 label {len(bad)}；honeypot {len(p.hp)} 处，全部 aria-hidden={all(p.hp)}；重复 id {len(dup)}")
for k in p.vals: print(f"data-mc-{k} =", " ".join(sorted(p.vals[k])))
noh1 = [k for k, v in p.sec.items() if v["h1"] < 1]
duplm = {k: sorted({x for x in v["lm"] if v["lm"].count(x) > 1}) for k, v in p.sec.items()}
duplm = {k: v for k, v in duplm.items() if v}
print(f"页面（截图屏）{len(p.sec)} 个，缺 h1 {len(noh1)}；nav/aside {p.lm} 个，缺 aria-label {len(p.nolabel)}，同屏重名 {sum(len(v) for v in duplm.values())}")
for k in noh1: print("  缺 h1：", k)
for k, v in duplm.items(): print("  landmark 重名：", k, v)
for i in bad: print("  缺 label：行", i[3], i[0])
for d in dup: print("  重复 id：", d)
sys.exit(0 if not bad and p.hp and all(p.hp) and not dup and ok_t and ok_p and ok_e and not noh1 and not p.nolabel and not duplm else 1)
PY
echo "== 10 WCAG 对比度 + 最小字号"
python3 - <<'PY' || fail=1
import sys
import build_tokens as b
ok, lines = b.check()
for th in ("light", "dark"):
    c = b.T["color"][th]
    t = min((b.ratio(c[f], c[g]), f, g) for f, g in b.T["contrastChecks"])
    n = min((b.ratio(c[f], c[g]), f, g) for f, g in b.T["nonTextChecks"])
    print(f"{th}: 文字 {len(b.T['contrastChecks'])} 对，最低 {t[0]:.2f}（{t[1]} on {t[2]}）；非文字 {len(b.T['nonTextChecks'])} 对，最低 {n[0]:.2f}（{n[1]} on {n[2]}）")
fs = min(float(v.rstrip("px")) for v in b.T["font-size"].values())
print(f"最小字号 {fs:g}px；" + ("AA 全部通过" if ok else "存在 AA 不通过项"))
sys.exit(0 if ok and fs >= 12 else 1)
PY
echo "== 11 点击区（token 引用 + Chrome 实测：桌面 ≥ --cf-hit-min，手机 ≥ --cf-hit-touch）"
grep -q 'var(--cf-hit-min)' base.css && grep -q 'var(--cf-hit-touch)' base.css || { echo "  base.css 未引用 --cf-hit-min / --cf-hit-touch"; fail=1; }
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ -x "$CH" ]; then
  for u in inquiry aftersales presales my-orders order-detail aftersale-page post-qa post-product post-discussion; do for v in "&vp=mobile" ""; do
    r=$("$CH" --headless=new --disable-gpu --window-size=1440,900 --virtual-time-budget=1500 --dump-dom "file://$PWD/direction-A.html?screen=$u$v&audit=hit" 2>/dev/null | grep -oE 'HIT (OK|FAIL) need=[^<]*')
    echo "  $u$v: ${r:-无结果}"; case "$r" in "HIT OK"*) ;; *) fail=1;; esac
  done; done
  for u in merchant-inquiry merchant-order merchant-aftersale presales-states parts parts2 parts3; do
    r=$("$CH" --headless=new --disable-gpu --window-size=1440,900 --virtual-time-budget=1500 --dump-dom "file://$PWD/direction-A.html?screen=$u&audit=hit" 2>/dev/null | grep -oE 'HIT (OK|FAIL) need=[^<]*')
    echo "  $u: ${r:-无结果}"; case "$r" in "HIT OK"*) ;; *) fail=1;; esac
  done
else echo "  跳过实测：未找到 Chrome"; fi
echo "== 12 帖子正文（cooked）只用 9 个白名单属性：card/part/state/status/tone/event/order/product/action"
python3 - <<'PY' || fail=1
from html.parser import HTMLParser
import sys
WL = {f"data-mc-{k}" for k in "card part state status tone event order product action".split()}
VOID = {"input", "img", "br", "hr", "meta", "link", "source", "path", "circle", "rect", "line", "polyline"}
class P(HTMLParser):
    def __init__(s): super().__init__(); s.st = []; s.bad = []; s.n = 0
    def handle_starttag(s, t, a):
        a = dict(a); inside = bool(s.st and s.st[-1])
        root = a.get("data-mc-card") in ("inquiry", "order") or "data-mc-event" in a or "cf-post__cooked" in (a.get("class") or "").split()
        if inside or root:
            s.n += 1
            s.bad += [(t, k, s.getpos()[0]) for k in a if k.startswith("data-mc-") and k not in WL]
        if t not in VOID: s.st.append(inside or root)
    def handle_startendtag(s, t, a):
        s.handle_starttag(t, a)
        if t not in VOID: s.st.pop()
    def handle_endtag(s, t):
        if t not in VOID and s.st: s.st.pop()
p = P(); p.feed(open("direction-A.html", encoding="utf-8").read())
print(f"cooked 元素 {p.n} 个，非白名单属性 {len(p.bad)} 处")
for b in p.bad[:20]: print("  ", b)
sys.exit(1 if p.bad else 0)
PY
echo "== 13 不出现任何在线状态（在线 / 离线 / 绿点）"; grep -nE '在线|离线|cf-widget__online' direction-A.html && fail=1
echo "== 14 卡片 / 正文元素不用 article、header、footer（语义靠 data-mc-card / data-mc-part）"
python3 - <<'PY' || fail=1
from html.parser import HTMLParser
import sys
VOID = {"input", "img", "br", "hr", "meta", "link", "source", "path", "circle", "rect", "line", "polyline"}
class P(HTMLParser):
    def __init__(s): super().__init__(); s.st = []; s.n = 0; s.bad = []
    def handle_starttag(s, t, a):
        a = dict(a); inside = bool(s.st and s.st[-1])
        root = "data-mc-card" in a or "data-mc-event" in a or "cf-post__cooked" in (a.get("class") or "").split()
        if inside or root:
            s.n += 1
            if t in ("article", "header", "footer"): s.bad.append((t, s.getpos()[0]))
        if t not in VOID: s.st.append(inside or root)
    def handle_startendtag(s, t, a):
        s.handle_starttag(t, a)
        if t not in VOID: s.st.pop()
    def handle_endtag(s, t):
        if t not in VOID and s.st: s.st.pop()
p = P(); p.feed(open("direction-A.html", encoding="utf-8").read())
print(f"卡片 / 正文元素 {p.n} 个，article/header/footer {len(p.bad)} 个")
for b in p.bad[:10]: print("  ", b)
sys.exit(1 if p.bad else 0)
PY
echo "== 15 界面可见文本不含开发说明（接口名、字段名、缓存、数据来源等；不含 parts 展示页与预览标注）"
python3 - <<'PY' || fail=1
from html.parser import HTMLParser
import re, sys
SKIP = {"parts", "parts2", "parts3", "presales-states"}
PAT = re.compile(r"vendor-orders|merchant/threads|products/\{|admin_url|view_url|woo_status|thread_kind|reply_hint|variant_label|stock_status|data-mc-|分钟缓存|缓存）|数据来自 Woo|以 Woo 为准|系统行|明文|契约|字段|接口")
VOID = {"input", "img", "br", "hr", "meta", "link", "source", "path", "circle", "rect", "line", "polyline"}
class P(HTMLParser):
    def __init__(s): super().__init__(); s.st = []; s.hits = []
    def handle_starttag(s, t, a):
        a = dict(a); c = (a.get("class") or "").split()
        sec = a.get("data-mc-screen") if "cf-preview__section" in c else None
        par = s.st[-1] if s.st else (None, False)
        hid = par[1] or t in ("script", "style", "code") or a.get("aria-hidden") == "true" or "cf-preview__h" in c or "cf-preview__bar" in c
        if t not in VOID: s.st.append((sec or par[0], hid))
    def handle_startendtag(s, t, a):
        s.handle_starttag(t, a)
        if t not in VOID: s.st.pop()
    def handle_endtag(s, t):
        if t not in VOID and s.st: s.st.pop()
    def handle_data(s, d):
        if s.st and s.st[-1][0] and s.st[-1][0] not in SKIP and not s.st[-1][1] and PAT.search(d): s.hits.append((s.st[-1][0], d.strip()[:60]))
p = P(); p.feed(open("direction-A.html", encoding="utf-8").read())
print(f"开发说明 {len(p.hits)} 处")
for h in p.hits[:20]: print("  ", h)
sys.exit(1 if p.hits else 0)
PY
echo "== 16 插件 assets/stylesheets/common/cf-tokens.css 与 tokens.css 字节一致"
if cmp -s tokens.css ../../../assets/stylesheets/common/cf-tokens.css; then echo "  一致"; else echo "  不一致或缺文件"; fail=1; fi
[ $fail = 0 ] && echo "自检通过" || echo "自检有问题"
exit $fail
