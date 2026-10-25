#!/usr/bin/env python3
"""encrypt-token.py — 加密一个 token 文件（zip 备份 + age 密文）。

流程：
  1) 明文先压成「密码 zip」备份到同目录 `<file>.backup.zip`（解压要密码）；
  2) 原文件内容改成 age 密文（公钥从 identity 文件的 "# public key: age1..." 行解析）。

用法: python encrypt-token.py <token_file> <age_bin> <identity> <zip_password>
"""
import os
import re
import sys
import zipfile
import subprocess


def main():
    if len(sys.argv) != 5:
        print("usage: encrypt-token.py <token_file> <age_bin> <identity> <zip_password>", file=sys.stderr)
        sys.exit(2)
    file, age_bin, identity, password = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

    idt = open(identity, encoding="utf-8", errors="replace").read()
    m = re.search(r"age1[a-z0-9]+", idt)
    if not m:
        print("identity 文件里没找到 public key（age1...）", file=sys.stderr)
        sys.exit(1)
    pubkey = m.group(0)

    # 1) 密码 zip 备份（同目录）
    zp = file + ".backup.zip"
    with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.setpassword(password.encode())
        zf.write(file, os.path.basename(file))

    # 2) age 加密原文件（temp -> replace）
    tmp = file + ".age.tmp"
    subprocess.run([age_bin, "-e", "-r", pubkey, "-o", tmp, file], check=True)
    os.replace(tmp, file)
    print("encrypted:", os.path.basename(file))


if __name__ == "__main__":
    main()
