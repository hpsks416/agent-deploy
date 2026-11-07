# findings 结构化 schema

每个 finding 一条，字段：

| 字段 | 说明 |
|---|---|
| id | 唯一编号 |
| severity | critical / major / minor（严重度需影响：critical=可利用造成实际损害，major=明确缺陷，minor=加固建议） |
| location | 文件:行 + 符号 |
| attack_surface | 属于哪个攻击面（输入 / 依赖 / 权限 / 敏感数据） |
| finding | 现象（可判定的事实） |
| impact | 影响（能被谁利用、造成什么） |
| evidence | 证据（代码路径 / 复现步骤） |
| recommendation | 修法 |

## 覆盖账本（coverage ledger）

| 攻击面 | 已查 | 结论 |
|---|---|---|
| ... | 是/否 | 安全 / 有 finding / gap（未查） |

**gap 必须诚实标注**：没查到的面写「未查」，不假装全覆盖（与「证据先于完成」同源）。
