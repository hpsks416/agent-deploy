export const name = "dsh-context-guard";

/**
 * 上下文窗口硬保底 —— 接近窗口上限时强制拦截，防止「爆窗报错」才被发现。
 *
 * 信号：harness 的 sessionProjections 已精确追踪 contextPressure：
 *   { surfaceTokens, contextWindow, pressureTokens, sampledSurfaceTokens }
 * 读法：ctx.sessionProjections.snapshot(session, ["contextPressure"]).values.contextPressure
 *
 * 三档阈值（pressureTokens / contextWindow）：
 *   warnAt (0.70) → 只打日志提醒，不拦（不烦人）
 *   askAt  (0.85) → tools/pre-execute 拦截 + 弹框 ask（人工放行/收口）
 *   denyAt (0.95) → 拦截 + 强措辞 ask（即将爆窗）
 *
 * 挂在 tools/pre-execute 瀑布最前（prepend），是 harness 层强制，不靠模型自觉。
 */
export function apply(ctx, config = {}) {
  const logger = ctx.logger("context-guard");
  const warnAt = config.warnAt ?? 0.70;
  const askAt = config.askAt ?? 0.85;
  const denyAt = config.denyAt ?? 0.95;

  const readPressure = (agent) => {
    if (agent == null || agent.session == null) return null;
    try {
      const sp = ctx.sessionProjections ?? ctx.get?.("sessionProjections");
      const v = sp?.snapshot(agent.session, ["contextPressure"])?.values?.contextPressure;
      if (v && typeof v.contextWindow === "number" && v.contextWindow > 0 && typeof v.pressureTokens === "number") {
        return { ratio: v.pressureTokens / v.contextWindow, window: v.contextWindow, used: v.pressureTokens };
      }
    } catch (e) {
      logger.warn(`context-guard: readPressure failed: ${e?.message ?? e}`);
    }
    return null;
  };

  ctx.on("tools/pre-execute", async (exec, next) => {
    const p = readPressure(exec?.agent);
    if (p == null) return next();
    const pct = Math.round(p.ratio * 100);
    const tool = exec?.name ?? "";

    if (p.ratio >= denyAt) {
      logger.warn(`context-guard: DENY ${tool} at ${pct}% (${p.used}/${p.window})`);
      return {
        kind: "ask",
        reason: `🚨 上下文占用 ${pct}%（${p.used}/${p.window} tokens），即将爆窗。强烈建议立即收口交接（写 HANDOFF + 开新对话）。是否继续 ${tool}？【允许】= 继续（已知风险）；【拒绝】= 先收口。`
      };
    }
    if (p.ratio >= askAt) {
      logger.warn(`context-guard: ASK ${tool} at ${pct}% (${p.used}/${p.window})`);
      return {
        kind: "ask",
        reason: `⚠️ 上下文占用 ${pct}%（${p.used}/${p.window} tokens），接近窗口上限。建议收口交接。是否继续 ${tool}？【允许】= 继续；【拒绝】= 先收口。`
      };
    }
    if (p.ratio >= warnAt) {
      logger.warn(`context-guard: warn at ${pct}% (${p.used}/${p.window})`);
    }
    return next();
  }, { prepend: true });
}

export default apply;
