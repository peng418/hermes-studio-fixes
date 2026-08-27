#!/usr/bin/env python3
"""patch_profile_default.py — Profile 400 兜底补丁（幂等）

扫描 hermes-web-ui dist/client/assets/js 中所有
`localStorage.getItem("hermes_active_profile_name")` 调用，
若其后无 `||"default"` 兜底则补上（修复"模型编辑报 400 Profile is required"）。

安全策略：只处理精确串，且仅在该串后未跟 ||"default" 时补。重复执行幂等。
用法: python3 patch_profile_default.py <hermes-web-ui-dist-client-dir>
"""
import os
import re
import sys

def patch_dir(client_dir: str) -> int:
    js_dir = os.path.join(client_dir, "assets", "js")
    if not os.path.isdir(js_dir):
        print(f"❌ 未找到 {js_dir}")
        return 1

    # 匹配 localStorage.getItem("hermes_active_profile_name") 及引号变体
    pattern = re.compile(
        r'localStorage\.getItem\(\s*["\']hermes_active_profile_name["\']\s*\)'
    )
    fixed_files = 0
    total_fixes = 0

    for fn in sorted(os.listdir(js_dir)):
        if not fn.endswith(".js"):
            continue
        p = os.path.join(js_dir, fn)
        with open(p, encoding="utf-8", errors="replace") as f:
            content = f.read()

        changes = 0
        out = []
        pos = 0
        for m in pattern.finditer(content):
            end = m.end()
            # 该调用后紧跟的字符（跳过空白）
            nxt = content[end:end + 40]
            if nxt.lstrip().startswith('||"default"') or nxt.lstrip().startswith("||'default'"):
                continue  # 已有兜底
            out.append(content[pos:end])
            out.append('||"default"')
            pos = end
            changes += 1
        if changes:
            out.append(content[pos:])
            with open(p, "w", encoding="utf-8") as f:
                f.write("".join(out))
            fixed_files += 1
            total_fixes += changes
            print(f"  ✅ {fn}: 补 {changes} 处 default 兜底")
        else:
            print(f"  ⏭️  {fn}: 无需修复")

    print(f"完成: {fixed_files} 个文件补丁, 共 {total_fixes} 处")
    return 0 if fixed_files >= 0 else 1

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python3 patch_profile_default.py <dist/client 目录>")
        sys.exit(1)
    sys.exit(patch_dir(sys.argv[1]))
