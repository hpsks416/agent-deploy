#!/usr/bin/env python3
"""decrypt-token.py — 恢复一个被 encrypt-token.py 加密的 token（从 AES-256-GCM 备份解回明文）。

用法: python decrypt-token.py <backup.enc> <password> <out.txt>
"""
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
        print("usage: decrypt-token.py <backup.enc> <password> <out.txt>", file=sys.stderr)
        sys.exit(2)
    enc, password, out = sys.argv[1], sys.argv[2], sys.argv[3]
    data = open(enc, "rb").read()
    if data[:4] != MAGIC:
        print("不是 encrypt-token.py 生成的备份（magic 不符）", file=sys.stderr)
        sys.exit(1)
    salt, nonce, ct = data[4:4 + SALT_LEN], data[4 + SALT_LEN:4 + SALT_LEN + NONCE_LEN], data[4 + SALT_LEN + NONCE_LEN:]
    kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt, iterations=ITERATIONS)
    key = kdf.derive(password.encode())
    try:
        pt = AESGCM(key).decrypt(nonce, ct, None)
    except Exception:
        print("密码错误或文件损坏，解密失败", file=sys.stderr)
        sys.exit(1)
    open(out, "wb").write(pt)
    print("recovered ->", out)


if __name__ == "__main__":
    main()
