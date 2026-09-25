#!/usr/bin/env python3
"""导入用户画像：从来源文件导入 persona.md（备份旧的 + 校验六维）。"""
import os
import sys
import shutil
from datetime import datetime

sys.stdout.reconfigure(encoding='utf-8')

PERSONA = os.path.expanduser('~/.dsh/persona.md')
SIX_DIMS = ['人格 / 身份', '思维习惯', '决策偏好', '纠错模式', '语言风格', '环境约定']


def main():
    if len(sys.argv) < 2:
        print('用法: python persona_import.py <来源文件>')
        sys.exit(1)
    src = sys.argv[1]
    if not os.path.isfile(src):
        print(f'来源文件不存在: {src}')
        sys.exit(1)
    text = open(src, encoding='utf-8').read()
    missing = [d for d in SIX_DIMS if d not in text]
    if missing:
        print(f'警告: 来源缺少维度 {", ".join(missing)}（仍导入，建议补全）')
    if os.path.exists(PERSONA):
        ts = datetime.now().strftime('%Y%m%d-%H%M%S')
        bak = f'{PERSONA}.bak-{ts}'
        shutil.copy2(PERSONA, bak)
        print(f'已备份旧画像 -> {bak}')
    with open(PERSONA, 'w', encoding='utf-8') as f:
        f.write(text)
    print(f'已导入 -> {PERSONA}')


if __name__ == '__main__':
    main()
