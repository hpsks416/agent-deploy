#!/usr/bin/env python3
"""decrypt-token.py — 恢复 encrypt-token.py 加密的 token（密码 = 私钥）。

用法: python decrypt-token.py <backup.enc> <identity> <out.txt>
"""
import re
import sys

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

MAGIC = b"ENC1"
SALT_LEN = 16
NONCE_LEN = 12
ITERATIONS = 600_000


def main():
    if len(sys.argv) != 4:
        print("usage: decrypt-token.py <backup.enc> <identity> <out.txt>", file=sys.stderr)
        sys.exit(2)
    enc, identity, out = sys.argv[1], sys.argv[2], sys.argv[3]

    idt = open(identity, encoding="utf-8", errors="replace").read()
    s = re.search(r"AGE-SECRET-KEY-1[A-Za-z0-9]+", idt)
    if not s:
        print("identity 文件里没找到私钥", file=sys.stderr)
        sys.exit(1)
    secret = s.group(0)

    data = open(enc, "rb").read()
    if data[:4] != MAGIC:
        print("不是 encrypt-token.py 生成的备份（magic 不符）", file=sys.stderr)
        sys.exit(1)
    salt = data[4:4 + SALT_LEN]
    nonce = data[4 + SALT_LEN:4 + SALT_LEN + NONCE_LEN]
    ct = data[4 + SALT_LEN + NONCE_LEN:]
    kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt, iterations=ITERATIONS)
    key = kdf.derive(secret.encode())
    try:
        pt = AESGCM(key).decrypt(nonce, ct, None)
    except Exception:
        print("解密失败（私钥不匹配或文件损坏）", file=sys.stderr)
        sys.exit(1)
    open(out, "wb").write(pt)
    print("recovered ->", out)


if __name__ == "__main__":
    main()
