# Service Launcher / Dashboard

A second reusable shape on top of the same thin server: one page that lists several local services, shows live status, and starts/stops them. Distilled from managing a DSH desktop (DSH web, acp-studio, secrets-link, dsh-replay), drawing on the patterns shared by alter-pm / server-services-manager / proceger.

## Services registry (single source of truth)

Drive everything from a `services.json`. Each entry:

```json
{
  "id": "dsh-web",
  "name": "DSH web",
  "group": "core",
  "start": ["cmd", "/c", "launch-dsh.cmd"],
  "stop": ["cmd", "/c", "stop-dsh.cmd"],
  "port": 3080,
  "health": "http://127.0.0.1:3080/",
  "url": "http://127.0.0.1:3080/"
}
```

- `start` / `stop` are the exact subprocess argv. The server shells out; it does not implement start/stop logic itself.
- `health` is an HTTP URL the server GETs to decide "actually up", stronger than "port is listening".
- `url` is the click-to-open link on the card.
- Never hardcode the service list in the server or frontend; both read `services.json`.

## Status probing (decidable, not "I think it started")

A service's status is computed, not guessed:

1. `health` URL returns 200 → `running` (strongest).
2. else port is listening → `running` (up but health unknown).
3. else port/pid absent → `stopped`.
4. start was requested but health never came up → `error` (distinct from `stopped`).

Probe lazily on each `GET /api/services` (or a background tick); do not cache status forever.

## Start/stop control

- Start: spawn the `start` argv. On Windows spawn with `stdio: 'inherit'` (or `'ignore'`) — the default piped stdio fails with EPERM because a sandboxed child cannot open the named pipe. `inherit`/`ignore` work.
- Stop: prefer the `stop` argv when the service ships one; fall back to kill by port (`netstat -ano | findstr :<port>` then taskkill the PID). A pid file is less reliable on Windows than asking the port who owns it.
- Restart: stop → poll until the port is actually free (e.g. 30s) → start. Starting before the port frees fails with "address already in use"; this is the #1 restart bug.

## Endpoints

- `GET /api/services` — registry + live status (probed on demand).
- `POST /api/services/:id/start` / `stop` / `restart` — run the action, then re-probe and return the new status.
- (optional) `GET /api/services/:id/log` — tail the service's log file if it writes one.

## Frontend

One card per service: status light (green/gray/red), name, port, "open" link, start/stop/restart buttons. No build step — plain ES modules. Poll `/api/services` every few seconds so the lights stay honest.

## Windows pitfalls (from the DSH desktop)

- Named-pipe EPERM: spawn children with `stdio: 'inherit'`/`'ignore'`, never the default pipe.
- Port reuse: always wait for the port to free before restarting.
- Port → PID: `netstat -ano | findstr :<port>` is the reliable way to find who owns a port; do not rely on a written pid file.
