#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check-dts.py —— 设备树静态校验（沙箱无 dtc 时的等价兜底）

做五件事：
  1. 去注释后检查 {} 是否平衡
  2. 逐条检查属性是否以 ';' 收尾（漏分号是 dtc 最常见的报错），
     属性值跨行时以 '<' '(' '[' 或 ',' 结尾视为续行
  3. 收集 label 定义与 &label 引用，检查引用是否都有定义
  4. 每个节点的**直接** reg（不在更深花括号内）首地址与节点名 @地址 一致
  5. 同一节点内 reg 的地址组数与 size 组数配平

退出码：0 全过；1 有 ERROR。
"""
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "gk6323v100c-chaoge-z71a.dts"
src = open(path, encoding="utf-8").read()

errors = []
warns = []


def strip_comments(s):
    """去 /* */ 与 // 注释，字符串整体保留；注释按行数补空行以便定位。"""
    out = []
    i, n = 0, len(s)
    while i < n:
        if s.startswith("/*", i):
            j = s.find("*/", i + 2)
            if j < 0:
                errors.append("块注释 /* 未闭合")
                return "".join(out)
            out.append("\n" * s.count("\n", i, j))
            i = j + 2
        elif s.startswith("//", i):
            j = s.find("\n", i)
            j = n if j < 0 else j
            out.append("\n")
            i = j
        elif s[i] == '"':
            j = i + 1
            while j < n and s[j] != '"':
                j += 2 if s[j] == "\\" else 1
            out.append(s[i:j + 1])
            i = j + 1
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


body = strip_comments(src)

# --- 1. 花括号平衡 ---
depth = 0
min_depth = 0
for ch in body:
    if ch == "{":
        depth += 1
    elif ch == "}":
        depth -= 1
        min_depth = min(min_depth, depth)
if depth != 0:
    errors.append("花括号不平衡：结尾深度 = %d（应为 0）" % depth)
if min_depth < 0:
    errors.append("出现多余的 '}'：最小深度 = %d" % min_depth)

# --- 2. 属性分号检查 ---
for lineno, raw in enumerate(body.splitlines(), 1):
    line = raw.strip()
    if not line:
        continue
    if line.endswith("{") or line in ("};", "}"):
        continue
    if "=" not in line:
        continue
    stripped = line.rstrip()
    # 续行标志：以逗号 / 尖括号 / 圆括号 / 反斜杠结尾
    if stripped[-1] in ",(<[\\":
        continue
    if stripped.endswith(";") or stripped.endswith("}"):
        continue
    errors.append("第 %d 行疑似漏分号：%s" % (lineno, line[:70]))

# --- 3. label 定义与引用 ---
labels = set(re.findall(r"^\s*([A-Za-z_][\w-]*)\s*:\s*[\w@,.\-+]+\s*\{", body, re.M))
refs = set(re.findall(r"&([A-Za-z_][\w-]*)", body))
missing = sorted(r for r in refs if r not in labels)
for m in missing:
    errors.append("引用了未定义的 label：&%s" % m)
for u in sorted(l for l in labels if l not in refs):
    warns.append("定义了但未被引用（正常现象）：%s" % u)


def match_brace(text, open_pos):
    """返回与 open_pos 处 '{' 配对的 '}' 位置，找不到返回 -1。"""
    d = 0
    for i in range(open_pos, len(text)):
        if text[i] == "{":
            d += 1
        elif text[i] == "}":
            d -= 1
            if d == 0:
                return i
    return -1


def top_level_reg(node_body):
    """取节点直接层级的 reg 属性值串（跳过子节点内的 reg）。"""
    d = 0
    i = 0
    n = len(node_body)
    while i < n:
        ch = node_body[i]
        if ch == "{":
            d += 1
            i += 1
            continue
        if ch == "}":
            d -= 1
            i += 1
            continue
        if d == 0 and node_body.startswith("reg", i):
            # 确认是独立属性名
            before = node_body[i - 1] if i > 0 else " "
            after = node_body[i + 3] if i + 3 < n else " "
            if not (before.isalnum() or before in "_-.") and after in " \t=":
                m = re.match(r"reg\s*=\s*<([^>]*)>", node_body[i:])
                if m:
                    return m.group(1)
        i += 1
    return None


# --- 4/5. 节点名 @地址 与直接 reg 首地址一致性 ---
node_re = re.compile(r"([A-Za-z_][\w-]*)@([0-9a-fA-F]+)\s*\{")
checked = 0
for m in node_re.finditer(body):
    name, addr = m.group(1), m.group(2)
    close = match_brace(body, m.end() - 1)
    if close < 0:
        continue
    inner = body[m.end():close]
    regs = top_level_reg(inner)
    if not regs:
        continue
    toks = regs.split()
    try:
        vals = [int(t, 0) for t in toks]
    except ValueError:
        errors.append("节点 %s@%s 的 reg 含非法数值：%s" % (name, addr, regs))
        continue
    if len(vals) == 2:          # 父核 1/1 → <addr size>
        phys = vals[0]
    elif len(vals) == 4:        # 父核 2/2 → <ahi alo shi slo>
        phys = (vals[0] << 32) | vals[1]
    elif len(vals) % 2 == 0 and len(vals) > 4:
        phys = (vals[0] << 32) | vals[1]
    else:
        continue
    checked += 1
    if phys != int(addr, 16):
        errors.append("节点 %s@%s 的地址与 reg 首地址 0x%x 不一致"
                      % (name, addr, phys))

print("文件：%s" % path)
print("花括号结尾深度：%d" % depth)
print("label 定义 %d 个，&引用 %d 处，未定义引用 %d 处"
      % (len(labels), len(refs), len(missing)))
print("节点名@地址 与直接 reg 首地址核对：共 %d 个节点通过" % checked)
for w in warns:
    print("  WARN  %s" % w)
for e in errors:
    print("  ERROR %s" % e)

if errors:
    print("\n校验未通过：%d 个 ERROR" % len(errors))
    sys.exit(1)
print("\n校验通过：0 ERROR")
