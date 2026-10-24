---
name: doc-to-markdown
description: 把 read 工具读不了的二进制文档（Word .doc/.docx、PDF、PPT、Excel）转成 Markdown 文本供直接读取。Use when 遇到 read 报 "binary file" 的文档，或用户要求「把文档转成 md/能读的格式」。
---

# 文档转 Markdown

把 read 工具读不了的二进制文档转成可读 `.md`。三层手段，按优先级递减：

## 1. 本机 Word COM（.doc/.docx，零依赖，首选）

```powershell
$src = '<文档绝对路径>'
$dst = '<输出.md，放 workspace 可写目录>'
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
$doc = $word.Documents.Open($src, $false, $true)   # ReadOnly
$text = $doc.Content.Text
$doc.Close($false)
$word.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
[System.IO.File]::WriteAllText($dst, $text, [System.Text.Encoding]::UTF8)
```

注意：
- .doc 提取的是纯文本，Word 段落标记是 `\r`/`\v`/`\f`/`\x0b`/`\x0c`，用 `-replace "`r","`n" -replace "`v","`n" -replace "`f","`n" -replace [char]11,"`n" -replace [char]12,"`n"` 归一化后再 `read`。
- 输出必须写到 workspace（可写），不要写只读的 attachment 目录。
- 只提纯文本；图片/表格结构会丢失，如需保留结构改用 MarkItDown。

## 2. MarkItDown（微软官方，支持 docx/pdf/pptx/xlsx/html）

```powershell
python -m markitdown <文件> -o <输出.md>
# 或 Python API：
#   from markitdown import MarkItDown
#   MarkItDown().convert('<文件>').text_content
```

本机已装 0.1.9（user site-packages，含 mammoth/pdfminer.six/python-pptx/openpyxl/beautifulsoup4/magika/markdownify）。**注意：不支持 `.doc` 老格式（OLE2）**——`.doc` 走 Word COM，`.docx`/`.pdf`/`.pptx`/`.xlsx`/`.html` 走 MarkItDown，两者互补。

## 3. 判格式（文件头 8 字节）

```powershell
[System.IO.File]::ReadAllBytes($p)[0..7] | ForEach-Object { $_.ToString('X2') }
```

- `.doc` = OLE2 复合文档（`D0 CF 11 E0 A1 B1 1A E1`）
- `.docx` = ZIP（`50 4B 03 04`）

## 边界

- 转出的 .md 只读；要改先复制到可写位置。
- COM 不可用 / 无 Word 时如实报告，不硬造内容。
