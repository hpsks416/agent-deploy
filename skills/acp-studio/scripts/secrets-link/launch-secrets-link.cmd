@echo off
rem Launch the secrets-link panel (zero-dependency local web UI).
rem Run this OUTSIDE the DSH agent sandbox (normal cmd / PowerShell) so it can write secrets.cmd.
node "G:\CodexDS\DSH\INTRO\secrets-link\secrets-link-web.mjs"
