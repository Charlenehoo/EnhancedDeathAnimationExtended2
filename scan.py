#!/usr/bin/env python3
"""
从标准输入读取文件路径列表（每行一个），输出文本文件的 Markdown 格式内容。
自动跳过二进制文件（如模型、图片、编译字节码等）。
支持 .scanignore 忽略规则文件（使用 glob 模式，每行一个，支持 # 注释）。
用法示例：
    git ls-files | grep edae | grep -v data | python scan.py
"""

import sys
import fnmatch
from pathlib import Path

# 常见的文本文件扩展名，用于推断代码块语言（可自行扩充）
LANG_MAP = {
    ".lua": "lua",
    ".py": "python",
    ".txt": "text",
    ".md": "markdown",
    ".json": "json",
    ".xml": "xml",
    ".html": "html",
    ".css": "css",
    ".js": "javascript",
    ".ts": "typescript",
    ".yml": "yaml",
    ".yaml": "yaml",
    ".ini": "ini",
    ".cfg": "ini",
    ".sh": "bash",
    ".bat": "batch",
    ".cpp": "cpp",
    ".h": "cpp",
    ".c": "c",
    ".cs": "csharp",
    ".java": "java",
    ".php": "php",
    ".rb": "ruby",
    ".go": "go",
    ".rs": "rust",
    ".sql": "sql",
}


def load_ignore_patterns(ignore_file: Path) -> list:
    """读取 .scanignore 文件，返回忽略模式列表。"""
    if not ignore_file.is_file():
        return []
    patterns = []
    with open(ignore_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            # 跳过空行和注释
            if not line or line.startswith("#"):
                continue
            # 统一使用正斜杠
            patterns.append(line.replace("\\", "/"))
    return patterns


def is_ignored(rel_path: str, patterns: list) -> bool:
    """检查 rel_path 是否匹配任一忽略模式。"""
    rel_path = rel_path.replace("\\", "/")
    for pattern in patterns:
        if fnmatch.fnmatch(rel_path, pattern):
            return True
    return False


def is_text_file(file_path: Path) -> bool:
    """
    通过检查文件开头是否包含空字节（NUL）来判断是否为文本文件。
    二进制文件通常在前几个字节内就包含 NUL。
    """
    try:
        with open(file_path, "rb") as f:
            chunk = f.read(1024)
            if b"\x00" in chunk:
                return False
            try:
                chunk.decode("utf-8")
            except UnicodeDecodeError:
                # 宽松处理：尝试 latin-1 解码，统计可打印字符比例
                text = chunk.decode("latin-1")
                printable = sum(c.isprintable() or c in "\n\r\t" for c in text)
                return printable / len(text) > 0.9 if text else True
            return True
    except Exception:
        return False


def get_language(file_path: Path) -> str:
    """根据扩展名返回代码块语言标识，未知返回空字符串。"""
    ext = file_path.suffix.lower()
    return LANG_MAP.get(ext, "")


def main():
    # 从 stdin 读取所有文件路径（每行一个，已自动去除换行）
    paths = [line.strip() for line in sys.stdin if line.strip()]

    if not paths:
        print("No input paths provided.", file=sys.stderr)
        sys.exit(1)

    base_dir = Path.cwd()
    # 加载 .scanignore
    ignore_file = base_dir / ".scanignore"
    ignore_patterns = load_ignore_patterns(ignore_file)
    if ignore_patterns:
        print(
            f"Loaded {len(ignore_patterns)} ignore pattern(s) from .scanignore",
            file=sys.stderr,
        )

    print(
        f"Scanning {len(paths)} files (text only, applying ignore rules)...\n",
        file=sys.stderr,
    )

    for rel_path in paths:
        rel_path = rel_path.replace("\\", "/")
        file_path = base_dir / rel_path

        # 忽略检查
        if is_ignored(rel_path, ignore_patterns):
            print(f"Ignored: {rel_path}", file=sys.stderr)
            continue

        if not file_path.is_file():
            print(f"Skipping missing file: {rel_path}", file=sys.stderr)
            continue

        if not is_text_file(file_path):
            print(f"Skipping binary file: {rel_path}", file=sys.stderr)
            continue

        # 输出 Markdown 标题
        print(f"# ./{rel_path}")
        lang = get_language(file_path)
        print(f"```{lang}")

        try:
            with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()
                print(content.rstrip("\n"))
        except Exception as e:
            print(f"ERROR: Failed to read file - {str(e)}", file=sys.stderr)

        print("```\n")


if __name__ == "__main__":
    main()
