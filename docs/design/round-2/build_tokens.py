#!/usr/bin/env python3
"""tokens.json -> tokens.css (亮色 :root + [data-theme="dark"])，并输出 WCAG 对比度自检。

用法：python3 build_tokens.py            # 生成 tokens.css 并打印 AA 报告
      python3 build_tokens.py --check    # 只检查，不写文件；AA 不过则退出码 1
只用标准库。命名规则：--cf-<group>-<name>，颜色为 --cf-color-<name>。
"""
import json, re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
T = json.loads((HERE / "tokens.json").read_text(encoding="utf-8"))
P = T["meta"]["prefix"]

def var(group, name):
    return f"--{P}-{group}-{name}"

def lum(hexv):
    h = hexv.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    rgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]

def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)

def build():
    out = ["/* 生成物，勿手改，源为 docs/design/round-1/tokens.json，归 cf-design（由 build_tokens.py 生成）。 */", ":root {"]
    for k, v in T["color"]["light"].items():
        out.append(f"  {var('color', k)}: {v};")
    for group in ("font", "font-size", "line-height", "letter-spacing", "space", "radius",
                  "border-width", "shadow", "size", "motion", "z", "hit"):
        for k, v in T[group].items():
            out.append(f"  {var(group, k)}: {v};")
    out.append("  color-scheme: light;")
    out.append("}")
    out.append("")
    out.append('[data-theme="dark"] {')
    for k, v in T["color"]["dark"].items():
        out.append(f"  {var('color', k)}: {v};")
    out.append("  color-scheme: dark;")
    out.append("}")
    out.append("")
    return "\n".join(out)

def check():
    ok = True
    lines = []
    for theme in ("light", "dark"):
        c = T["color"][theme]
        for fg, bg in T["contrastChecks"]:
            r = ratio(c[fg], c[bg])
            flag = "AA" if r >= 4.5 else "FAIL"
            ok &= r >= 4.5
            lines.append(f"{theme:5} {fg:20} on {bg:18} {r:5.2f}  {flag}")
    for theme in ("light", "dark"):
        c = T["color"][theme]
        for fg, bg in T.get("nonTextChecks", []):
            r = ratio(c[fg], c[bg])
            flag = "3:1" if r >= 3 else "FAIL"
            ok &= r >= 3
            lines.append(f"{theme:5} [非文字] {fg:15} on {bg:18} {r:5.2f}  {flag}")
    for theme, pairs in T.get("surfaceChecks", {}).items():
        c = T["color"][theme]
        for fg, bg in pairs:
            r = ratio(c[fg], c[bg])
            ok &= r >= 1.25
            lines.append(f"{theme:5} [卡面] {fg:15} on {bg:18} {r:5.2f}  {'1.25' if r >= 1.25 else 'FAIL'}")
    return ok, lines

if __name__ == "__main__":
    ok, lines = check()
    print("\n".join(lines))
    print("AA 全部通过" if ok else "存在 AA 不通过项")
    if "--check" not in sys.argv:
        css = build()
        (HERE / "tokens.css").write_text(css, encoding="utf-8")
        # 插件内副本：与 docs 里的 tokens.css 字节一致；注册（plugin.rb）归 cf-frontend
        plug = HERE.parents[2] / "assets" / "stylesheets" / "common" / "cf-tokens.css"
        plug.parent.mkdir(parents=True, exist_ok=True)
        plug.write_text(css, encoding="utf-8")
        print("wrote tokens.css + " + str(plug.relative_to(HERE.parents[2])))
    sys.exit(0 if ok else 1)
