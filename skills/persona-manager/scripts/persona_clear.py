#!/usr/bin/env python3
"""清空用户画像：备份当前 persona.md → 重置为空白六维模板。"""
import os
import sys
import shutil
from datetime import datetime

sys.stdout.reconfigure(encoding='utf-8')

PERSONA = os.path.expanduser('~/.dsh/persona.md')

TEMPLATE = """# 用户画像（Persona）

本文件记录用户的人格与思维习惯，由铁律二的「收尾提取」机制持续积累。会话开始时先读本文件，让工作对齐用户。

## 人格 / 身份

-

## 思维习惯

-

## 决策偏好

-

## 纠错模式

-

## 语言风格

-

## 环境约定

-
"""


def main():
    if os.path.exists(PERSONA):
        ts = datetime.now().strftime('%Y%m%d-%H%M%S')
        bak = f'{PERSONA}.bak-{ts}'
        shutil.copy2(PERSONA, bak)
        print(f'已备份 -> {bak}')
    else:
        print(f'未找到 {PERSONA}，将新建空白画像')
    with open(PERSONA, 'w', encoding='utf-8') as f:
        f.write(TEMPLATE)
    print(f'已重置为空白画像 -> {PERSONA}')


if __name__ == '__main__':
    main()
