#!/usr/bin/env python3
# 补漏改名：处理 rename_app.py 未覆盖的路径（upgrade_init /vol1 硬编码、sed 模式、scripts 默认 PKGHOME）
import os

ROOT = "/vol6/@apphome/hermes-studio/hermes-home/workspace/hermes-studio-2-fpk"

REPLACEMENTS = [
    # cmd/upgrade_init 硬编码 /vol1 路径（新实例装 vol2，兜底路径也要改对）
    (b"/vol1/@appcenter/hermes-studio", b"/vol1/@appcenter/hermes-studio-2", ["cmd/upgrade_init"]),
    (b"/vol1/@apphome/hermes-studio", b"/vol1/@apphome/hermes-studio-2", ["cmd/upgrade_init"]),
    (b"/vol1/@appdata/hermes-studio", b"/vol1/@appdata/hermes-studio-2", ["cmd/upgrade_init"]),
    # cmd/install_callback 的 fix_main_script sed 模式：目标是修复安装版 cmd/main 的路径，
    # 新应用的安装版路径是 hermes-studio-2
    (b"s|/vol[0-9]+/@appcenter/hermes-studio|", b"s|/vol[0-9]+/@appcenter/hermes-studio-2|", ["cmd/install_callback"]),
    (b"s|/vol[0-9]+/@apphome/hermes-studio|", b"s|/vol[0-9]+/@apphome/hermes-studio-2|", ["cmd/install_callback"]),
    (b"s|/vol[0-9]+/@appdata/hermes-studio|", b"s|/vol[0-9]+/@appdata/hermes-studio-2|", ["cmd/install_callback"]),
    # scripts 默认 PKGHOME：新实例在 vol2
    (b"/vol6/@apphome/hermes-studio", b"/vol2/@apphome/hermes-studio-2", ["scripts/check_upgrade_env.sh", "scripts/recover_upgrade_env.sh", "scripts/recover_ipv6_bind.sh"]),
    # recover_ipv6_bind.sh 注释里的验证端口（8648→8649 已在 rename 处理，这里补 PKGHOME 相关）
    (b"hermes-studio", b"hermes-studio-2", ["scripts/recover_ipv6_bind.sh"]),
    (b"hermes-studio", b"hermes-studio-2", ["scripts/check_upgrade_env.sh"]),
    (b"hermes-studio", b"hermes-studio-2", ["scripts/recover_upgrade_env.sh"]),
]

def matches(full, rules):
    for r in rules:
        if full.endswith("/" + r):
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
            changed.append(full.replace(ROOT, "."))

print(f"补漏修改 {len(changed)} 个文件:")
for c in changed:
    print("  ", c)
