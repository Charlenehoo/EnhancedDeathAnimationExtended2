#!/usr/bin/env python3
"""
lipsync_gen.py - 从 TFA-VOX 声音包批量生成逐帧口型数据（Lua 表）

支持的三种模式（自动检测）：
  1. 单文件：input 是 .wav / .mp3 / .ogg 文件
  2. 单目录：input 是一个 sound/ 目录，递归处理
  3. 多包：  input 是 addons 根目录，自动发现所有 [TFA-VOX]* 子包

输出结构：
  <output-root>/<voiceKey>.lua

依赖：Python 3.7+、ffmpeg、ffprobe（需在 PATH 中）
"""

import argparse
import fnmatch
import os
import re
import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed

AUDIO_EXTS = (".wav", ".mp3", ".ogg")


# ---------------------------------------------------------------------------
# 音频分析
# ---------------------------------------------------------------------------


def get_sample_rate(path):
    out = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "a:0",
            "-show_entries",
            "stream=sample_rate",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            path,
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    return int(out)


def extract_rms_db_per_frame(path, fps):
    """使用 ffmpeg 的 astats 滤波器从 stderr 提取每帧 RMS 电平（dBFS）。

    注意：不使用 ametadata 的 file= 参数——Windows 路径里的冒号会被
    filter 参数解析器当作分隔符，导致 EINVAL（错误码 -22）。
    """
    sr = get_sample_rate(path)
    window = max(1, sr // fps)

    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-nostdin",
        "-i",
        path,
        "-af",
        (
            f"asetnsamples={window},"
            f"astats=metadata=1:reset=1,"
            f"ametadata=print:key=lavfi.astats.Overall.RMS_level"
        ),
        "-f",
        "null",
        "-",
    ]

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="ignore",
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"ffmpeg 失败 (code={result.returncode}):\n{result.stderr.strip()[:800]}"
        )

    levels = []
    for line in result.stderr.splitlines():
        m = re.search(r"RMS_level=(-?\d+\.?\d*|-inf\w*)", line)
        if m:
            v = m.group(1)
            levels.append(-120.0 if "inf" in v else float(v))
    return levels


# ---------------------------------------------------------------------------
# 信号处理
# ---------------------------------------------------------------------------


def db_to_amplitude(db):
    return 10.0 ** (db / 20.0)


def smooth(values, window=3):
    if window <= 1 or not values:
        return list(values)
    n = len(values)
    half = window // 2
    out = []
    for i in range(n):
        lo = max(0, i - half)
        hi = min(n, i + half + 1)
        out.append(sum(values[lo:hi]) / (hi - lo))
    return out


def generate_frames(levels, gamma=1.4, noise_floor=0.02, smooth_window=3):
    if not levels:
        return []
    amps = [db_to_amplitude(db) for db in levels]
    max_amp = max(amps) if amps else 1.0
    if max_amp <= 0:
        max_amp = 1.0
    norm = [a / max_amp for a in amps]
    norm = [0.0 if v < noise_floor else v for v in norm]
    norm = [v**gamma for v in norm]
    norm = smooth(norm, smooth_window)
    return [round(min(1.0, max(0.0, v)), 3) for v in norm]


# ---------------------------------------------------------------------------
# Lua 输出
# ---------------------------------------------------------------------------


def write_lua(output_path, source_name, fps, frames):
    duration = len(frames) / fps if fps > 0 else 0.0
    out = []
    out.append("-- 自动生成，请勿手动编辑")
    out.append(f"-- 源文件: {source_name}")
    out.append(f"-- 帧率: {fps} fps")
    out.append(f"-- 时长: {duration:.3f} 秒")
    out.append(f"-- 帧数: {len(frames)}")
    out.append("return {")
    out.append(f"    fps = {fps},")
    out.append("    frames = {")
    for i in range(0, len(frames), 10):
        chunk = frames[i : i + 10]
        out.append("        " + ", ".join(f"{v:.3f}" for v in chunk) + ",")
    out.append("    },")
    out.append("}")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))


# ---------------------------------------------------------------------------
# 路径规范化与输入发现
# ---------------------------------------------------------------------------


def is_audio_file(name):
    return name.lower().endswith(AUDIO_EXTS)


def make_voice_key(rel_path):
    """'deltaforce_MaiXiaowen\\crithit1.WAV' -> 'deltaforce_maixiaowen/crithit1'"""
    key = rel_path.replace("\\", "/").lower()
    if key.startswith("sound/"):
        key = key[len("sound/") :]
    for ext in AUDIO_EXTS:
        if key.endswith(ext):
            key = key[: -len(ext)]
            break
    return key


def discover_sound_dirs(input_path):
    if os.path.isfile(input_path):
        return [
            (
                "__single_file__",
                os.path.dirname(input_path),
                os.path.basename(input_path),
            )
        ]

    if not os.path.isdir(input_path):
        return []

    packs = []
    try:
        for name in sorted(os.listdir(input_path)):
            sub = os.path.join(input_path, name)
            if not os.path.isdir(sub):
                continue
            if not name.startswith("[TFA-VOX]"):
                continue
            sound_dir = os.path.join(sub, "sound")
            if os.path.isdir(sound_dir):
                packs.append(sound_dir)
    except OSError:
        pass

    if packs:
        return [("__multi_pack__", d, None) for d in packs]

    return [("__single_dir__", input_path, None)]


def collect_tasks(sound_root, pattern=None):
    tasks = []
    for dirpath, _, filenames in os.walk(sound_root):
        for name in filenames:
            if not is_audio_file(name):
                continue
            if pattern and not fnmatch.fnmatch(name.lower(), pattern.lower()):
                continue
            abs_path = os.path.join(dirpath, name)
            rel_path = os.path.relpath(abs_path, sound_root)
            voice_key = make_voice_key(rel_path)
            tasks.append((abs_path, voice_key))
    return tasks


# ---------------------------------------------------------------------------
# 单文件处理（供并行调用）
# ---------------------------------------------------------------------------


def process_one(args):
    abs_path, voice_key, out_root, fps, gamma, noise_floor, smooth_window, force = args

    out_path = os.path.join(out_root, voice_key + ".lua")

    if not force and os.path.exists(out_path):
        return ("skip", voice_key)

    try:
        levels = extract_rms_db_per_frame(abs_path, fps)
        if not levels:
            return ("fail", f"{voice_key}: 未提取到音频数据")

        frames = generate_frames(
            levels,
            gamma=gamma,
            noise_floor=noise_floor,
            smooth_window=smooth_window,
        )
        write_lua(out_path, voice_key + ".wav", fps, frames)
        return ("ok", f"{voice_key} ({len(frames)} 帧, max={max(frames):.3f})")
    except Exception as e:
        return ("fail", f"{voice_key}: {e}")


# ---------------------------------------------------------------------------
# 主入口
# ---------------------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser(
        description="从 TFA-VOX 声音包批量生成逐帧口型数据（Lua 表）。",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument(
        "input", help="音频文件 / sound 目录 / 包含 [TFA-VOX]* 的 addons 根目录"
    )
    ap.add_argument(
        "-o",
        "--output",
        required=True,
        help="输出根目录（例如 Death Face/lua/death_face/lipsync）",
    )
    ap.add_argument(
        "--pattern", default=None, help="文件名过滤（fnmatch 模式，如 'crithit*'）"
    )
    ap.add_argument("--fps", type=int, default=30, help="目标帧率（默认 30）")
    ap.add_argument(
        "--gamma", type=float, default=1.4, help="gamma 锐化系数（默认 1.4）"
    )
    ap.add_argument(
        "--noise-floor", type=float, default=0.02, help="噪声门限 0~1（默认 0.02）"
    )
    ap.add_argument("--smooth", type=int, default=3, help="平滑窗口大小（帧，默认 3）")
    ap.add_argument("--force", action="store_true", help="强制覆盖已存在的输出文件")
    ap.add_argument(
        "--jobs", type=int, default=1, help="并行进程数（默认 1；建议设为 CPU 核数）"
    )
    ap.add_argument(
        "--on-conflict",
        choices=["skip", "overwrite"],
        default="skip",
        help="voiceKey 冲突时的策略（默认 skip）",
    )
    args = ap.parse_args()

    if not os.path.exists(args.input):
        print(f"[错误] 输入不存在: {args.input}", file=sys.stderr)
        return 1

    sound_dirs = discover_sound_dirs(args.input)
    if not sound_dirs:
        print(f"[错误] 未发现任何可处理的目录: {args.input}", file=sys.stderr)
        return 1

    all_tasks = []
    for kind, root, single_file in sound_dirs:
        if kind == "__single_file__":
            abs_path = os.path.join(root, single_file)
            voice_key = make_voice_key(single_file)
            all_tasks.append((abs_path, voice_key, single_file))
        else:
            source_label = os.path.basename(os.path.dirname(root)) or root
            for abs_path, voice_key in collect_tasks(root, args.pattern):
                all_tasks.append((abs_path, voice_key, source_label))

    if not all_tasks:
        print(f"[警告] 没有找到任何匹配的音频文件", file=sys.stderr)
        return 0

    seen = {}
    unique_tasks = []
    conflicts = []
    for abs_path, voice_key, source in all_tasks:
        if voice_key in seen:
            conflicts.append((voice_key, seen[voice_key], source))
            if args.on_conflict == "overwrite":
                for i, (_, k, _) in enumerate(unique_tasks):
                    if k == voice_key:
                        unique_tasks[i] = (abs_path, voice_key, source)
                        break
                seen[voice_key] = source
            continue
        seen[voice_key] = source
        unique_tasks.append((abs_path, voice_key, source))

    print(
        f"[信息] 共发现 {len(all_tasks)} 个音频文件，"
        f"去重后 {len(unique_tasks)} 个待处理"
    )
    if conflicts:
        print(
            f"[提示] 发现 {len(conflicts)} 个 voiceKey 冲突"
            f"（策略: {args.on_conflict}）"
        )
        for k, src_a, src_b in conflicts[:10]:
            print(f"       {k}: {src_a} vs {src_b}")
        if len(conflicts) > 10:
            print(f"       ... 还有 {len(conflicts) - 10} 个")

    params = [
        (
            abs_path,
            voice_key,
            args.output,
            args.fps,
            args.gamma,
            args.noise_floor,
            args.smooth,
            args.force,
        )
        for abs_path, voice_key, _ in unique_tasks
    ]

    ok_count = skip_count = fail_count = 0
    fails = []

    def handle_result(status, msg):
        nonlocal ok_count, skip_count, fail_count
        if status == "ok":
            ok_count += 1
            print(f"[OK]   {msg}")
        elif status == "skip":
            skip_count += 1
        else:
            fail_count += 1
            fails.append(msg)
            print(f"[FAIL] {msg}", file=sys.stderr)

    if args.jobs > 1:
        with ProcessPoolExecutor(max_workers=args.jobs) as ex:
            futures = [ex.submit(process_one, t) for t in params]
            for fut in as_completed(futures):
                status, msg = fut.result()
                handle_result(status, msg)
    else:
        for t in params:
            status, msg = process_one(t)
            handle_result(status, msg)

    print()
    print(f"[完成] 成功 {ok_count}，跳过 {skip_count}，失败 {fail_count}")
    if fails:
        print("[失败列表]", file=sys.stderr)
        for f in fails:
            print("  " + f, file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
