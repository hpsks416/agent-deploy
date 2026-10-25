#!/usr/bin/env python3
"""encrypt-token.py — 加密 token：AES 备份 + age 密文 → 打包成 zip（公钥做 zip 密码）。

流程（防误操作：最终产物是 .zip，面板只认 zip）：
  1) 明文 AES-256-GCM 备份 <file>.backup.enc（密码 = 私钥）；
  2) 明文 age 加密成密文；
  3) 密文打包成 zip <file>.zip（zip 密码 = 公钥，作为「已加密」的格式标记）；
  4) 删原明文文件。

依赖：cryptography + age 二进制。无需 pip。
用法: python encrypt-token.py <token_file> <age_bin> <identity>
"""
import os
import re
import sys
import zipfile
import subprocess

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

MAGIC = b"ENC1"
SALT_LEN = 16
NONCE_LEN = 12
ITERATIONS = 600_000


def _derive_key(password: bytes, salt: bytes) -> bytes:
    kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt, iterations=ITERATIONS)
    return kdf.derive(password)


def aes_backup(file: str, secret: str) -> str:
    pt = open(file, "rb").read()
    salt = os.urandom(SALT_LEN)
    nonce = os.urandom(NONCE_LEN)
    key = _derive_key(secret.encode(), salt)
    ct = AESGCM(key).encrypt(nonce, pt, None)
    out = file + ".backup.enc"
    with open(out, "wb") as f:
        f.write(MAGIC + salt + nonce + ct)
    return out


def main():
    if len(sys.argv) != 4:
        print("usage: encrypt-token.py <token_file> <age_bin> <identity>", file=sys.stderr)
        sys.exit(2)
    file, age_bin, identity = sys.argv[1], sys.argv[2], sys.argv[3]

    idt = open(identity, encoding="utf-8", errors="replace").read()
    m = re.search(r"age1[a-z0-9]+", idt)
    s = re.search(r"AGE-SECRET-KEY-1[A-Za-z0-9]+", idt)
    if not m or not s:
        print("identity 文件里没找到 public key / 私钥", file=sys.stderr)
        sys.exit(1)
    pubkey = m.group(0)
    secret = s.group(0)

    backup = aes_backup(file, secret)  # 1) AES 备份

    age_ct = file + ".age.tmp"          # 2) age 加密
    subprocess.run([age_bin, "-e", "-r", pubkey, "-o", age_ct, file], check=True)

    zp = file + ".zip"                  # 3) 密文打包 zip（密码 = 公钥）
    with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.setpassword(pubkey.encode())
        zf.write(age_ct, os.path.basename(file))
    os.remove(age_ct)

    os.remove(file)                     # 4) 删原明文
    print("encrypted:", os.path.basename(file), "->", os.path.basename(zp), "+", os.path.basename(backup))


if __name__ == "__main__":
    main()
