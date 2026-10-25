#!/usr/bin/env python3
"""encrypt-token.py — 加密一个 token 文件（AES-256-GCM 备份 + age 密文）。

流程（精简：私钥即备份密码）：
  1) 明文先 AES-256-GCM 加密备份到同目录 <file>.backup.enc（密码 = 私钥 AGE-SECRET-KEY 行）；
  2) 原文件内容改成 age 密文（公钥从 identity 解析）。

依赖：cryptography + age 二进制。无需 pip。
用法: python encrypt-token.py <token_file> <age_bin> <identity>
"""
import os
import re
import sys
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


def aes_encrypt_backup(file: str, secret: str) -> str:
    plaintext = open(file, "rb").read()
    salt = os.urandom(SALT_LEN)
    nonce = os.urandom(NONCE_LEN)
    key = _derive_key(secret.encode(), salt)
    ct = AESGCM(key).encrypt(nonce, plaintext, None)
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

    backup = aes_encrypt_backup(file, secret)  # 密码 = 私钥
    tmp = file + ".age.tmp"
    subprocess.run([age_bin, "-e", "-r", pubkey, "-o", tmp, file], check=True)
    os.replace(tmp, file)
    print("encrypted:", os.path.basename(file), "-> backup", os.path.basename(backup))


if __name__ == "__main__":
    main()
