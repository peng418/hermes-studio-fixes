#!/usr/bin/env python3
# 修复 rename_app2.py 造成的 hermes-studio-2 双重替换
import os

ROOT = "/vol6/@apphome/hermes-studio/hermes-home/workspace/hermes-studio-2-fpk"

fixed = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    for fn in filenames:
        full = os.path.join(dirpath, fn)
        try:
            with open(full, "rb") as f:
                data = f.read()
        except Exception:
            continue
        orig = data
        data = data.replace(b"hermes-studio-2", b"hermes-studio-2")
        data = data.replace(b"/vol2/@apphome/hermes-studio-2", b"/vol2/@apphome/hermes-studio-2")
        if data != orig:
            with open(full, "wb") as f:
                f.write(data)
            fixed.append(full.replace(ROOT, "."))

print(f"修复 {len(fixed)} 个文件:")
for c in fixed:
    print("  ", c)
