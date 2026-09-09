#!/usr/bin/env python3
"""
从标准输入读取文件路径列表（每行一个），输出文本文件的 Markdown 格式内容。
自动跳过二进制文件（如模型、图片、编译字节码等）。
支持 .scanignore 忽略规则文件：
    - 首行作为 Jinja2 模板，渲染后插入到每个输出文件的开头。
    - 后续行作为 glob 忽略模式（每行一个，支持 # 注释）。

可选参数：
    n   如果提供，则将结果按照文件行数尽量平均地分成 n 个输出文件（不会截断文件）。
        如果不提供，则所有结果写入单个文件 scan_output.md。

输出文件位于当前工作目录（pwd）：
    - 单文件模式：scan_output.md
    - 分片模式：scan_output_part1.md, scan_output_part2.md, ...

用法示例：
    git ls-files | grep edae | grep -v data | python scan.py
    git ls-files | grep edae | grep -v data | python scan.py 3
"""

import sys
import argparse
import fnmatch
from pathlib import Path
import heapq
from datetime import datetime

try:
    from jinja2 import Template
except ImportError:
    Template = None  # 可选依赖，缺失时跳过模板渲染

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


def load_ignore_patterns(ignore_file: Path):
    """
    读取 .scanignore 文件，返回 (template_str, patterns)。
    - template_str: 文件首行（去除换行），作为 Jinja2 模板；若文件不存在或首行为空则返回 None。
    - patterns: 后续行的忽略模式列表（忽略空行和 # 注释）。
    """
    if not ignore_file.is_file():
        return None, []

    with open(ignore_file, "r", encoding="utf-8") as f:
        lines = f.readlines()

    template_str = None
    patterns = []
    if lines:
        # 首行作为模板（即使以 # 开头也视为模板）
        template_str = lines[0].rstrip("\n")
        if template_str.strip() == "":
            template_str = None  # 首行为空则不视为模板

        # 后续行作为忽略模式
        for line in lines[1:]:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            patterns.append(line.replace("\\", "/"))

    return template_str, patterns


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


def get_line_count(file_path: Path) -> int:
    """快速统计文本文件的行数（用于权重计算），失败返回 0。"""
    try:
        with open(file_path, "r", encoding="utf-8", errors="replace") as f:
            return sum(1 for _ in f)
    except Exception:
        return 0


def split_files_by_weight(file_paths: list, num_parts: int) -> list:
    """
    将文件列表按照行数权重尽量平均地分成 num_parts 组。
    使用贪心桶分配：先按权重降序排序，依次放入当前总权重最小的桶。
    最后对每个桶内的文件按原始顺序排序（保持相对顺序）。
    返回列表的列表，每个子列表包含 Path 对象。
    """
    if num_parts <= 0:
        raise ValueError("num_parts must be positive")
    if num_parts >= len(file_paths):
        # 若桶数不少于文件数，则每个文件单独一组
        return [[fp] for fp in file_paths]

    # 计算每个文件的行数，并记录原始索引
    items = []
    for idx, fp in enumerate(file_paths):
        weight = get_line_count(fp)
        items.append((weight, idx, fp))

    # 按权重降序排序（大文件优先分配）
    items.sort(key=lambda x: x[0], reverse=True)

    # 初始化桶，每个桶用 (当前总权重, 桶索引, 文件列表)
    buckets = [(0, i, []) for i in range(num_parts)]
    heapq.heapify(buckets)  # 最小堆，按总权重排序

    for weight, idx, fp in items:
        # 弹出当前权重最小的桶
        curr_weight, bucket_idx, file_list = heapq.heappop(buckets)
        file_list.append((idx, fp))  # 存储原始索引以便最后排序
        curr_weight += weight
        heapq.heappush(buckets, (curr_weight, bucket_idx, file_list))

    # 收集所有桶并排序（按桶索引）
    final_buckets = sorted(buckets, key=lambda x: x[1])
    result = []
    for _, _, file_list in final_buckets:
        # 对桶内文件按原始索引排序，恢复输入顺序
        file_list.sort(key=lambda x: x[0])
        result.append([fp for _, fp in file_list])
    return result


def render_header(template_str: str, context: dict) -> str:
    """
    使用 Jinja2 渲染模板。若模板为空或渲染失败，返回空字符串。
    """
    if not template_str:
        return ""
    if Template is None:
        print(
            "Warning: jinja2 not installed, skipping header rendering.", file=sys.stderr
        )
        return ""
    try:
        template = Template(template_str)
        return template.render(**context)
    except Exception as e:
        print(f"Warning: failed to render header template: {e}", file=sys.stderr)
        return ""


def write_markdown_for_files(file_paths: list, out_file: Path, header_text: str = ""):
    """
    将给定文件列表的 Markdown 内容写入 out_file。
    如果 header_text 非空，则先写入头部，再空一行。
    file_paths 为 Path 对象列表（已过滤为有效文本文件）。
    """
    with open(out_file, "w", encoding="utf-8") as out:
        if header_text:
            out.write(header_text)
            out.write("\n\n")  # 头部后空一行

        for file_path in file_paths:
            # 计算相对路径（相对于当前工作目录）
            rel_path = file_path.relative_to(Path.cwd()).as_posix()
            # 输出 Markdown 标题
            print(f"# ./{rel_path}", file=out)
            lang = get_language(file_path)
            print(f"```{lang}", file=out)

            try:
                with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read()
                    print(content.rstrip("\n"), file=out)
            except Exception as e:
                print(
                    f"ERROR: Failed to read file {rel_path} - {str(e)}", file=sys.stderr
                )

            print("```\n", file=out)


def main():
    # 解析命令行参数
    parser = argparse.ArgumentParser(
        description="Scan text files from stdin and output Markdown content to file(s)."
    )
    parser.add_argument(
        "num_parts",
        nargs="?",
        type=int,
        default=None,
        help="Optional number of output files to split into (balanced by file line count). "
        "If not provided, all content goes to a single file scan_output.md.",
    )
    args = parser.parse_args()

    # 从 stdin 读取所有文件路径（每行一个，已自动去除换行）
    paths = [line.strip() for line in sys.stdin if line.strip()]

    if not paths:
        print("No input paths provided.", file=sys.stderr)
        sys.exit(1)

    base_dir = Path.cwd()
    # 加载 .scanignore（首行模板 + 后续忽略规则）
    ignore_file = base_dir / ".scanignore"
    header_template, ignore_patterns = load_ignore_patterns(ignore_file)
    if ignore_patterns:
        print(
            f"Loaded {len(ignore_patterns)} ignore pattern(s) from .scanignore",
            file=sys.stderr,
        )

    print(
        f"Scanning {len(paths)} input paths (text only, applying ignore rules)...\n",
        file=sys.stderr,
    )

    # 收集有效的文本文件
    valid_files = []
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

        valid_files.append(file_path)

    if not valid_files:
        print("No valid text files to process.", file=sys.stderr)
        sys.exit(0)

    print(f"Found {len(valid_files)} valid text files.", file=sys.stderr)

    # 确定分片数量
    num_parts = args.num_parts if args.num_parts is not None else 1
    if num_parts <= 0:
        print("ERROR: num_parts must be a positive integer.", file=sys.stderr)
        sys.exit(1)
    if num_parts > len(valid_files):
        print(
            f"Warning: num_parts ({num_parts}) exceeds number of valid files "
            f"({len(valid_files)}). Using {len(valid_files)} parts instead.",
            file=sys.stderr,
        )
        num_parts = len(valid_files)

    # 按行数权重分组
    groups = split_files_by_weight(valid_files, num_parts)

    # 输出文件名规则
    if num_parts == 1:
        output_files = [Path("scan_output.md")]
    else:
        output_files = [
            Path(f"scan_output_part{i}.md") for i in range(1, num_parts + 1)
        ]

    # 生成时间戳（供模板使用）
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # 写入各分组
    for i, (group, out_file) in enumerate(zip(groups, output_files), start=1):
        print(f"Writing {len(group)} files to {out_file}", file=sys.stderr)

        # 准备模板上下文并渲染头部
        context = {
            "part_index": i,
            "num_parts": num_parts,
            "total_files": len(valid_files),
            "files_in_part": len(group),
            "timestamp": timestamp,
        }
        header_text = render_header(header_template, context)

        write_markdown_for_files(group, out_file, header_text)

    print("Done.", file=sys.stderr)


if __name__ == "__main__":
    main()
