#!/usr/bin/env python3
# cmd/ 定向改名 + 统一 LF（cmd/ 已从 hs-fixes 重置，需重做改名）
import os

CMD = "/vol6/@apphome/hermes-studio/hermes-home/workspace/hermes-studio-2-fpk/cmd"

# (old, new) 字节级替换；先 CRLF→LF 再替换
REPL = [
    (b"/var/apps/hermes-studio", b"/var/apps/hermes-studio-2"),
    (b"/tmp/hermes-studio-", b"/tmp/hermes-studio-2-"),
    (b"8648", b"8649"),
    (b"${TRIM_USERNAME:-hermes-studio}", b"${TRIM_USERNAME:-hermes-studio-2}"),
    (b"/vol1/@appcenter/hermes-studio", b"/vol1/@appcenter/hermes-studio-2"),
    (b"/vol1/@apphome/hermes-studio", b"/vol1/@apphome/hermes-studio-2"),
    (b"/vol1/@appdata/hermes-studio", b"/vol1/@appdata/hermes-studio-2"),
    (b"s|/vol[0-9]+/@appcenter/hermes-studio|", b"s|/vol[0-9]+/@appcenter/hermes-studio-2|"),
    (b"s|/vol[0-9]+/@apphome/hermes-studio|", b"s|/vol[0-9]+/@apphome/hermes-studio-2|"),
    (b"s|/vol[0-9]+/@appdata/hermes-studio|", b"s|/vol[0-9]+/@appdata/hermes-studio-2|"),
    # install_callback 里 fix_main_script 的 expected_bin 路径（hermes-web-ui 产品名保留）
]

for fn in sorted(os.listdir(CMD)):
    p = os.path.join(CMD, fn)
    if not os.path.isfile(p):
        continue
    with open(p, "rb") as f:
        data = f.read()
    orig = data
    data = data.replace(b"\r\n", b"\n")  # 统一 LF
    for old, new in REPL:
        data = data.replace(old, new)
    if data != orig:
        with open(p, "wb") as f:
            f.write(data)
        print(f"updated: {fn}")

print("\n=== 验证 ===")
for fn in sorted(os.listdir(CMD)):
    p = os.path.join(CMD, fn)
    if not os.path.isfile(p):
        continue
    with open(p, "rb") as f:
        d = f.read()
    leftover = [w for w in (b"hermes-studio", b"8648") if w in d]
    # 允许 hermes-studio-mcp / hermes-studio-version.env / hermes-studio-fixes 引用
    bad = []
    if b"hermes-studio" in d:
        # 找出不含 -2 的 hermes-studio 引用
        import re
        for m in re.finditer(rb"hermes-studio(?!-2|-mcp|-version|-fixes)", d):
            ctx = d[max(0, m.start()-20):m.end()+10]
            bad.append(ctx)
    if b"8648" in d:
        bad.append(b"8648!!")
    status = "OK" if not bad else f"LEFTOVER: {bad[:3]}"
    print(f"  {fn}: {status}")
