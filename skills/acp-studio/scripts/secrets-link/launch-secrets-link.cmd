@echo off
rem Launch the secrets-link panel (zero-dependency local web UI).
rem Run this OUTSIDE the DSH agent sandbox (normal cmd / PowerShell) so it can write secrets scripts.
node "%~dp0secrets-link-web.mjs"
