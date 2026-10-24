export const name = "dsh-retrieval-guard";

/**
 * 铁律一（先检索）的事前硬门控 —— 轮次级强制。
 *
 * 挂在 `tools/pre-execute` 瀑布最前（prepend），拦截两类「大概率造轮子」的动作：
 *   1. write/edit 到代码/脚本/skill 文件（.py/.js/.ts/.sh/.ps1/.../SKILL.md/AGENTS.md）
 *   2. bash/pwsh 里跑「装依赖/拉新东西」的命令（npm install / pip install / git clone / npx create / cargo new / pnpm create）
 *
 * 判定依据：**每轮**（最近一次 user/message 之后）是否已调过检索工具（web_search / open-source-scout）。
 * 不是「会话里检索过一次就永久放行」，而是「每一轮都要先检索」——上一轮搜过不代表这一轮能跳过。
 * 这是 harness 层的硬门控，不靠模型自觉。
 */
export function apply(ctx, config = {}) {
  const logger = ctx.logger("retrieval-guard");

  // 算作「检索」的工具：本轮内调用它们 = 满足「先检索」
  const retrievalTools = new Set(config.retrievalTools ?? ["web_search", "open-source-scout"]);

  // 「代码/脚本」扩展名：写这些才需要「先检索」（写 .md 笔记不拦）
  const codeExtensions = new Set([
    ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx",
    ".py", ".sh", ".bash", ".ps1", ".psm1",
    ".go", ".rs", ".java", ".c", ".cpp", ".h", ".hpp",
    ".rb", ".php", ".lua", ".sql", ".r", ".swift", ".kt"
  ]);

  // 从 exec.arguments 提取目标文件路径
  const targetPath = (exec) => {
    const a = exec?.arguments;
    if (a == null) return "";
    return String(a.file_path ?? a.path ?? a.file ?? a.target ?? "");
  };

  // 判断 write/edit 是否在写「代码/脚本/skill」
  const isCodeWrite = (exec) => {
    const p = targetPath(exec).toLowerCase();
    if (p === "") return false;
    if (p.endsWith("skill.md") || p.endsWith("agents.md") || p.endsWith("persona.md")) return true;
    for (const ext of codeExtensions) if (p.endsWith(ext)) return true;
    return false;
  };

  // 判断「本轮」是否已检索：从后往前扫事件，遇到「本轮的用户消息」就停；
  // 停之前若见过检索工具调用 = 本轮已检索。
  const hasRetrievedThisTurn = (agent) => {
    if (agent == null || agent.session == null) return true; // 无会话信息时不拦，避免误伤
    try {
      const events = agent.session.snapshotEvents();
      for (let seq = events.length - 1; seq >= 0; seq--) {
        const event = events[seq];
        if (event == null) continue;
        // 本轮起点 = 最近一次 user/message（source.kind === "user"）。走到这里说明本轮内还没检索。
        if (event.type === "user/message" && event.data?.source?.kind === "user") {
          return false;
        }
        if (event.type === "tool/call") {
          const toolName = event.data?.name;
          if (toolName != null && retrievalTools.has(toolName)) {
            return true; // 本轮内检索过
          }
        }
      }
      return false;
    } catch (e) {
      logger.warn(`retrieval-guard: hasRetrievedThisTurn failed: ${e?.message ?? e}`);
      return true;
    }
  };

  // bash/pwsh 里「装依赖/拉新东西」的命令模式
  const INSTALL_PATTERN = /npm\s+(install|i)\b|pip\s+install|pipx\s+install|git\s+clone|cargo\s+new|cargo\s+install|pnpm\s+create|pnpm\s+add\b|npx\s+create|yarn\s+add\b|go\s+install\b|brew\s+install|dnf\s+install|apt(-get)?\s+install/;

  ctx.on("tools/pre-execute", async (exec, next) => {
    const tool = exec?.name;

    // 融合 dsh-guardian：先查通用安全（危险命令/明文密钥/SSRF/提示注入），命中就弹框强制触发。
    // dsh-guardian 未安装或调用失败时静默跳过，不影响我们的业务门控。
    try {
      const g = ctx.bail("guardian/check", tool, exec?.arguments);
      if (g && g.intercepted) {
        logger.info(`retrieval-guard: dsh-guardian ${g.action} intercepted ${tool}: ${g.reason}`);
        return {
          kind: "ask",
          reason: `🛡️ dsh-guardian 安全护栏拦截（${g.action}）：${g.reason}。是否继续？【允许】= 继续（已知风险）；【拒绝】= 中止该动作。`
        };
      }
    } catch { /* dsh-guardian 未安装/失败，跳过 */ }

    // 检索工具本身：放行（它的调用会进会话事件，供 hasRetrievedThisTurn 查）
    if (retrievalTools.has(tool)) return next();

    // 写文件：只在「写代码/脚本/skill」时拦截
    if (tool === "write" || tool === "edit") {
      if (isCodeWrite(exec)) {
        if (!hasRetrievedThisTurn(exec.agent)) {
          logger.info(`retrieval-guard: deny ${tool} ${targetPath(exec)} — no retrieval this turn`);
          return {
            kind: "ask",
            reason: `⚠️ 本轮未检索。是否直接写（跳过检索）？【允许】= 直接写，跳过检索；【拒绝】= 先检索（web_search/open-source-scout）再写。目标：${targetPath(exec)}`
          };
        }
      }
    }

    // bash/pwsh：拦「装依赖/拉新东西」命令
    if (tool === "bash" || tool === "pwsh") {
      const text = String(exec?.arguments?.command ?? exec?.arguments?.cmd ?? exec?.arguments?.script ?? "");
      if (INSTALL_PATTERN.test(text)) {
        if (!hasRetrievedThisTurn(exec.agent)) {
          logger.info(`retrieval-guard: deny ${tool} — install/clone without retrieval this turn`);
          return {
            kind: "ask",
            reason: "⚠️ 本轮未检索。是否直接装（跳过检索）？【允许】= 直接装，跳过检索；【拒绝】= 先检索（web_search/open-source-scout）再装。"
          };
        }
      }
    }

    return next();
  }, { prepend: true });

  // 第 3 层：检测「文字询问用户决策，但没用 ask_user_question 弹窗」+「提示重启但没附日志路径」
  const ASK_PATTERN = /你认可吗|是否同意|要不要|选哪个|你定|认可吗|同意吗|怎么处理|怎么做|继续吗|需要我|要哪个|选一下/;
  const RESTART_PATTERN = /重启|重新启动|dsh\s+web|重启\s*DSH/;
  const LOG_PATH_PATTERN = /startup-\*\.log|session_projcache|session\.v3\.jsonl\.zstd|\.dsh[\\/]logs|\.dsh[\\/]storages/;
  const extractText = (data) => {
    if (data == null) return "";
    const content = data.content ?? data.message?.content ?? data.text;
    if (Array.isArray(content)) {
      return content.map((b) => (typeof b === 'string' ? b : (b?.text ?? ''))).join('\n');
    }
    return typeof content === 'string' ? content : '';
  };
  ctx.on("session/event", (event) => {
    try {
      if (event == null) return;

      // 检测 1：assistant/message 文字询问未弹窗 + 重启未附日志
      if (event.type === "assistant/message") {
        const text = extractText(event.data);
        if (text && ASK_PATTERN.test(text)) {
          logger.warn(`retrieval-guard: text-ask detected but no ask_user_question — "${String(text).slice(0, 100).replace(/\n/g, ' ')}"`);
        }
        if (text && RESTART_PATTERN.test(text) && !LOG_PATH_PATTERN.test(text)) {
          logger.warn(`retrieval-guard: restart hinted but no log path given — "${String(text).slice(0, 100).replace(/\n/g, ' ')}"`);
        }
      }

      // 检测 2（新增）：tool/call 直接读 G:\KEY token 明文（任何场景都强制安全调用，非 push 也 warn）
      if (event.type === "tool/call") {
        const d = event.data;
        if (d?.name === "pwsh" || d?.name === "bash") {
          let args = d?.arguments;
          if (typeof args === "string") { try { args = JSON.parse(args); } catch { args = null; } }
          const cmd = String(args?.command ?? args?.cmd ?? args?.script ?? "");
          if (/G:\\KEY/i.test(cmd) && /(Get-Content|cat\b|type\b)/i.test(cmd)) {
            logger.warn(`retrieval-guard: token read detected (non-plugin) — direct Get-Content G:\KEY: "${cmd.slice(0, 100).replace(/\n/g, ' ')}"`);
          }
        }
        if (d?.name === "read") {
          let args = d?.arguments;
          if (typeof args === "string") { try { args = JSON.parse(args); } catch { args = null; } }
          const fp = String(args?.file_path ?? "");
          if (/G:\\KEY/i.test(fp)) {
            logger.warn(`retrieval-guard: token read detected (non-plugin) — read G:\KEY file: ${fp}`);
          }
        }
      }
    } catch { /* detection is best-effort; never break the session */ }
  });
}

export default apply;
