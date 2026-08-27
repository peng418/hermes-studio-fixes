#!/usr/bin/env python3
# 改壳：hermes-studio → hermes-studio-2（字节级替换，保持 CRLF/LF 行尾）
import os, sys

ROOT = "/vol6/@apphome/hermes-studio/hermes-home/workspace/hermes-studio-2-fpk"

# 精确替换表（bytes）：(old, new, 适用文件)
REPLACEMENTS = [
    # manifest
    (b"appname               = hermes-studio", b"appname               = hermes-studio-2", ["manifest"]),
    (b"desktop_applaunchname = hermes-studio.Application", b"desktop_applaunchname = hermes-studio-2.Application", ["manifest"]),
    # ui/config
    (b'"hermes-studio.Application"', b'"hermes-studio-2.Application"', ["app/ui/config"]),
    # cmd 路径与端口（全部 cmd/*）
    (b"/var/apps/hermes-studio", b"/var/apps/hermes-studio-2", ["cmd"]),
    (b"/tmp/hermes-studio-", b"/tmp/hermes-studio-2-", ["cmd"]),
    (b"8648", b"8649", ["cmd"]),
    (b"${TRIM_USERNAME:-hermes-studio}", b"${TRIM_USERNAME:-hermes-studio-2}", ["cmd"]),
    # app/bin 启动器
    (b"/vol${v}/@apphome/hermes-studio", b"/vol${v}/@apphome/hermes-studio-2", ["app/bin"]),
    (b"/vol1/@apphome/hermes-studio", b"/vol1/@apphome/hermes-studio-2", ["app/bin"]),
    # config/privilege + resource（应用用户隔离，关键！）
    (b'"username": "hermes-studio"', b'"username": "hermes-studio-2"', ["config/privilege"]),
    (b'"groupname": "hermes-studio"', b'"groupname": "hermes-studio-2"', ["config/privilege"]),
    (b'"name": "hermes-studio"', b'"name": "hermes-studio-2"', ["config/resource"]),
    # scripts/build-fpk.sh
    (b'APPNAME="hermes-studio"', b'APPNAME="hermes-studio-2"', ["scripts/build-fpk.sh"]),
    # scripts/recover_ipv6_bind.sh 验证端口
    (b"8648", b"8649", ["scripts/recover_ipv6_bind.sh"]),
    # scripts/hermes_monitor.py 路径与端口
    (b"/vol3/@appdata/hermes-studio", b"/vol3/@appdata/hermes-studio-2", ["scripts/hermes_monitor.py"]),
    (b"/vol3/@appcenter/hermes-studio", b"/vol3/@appcenter/hermes-studio-2", ["scripts/hermes_monitor.py"]),
    (b"/var/apps/hermes-studio", b"/var/apps/hermes-studio-2", ["scripts/hermes_monitor.py"]),
    (b"8648", b"8649", ["scripts/hermes_monitor.py"]),
]

def matches(path, rules):
    for r in rules:
        if r == "cmd" and "/cmd/" in path:
            return True
        if r == "manifest" and path.endswith("/manifest"):
            return True
        if r == "app/ui/config" and path.endswith("/app/ui/config"):
            return True
        if r == "app/bin" and path.endswith("/app/bin/hermes-web-ui"):
            return True
        if r == "config/privilege" and path.endswith("/config/privilege"):
            return True
        if r == "config/resource" and path.endswith("/config/resource"):
            return True
        if r == "scripts/build-fpk.sh" and path.endswith("/scripts/build-fpk.sh"):
            return True
        if r == "scripts/recover_ipv6_bind.sh" and path.endswith("/scripts/recover_ipv6_bind.sh"):
            return True
        if r == "scripts/hermes_monitor.py" and path.endswith("/scripts/hermes_monitor.py"):
            return True
    return False

changed = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    for fn in filenames:
        full = os.path.join(dirpath, fn)
        try:
            with open(full, "rb") as f:
                data = f.read()
        except Exception:
            continue
        orig = data
        for old, new, rules in REPLACEMENTS:
            if matches(full, rules) and old in data:
                data = data.replace(old, new)
        if data != orig:
            with open(full, "wb") as f:
                f.write(data)
            changed.append(full)

print(f"修改了 {len(changed)} 个文件:")
for c in changed:
    print("  ", c.replace(ROOT, "."))
