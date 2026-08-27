#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""hermes-studio-2 dist/client 正确前缀注入（修复 recover_subpath.sh 引号 bug）
用法: sudo python3 fix_subpath.py <DIST_CLIENT_DIR>
幂等: 已带前缀的调用跳过。
"""
import os, sys

DIST = sys.argv[1] if len(sys.argv) > 1 else "/vol2/@apphome/hermes-studio-2/data/node/lib/node_modules/hermes-web-ui/dist/client"
PREFIX = "/app/hermes-studio-2"

def patch_file(p, olds):
    """正确加前缀：old 含前导引号，前缀插在引号与路径之间（old[0]+PREFIX+old[1:]）"""
    changed = 0
    with open(p, encoding="utf-8", errors="replace") as f:
        c = f.read()
    o = c
    for old in olds:
        if old in c and (old[0] + PREFIX + old[1:]) not in c:
            c = c.replace(old, old[0] + PREFIX + old[1:])
    if c != o:
        with open(p, "w", encoding="utf-8") as f:
            f.write(c)
        changed = 1
        print(f"  patched {os.path.basename(p)}")
    return changed

total = 0
# 1) index.html 静态资源引用
idx = os.path.join(DIST, "index.html")
if os.path.exists(idx):
    total += patch_file(idx, [
        '"/assets/', '"/favicon.ico', '"/logo.png', '"/manifest.webmanifest',
        '"/icons/', '"/fonts/', '"/coding-agents/', '"/notification-sw.js',
    ])

# 2) assets/js 下所有 JS（双引号 + 模板字符串两种形态 + plugins/engine.io）
js_dir = os.path.join(DIST, "assets", "js")
if os.path.isdir(js_dir):
    for fn in sorted(os.listdir(js_dir)):
        if fn.endswith(".js"):
            total += patch_file(os.path.join(js_dir, fn), [
                '"/api', '`/api', '"/plugins/', '`/plugins/', '"/engine.io', '`/engine.io',
            ])

# 3) 其他子目录 js（coding-agents 等）
for sub in ("coding-agents", "icons"):
    d = os.path.join(DIST, sub)
    if os.path.isdir(d):
        for root, _dirs, files in os.walk(d):
            for fn in files:
                if fn.endswith(".js"):
                    total += patch_file(os.path.join(root, fn), [
                        '"/api', '`/api', '"/plugins/', '`/plugins/',
                    ])

print(f"done: {total} files patched with prefix {PREFIX}")
