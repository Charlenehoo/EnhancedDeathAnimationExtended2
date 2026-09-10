#!/usr/bin/env python3
"""
从标准输入读取文件路径列表（每行一个），输出文本文件的 Markdown 格式内容。

所有扩展名分类与语言映射由 scan_ext.json 提供：
  - text_exts   : 明确判定为文本的扩展名（小写、含点）
  - binary_exts : 明确判定为二进制的扩展名（小写、含点）
  - lang_map    : 扩展名 -> Markdown 代码块语言标识（可省略，缺省则留空）

判定顺序：
  1. 命中 binary_exts → 跳过
  2. 命中 text_exts   → 视为文本
  3. 扩展名未知 → 启发式：含 NUL 判为二进制；否则依次尝试
     utf-8-sig / utf-8 / gbk / big5 / latin-1 解码，
     任一成功且可打印字符比例 >= 0.90 → 文本

忽略规则：
  .scanignore 每行一个 glob 模式（空行与 # 注释忽略）。

输出：
  当前工作目录下的 scan_output.md

用法：
    git ls-files | python scan.py
    git ls-files | python -m scan
"""

import sys
import json
import fnmatch
from pathlib import Path

# ------------------------------------------------------------
# 启发式参数（逻辑常量，非数据）
# ------------------------------------------------------------
SAMPLE_BYTES = 8192
PRINTABLE_RATIO_MIN = 0.90
DECODE_ATTEMPTS = ("utf-8-sig", "utf-8", "gbk", "big5", "latin-1")


# ============================================================
# 配置加载
# ============================================================


def load_config(config_path: Path):
    """从 scan_ext.json 读取扩展名分类和语言映射。失败则退出。"""
    if not config_path.is_file():
        print(f"ERROR: config file not found: {config_path}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(config_path, "r", encoding="utf-8") as f:
            cfg = json.load(f)
    except Exception as e:
        print(f"ERROR: failed to parse {config_path}: {e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(cfg, dict):
        print(f"ERROR: {config_path} root must be a JSON object", file=sys.stderr)
        sys.exit(1)

    text_exts = {str(x).lower() for x in cfg.get("text_exts", []) if x}
    binary_exts = {str(x).lower() for x in cfg.get("binary_exts", []) if x}
    lang_map = {str(k).lower(): str(v) for k, v in cfg.get("lang_map", {}).items()}

    if not text_exts and not binary_exts:
        print(
            f"WARNING: {config_path} declares no text_exts and no binary_exts; "
            "all files will fall through to heuristics.",
            file=sys.stderr,
        )

    return text_exts, binary_exts, lang_map


# ============================================================
# .scanignore
# ============================================================


def load_ignore_patterns(ignore_file: Path):
    if not ignore_file.is_file():
        return []
    patterns = []
    with open(ignore_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            patterns.append(line.replace("\\", "/"))
    return patterns


def is_ignored(rel_path: str, patterns) -> bool:
    rel_path = rel_path.replace("\\", "/")
    for pattern in patterns:
        if fnmatch.fnmatch(rel_path, pattern):
            return True
    return False


# ============================================================
# 文件类型判断
# ============================================================


def ext_of(file_path: Path) -> str:
    return file_path.suffix.lower()


def classify_by_ext(file_path: Path, text_exts, binary_exts):
    ext = ext_of(file_path)
    if not ext:
        return "unknown"
    if ext in binary_exts:
        return "binary"
    if ext in text_exts:
        return "text"
    return "unknown"


def heuristic_is_text(file_path: Path) -> bool:
    try:
        with open(file_path, "rb") as f:
            chunk = f.read(SAMPLE_BYTES)
    except Exception:
        return False

    if not chunk:
        return True
    if b"\x00" in chunk:
        return False

    def printable_ratio(text: str) -> float:
        if not text:
            return 1.0
        count = sum(1 for c in text if c.isprintable() or c in "\n\r\t")
        return count / len(text)

    for enc in DECODE_ATTEMPTS:
        try:
            text = chunk.decode(enc)
        except (UnicodeDecodeError, LookupError):
            continue
        if printable_ratio(text) >= PRINTABLE_RATIO_MIN:
            return True
    return False


def is_text_file(file_path: Path, text_exts, binary_exts):
    kind = classify_by_ext(file_path, text_exts, binary_exts)
    if kind == "binary":
        return False, "ext-binary"
    if kind == "text":
        return True, "ext-text"
    if heuristic_is_text(file_path):
        return True, "heuristic-text"
    return False, "heuristic-binary"


def get_language(file_path: Path, lang_map) -> str:
    return lang_map.get(ext_of(file_path), "")


# ============================================================
# 输出
# ============================================================


def write_markdown_for_files(file_paths, out_file: Path, lang_map):
    with open(out_file, "w", encoding="utf-8") as out:
        for file_path in file_paths:
            rel_path = file_path.relative_to(Path.cwd()).as_posix()
            print(f"# ./{rel_path}", file=out)
            lang = get_language(file_path, lang_map)
            print(f"```{lang}", file=out)
            try:
                with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read()
                print(content.rstrip("\n"), file=out)
            except Exception as e:
                print(f"ERROR: Failed to read {rel_path} - {e}", file=sys.stderr)
            print("```\n", file=out)


# ============================================================
# 主流程
# ============================================================


def main():
    paths = [line.strip() for line in sys.stdin if line.strip()]
    if not paths:
        print("No input paths provided.", file=sys.stderr)
        sys.exit(1)

    base_dir = Path.cwd()

    text_exts, binary_exts, lang_map = load_config(base_dir / "scan_ext.json")
    print(
        f"Loaded config: {len(text_exts)} text exts, "
        f"{len(binary_exts)} binary exts, "
        f"{len(lang_map)} lang mappings.",
        file=sys.stderr,
    )

    ignore_patterns = load_ignore_patterns(base_dir / ".scanignore")
    if ignore_patterns:
        print(
            f"Loaded {len(ignore_patterns)} ignore pattern(s) from .scanignore",
            file=sys.stderr,
        )

    print(f"Scanning {len(paths)} input paths...", file=sys.stderr)

    valid_files = []
    for rel_path in paths:
        rel_path = rel_path.replace("\\", "/")
        file_path = base_dir / rel_path

        if is_ignored(rel_path, ignore_patterns):
            print(f"Ignored: {rel_path}", file=sys.stderr)
            continue
        if not file_path.is_file():
            print(f"Skipping missing file: {rel_path}", file=sys.stderr)
            continue

        ok, reason = is_text_file(file_path, text_exts, binary_exts)
        if not ok:
            print(f"Skipping ({reason}): {rel_path}", file=sys.stderr)
            continue
        valid_files.append(file_path)

    if not valid_files:
        print("No valid text files to process.", file=sys.stderr)
        sys.exit(0)

    print(f"Found {len(valid_files)} valid text files.", file=sys.stderr)

    out_file = base_dir / "scan_output.md"
    write_markdown_for_files(valid_files, out_file, lang_map)
    print(f"Written to {out_file}", file=sys.stderr)
    print("Done.", file=sys.stderr)


if __name__ == "__main__":
    main()
