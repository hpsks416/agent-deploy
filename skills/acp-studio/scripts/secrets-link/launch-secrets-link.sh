#!/bin/sh
# Launch the secrets-link panel (zero-dependency local web UI).
# Run this OUTSIDE the DSH agent sandbox (normal terminal) so it can write secrets scripts.
DIR="$(cd "$(dirname "$0")" && pwd)"
exec node "$DIR/secrets-link-web.mjs"
