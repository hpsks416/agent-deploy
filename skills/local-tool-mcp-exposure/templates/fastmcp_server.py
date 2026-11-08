"""FastMCP 最小骨架：把本地工具暴露成 MCP server + 自带 skill 资源。

依赖：pip install mcp
启动：python fastmcp_server.py            # MCP 在 http://127.0.0.1:8000/mcp
agent 连接：claude mcp add --transport http <name> http://127.0.0.1:8000/mcp

注意：mcp.run() 的 transport 参数随 mcp SDK 版本略有差异，以安装版本为准
（streamable-http / http / stdio）。
"""
from mcp.server.fastmcp import FastMCP

# 工具名（kebab-case），agent 用这个名字发现你
mcp = FastMCP("my-tool")


# 1) 把工具的操作暴露成 tool：每个操作一个带 typed 参数的函数
@mcp.tool()
def my_action(param_a: str, param_b: int = 1) -> str:
    """一句话说明这个操作做什么、参数含义、返回什么（agent 靠这段 docstring 决定怎么用）。"""
    # TODO: 调用你本地工具的真实逻辑
    return f"done: {param_a} x {param_b}"


# 2) 把「怎么写/怎么用」的 SKILL.md 全文作为 resource 下发给 agent
#    agent 应先 read_resource("tool://skill") 再开始用工具。
def _load_skill() -> str:
    with open("SKILL.md", encoding="utf-8") as f:
        return f.read()


@mcp.resource("tool://skill")
def skill() -> str:
    """工具说明书（写作规则 + 官方示例）。"""
    return _load_skill()


if __name__ == "__main__":
    # transport 按需选：streamable-http（HTTP）/ stdio（本地子进程）
    mcp.run(transport="streamable-http", host="127.0.0.1", port=8000)
