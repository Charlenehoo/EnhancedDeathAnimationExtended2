#!/usr/bin/env python3
"""
自动化重构脚本：
1. 根据映射表移动 lua/ 下的文件到新目录。
2. 更新所有 .lua 文件中 include("...") 的路径。
3. 特殊处理 log/init.lua 中的 include("log.lua")。
用法：
    python refactor_edae.py            # 执行
    python refactor_edae.py --dry-run  # 仅预览，不修改
"""

import os
import re
import shutil
import sys
from pathlib import Path

# ------------------------------------------------------------
# 配置
# ------------------------------------------------------------
PROJECT_ROOT = Path.cwd()  # 假设在项目根目录运行
LUA_DIR = PROJECT_ROOT / "lua"  # lua 目录

# 文件移动映射：旧相对路径（相对于 lua/） -> 新相对路径（相对于 lua/）
MOVE_MAP = {
    # core
    "edae/config/constants.lua": "edae/core/constants.lua",
    "edae/coroutine_scheduler.lua": "edae/core/coroutine_scheduler.lua",
    "edae/eds/entity_data_store.lua": "edae/core/entity_data_store.lua",
    "edae/log/init.lua": "edae/core/log/init.lua",
    "edae/log/log.lua": "edae/core/log/log.lua",
    "edae/rm/health_manager.lua": "edae/core/health_manager.lua",
    # data
    "edae/config/animation_model_map.lua": "edae/data/animation_model_map.lua",
    "edae/config/female_models.lua": "edae/data/female_models.lua",
    "edae/as/animation_categories.lua": "edae/data/animation_categories.lua",
    "edae/as/bone_whitelists.lua": "edae/data/bone_whitelists.lua",
    # state
    "edae/life_cycle_handler.lua": "edae/state/life_cycle_handler.lua",
    "edae/mortality_evaluator.lua": "edae/state/mortality_evaluator.lua",
    # damage
    "edae/damage_context_manager.lua": "edae/damage/damage_context_manager.lua",
    "edae/ragdoll_damage_processor.lua": "edae/damage/ragdoll_damage_processor.lua",
    # player
    "edae/player_proxy.lua": "edae/player/player_proxy.lua",
    "edae/sh_player_create_prop_ragdoll.lua": "edae/player/sh_player_create_prop_ragdoll.lua",
    # playback
    "edae/ap/animation_player.lua": "edae/playback/animation_player.lua",
    "edae/ap/twitch_controller.lua": "edae/playback/twitch_controller.lua",
    "edae/ap/helper.lua": "edae/playback/helper.lua",
    "edae/rm/playback_coordinator.lua": "edae/playback/playback_coordinator.lua",
    "edae/rm/pose_helper.lua": "edae/playback/pose_helper.lua",
    "edae/as/animation_assembler.lua": "edae/playback/assemblers/animation_assembler.lua",
    "edae/as/twitch_assembler.lua": "edae/playback/assemblers/twitch_assembler.lua",
    "edae/as/animation_selector.lua": "edae/playback/selectors/animation_selector.lua",
    "edae/as/bone_whitelist_selector.lua": "edae/playback/selectors/bone_whitelist_selector.lua",
    "edae/as/prewait_builder.lua": "edae/playback/builders/prewait_builder.lua",
    "edae/as/effect_builder.lua": "edae/playback/builders/effect_builder.lua",
    "edae/as/ground_strategy_builder.lua": "edae/playback/builders/ground_strategy_builder.lua",
    # ragdoll
    "edae/rm/ragdoll_manager.lua": "edae/ragdoll/ragdoll_manager.lua",
    "edae/rm/voice_manager.lua": "edae/ragdoll/voice_manager.lua",
    "edae/rm/revive_manager.lua": "edae/ragdoll/revive_manager.lua",
    # compat
    "compat/bsmod_edae_compat.lua": "edae/compat/bsmod_edae_compat.lua",
    "compat/ngm2_edae_compat.lua": "edae/compat/ngm2_edae_compat.lua",
}

# 额外的 include 替换规则（特殊路径）
SPECIAL_INCLUDE_REPLACEMENTS = {
    "log.lua": "edae/core/log/log.lua",  # 处理 edae/core/log/init.lua 中的 include("log.lua")
}


# ------------------------------------------------------------
# 辅助函数
# ------------------------------------------------------------
def normalize_path(path_str: str) -> str:
    """将 Windows 反斜杠转为正斜杠，并去除前导斜杠。"""
    return path_str.replace("\\", "/").strip("/")


def ensure_dir(path: Path):
    """确保目录存在。"""
    path.mkdir(parents=True, exist_ok=True)


def move_file(src: Path, dst: Path, dry_run: bool = False):
    """移动文件，支持 dry-run。"""
    if not src.exists():
        print(f"  [警告] 源文件不存在: {src}")
        return False
    if dst.exists():
        print(f"  [警告] 目标文件已存在，跳过: {dst}")
        return False
    if dry_run:
        print(
            f"  [移动] {src.relative_to(PROJECT_ROOT)} -> {dst.relative_to(PROJECT_ROOT)}"
        )
    else:
        ensure_dir(dst.parent)
        shutil.move(str(src), str(dst))
        print(
            f"  [移动] {src.relative_to(PROJECT_ROOT)} -> {dst.relative_to(PROJECT_ROOT)}"
        )
    return True


def replace_include_in_file(file_path: Path, dry_run: bool = False):
    """替换单个 .lua 文件中的 include 路径。"""
    try:
        content = file_path.read_text(encoding="utf-8")
    except Exception as e:
        print(f"  [错误] 读取文件失败 {file_path}: {e}")
        return

    original = content

    # 正则匹配 include("...") 或 include('...')
    pattern = re.compile(r'include\(\s*["\']([^"\']+)["\']\s*\)')

    def replacer(match):
        old_path = match.group(1).replace("\\", "/")
        # 1. 先在 MOVE_MAP 中查找
        if old_path in MOVE_MAP:
            new_path = MOVE_MAP[old_path]
            return f'include("{new_path}")'
        # 2. 特殊替换
        if old_path in SPECIAL_INCLUDE_REPLACEMENTS:
            new_path = SPECIAL_INCLUDE_REPLACEMENTS[old_path]
            return f'include("{new_path}")'
        # 3. 保持原样
        return match.group(0)

    new_content = pattern.sub(replacer, content)

    if new_content != original:
        if dry_run:
            print(f"  [修改] {file_path.relative_to(PROJECT_ROOT)}")
        else:
            file_path.write_text(new_content, encoding="utf-8")
            print(f"  [修改] {file_path.relative_to(PROJECT_ROOT)}")


# ------------------------------------------------------------
# 主流程
# ------------------------------------------------------------
def main():
    dry_run = "--dry-run" in sys.argv

    if dry_run:
        print("=== Dry run 模式：仅显示将执行的操作，不实际修改 ===\n")
    else:
        print("=== 执行重构 ===\n")

    # 1. 移动文件
    print("步骤 1：移动文件")
    for old_rel, new_rel in MOVE_MAP.items():
        src = LUA_DIR / old_rel
        dst = LUA_DIR / new_rel
        move_file(src, dst, dry_run)

    # 2. 替换 include 路径
    print("\n步骤 2：更新 include 路径")
    # 遍历 lua/ 下所有 .lua 文件
    for lua_file in LUA_DIR.rglob("*.lua"):
        replace_include_in_file(lua_file, dry_run)

    if dry_run:
        print("\nDry run 完成，没有实际修改。")
    else:
        print("\n重构完成！请检查 Git 状态并测试。")


if __name__ == "__main__":
    main()
