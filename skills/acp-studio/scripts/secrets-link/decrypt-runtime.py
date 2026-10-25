#!/usr/bin/env python3
"""decrypt-runtime.py — 运行时解密 token.zip（zip 密码=公钥 → age 密文 → age 私钥解密 → 明文）。

供 secrets.cmd 的 for /f 与面板预览使用。
用法: python decrypt-runtime.py <token.zip> <age_bin> <identity>
输出: 明文到 stdout。
"""
import os
import re
import sys
import zipfile
import subprocess


def main():
    if len(sys.argv) != 4:
        print("usage: decrypt-runtime.py <token.zip> <age_bin> <identity>", file=sys.stderr)
        sys.exit(2)
    file, age_bin, identity = sys.argv[1], sys.argv[2], sys.argv[3]

    idt = open(identity, encoding="utf-8", errors="replace").read()
    m = re.search(r"age1[a-z0-9]+", idt)
    if not m:
        print("identity 文件里没找到 public key", file=sys.stderr)
        sys.exit(1)
    pubkey = m.group(0)

    with zipfile.ZipFile(file) as zf:
        zf.setpassword(pubkey.encode())
        name = zf.namelist()[0]
        age_ct = zf.read(name)

    tmp = file + ".ct"
    open(tmp, "wb").write(age_ct)
    out = subprocess.run([age_bin, "-d", "-i", identity, tmp], capture_output=True)
    os.remove(tmp)
    sys.stdout.write(out.stdout.decode("utf-8", "replace"))


if __name__ == "__main__":
    main()
