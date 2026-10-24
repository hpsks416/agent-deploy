export const name = "dsh-session-sync-flush";

/**
 * 崩溃前一刻日志落盘 —— 关键事件后主动触发 session/flush。
 *
 * DSH 会话日志默认「异步 write-behind + 请求级 flush」：session/event 先进有界 buffer，
 * 窗口到期才 append，且 append 是 best-effort（只有 flush 才 promise crash-survive）。
 * 因此崩溃在「请求进行中」时会丢当前请求未 flush 的 buffer。
 *
 * 本插件把丢失窗口从「整个请求」缩小到「单个事件」：监听关键事件
 * （user/message、assistant/message、tool/call、tool/result），事件落库后立即
 * 调 SessionStore.flush(session)（dispatch session/flush 检查点 → drain + fsync）。
 *
 * session/event 回调签名是 (session, event)，第一个参数即 session。
 * flush 是异步 fire-and-forget（不阻塞生产方），失败只告警不打断会话。
 */
export function apply(ctx, config = {}) {
  const logger = ctx.logger("session-sync-flush");

  const flushTypes = new Set(config.flushTypes ?? [
    "user/message",
    "assistant/message",
    "tool/call",
    "tool/result"
  ]);

  ctx.on("session/event", (session, event) => {
    if (event == null || !flushTypes.has(event.type)) return;
    try {
      const sessions = ctx.get("sessions");
      if (sessions && typeof sessions.flush === "function") {
        sessions.flush(session).catch((e) => {
          logger.warn(`session-sync-flush: flush failed: ${e?.message ?? e}`);
        });
      }
    } catch { /* best-effort: never break the session */ }
  });
}

export default apply;
