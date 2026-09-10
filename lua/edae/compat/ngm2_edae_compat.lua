-- Noob Gore Mod 2 与 Enhanced Death Animation Extended 兼容补丁
-- 功能：
--   1. 当 NGM2 肢解骨骼时，通过 BoneControlManager 申请该骨骼及其子骨骼的控制权，使基础动画失去这些骨骼（自动 skip）
--   2. 当 NGM2 完全炸碎布娃娃时，停止 EDAE 播放并阻止其初始化
--   3. 若布娃娃在 EDAE 初始化前已被标记为爆炸，则阻止 EDAE 初始化
--
-- 优先级契约：NGM2 使用 Interface.GetMaxBoneControlPriority() + 1，
-- 保证能够抢占 EDAE 内部任何 owner 的骨骼控制权，且不需要知道 EDAE 内部
-- 优先级的具体数值。参见 edae_sv_init.lua 与 core/constants.lua。

if SERVER then
    local function ApplyPatch()
        -- 检查依赖是否已加载
        if not gore_mod_gib_PhysBone or not gore_mod_decap_ragdoll or not gore_mod_gib_ragdolll then
            return false
        end
        if not EnhancedDeathAnimationExtended or not EnhancedDeathAnimationExtended.Interface then
            return false
        end

        local EDAE          = EnhancedDeathAnimationExtended.Interface

        -- 通过 Interface 获取 EDAE 内部最大优先级，无需 include Constants。
        -- 契约保证：MAX_LOCAL 覆盖 EDAE 内部所有 owner，NGM2 使用 +1 即始终能抢占。
        local NGM2_PRIORITY = EDAE.GetMaxBoneControlPriority() + 1

        -- 保存原始函数
        local orig_gib_phys = gore_mod_gib_PhysBone
        local orig_decap    = gore_mod_decap_ragdoll
        local orig_gib_all  = gore_mod_gib_ragdolll

        -- 辅助函数：申请骨骼链控制权（最高优先级，永久有效）
        local function ClaimBoneChain(ragdoll, rootBoneName)
            if not IsValid(ragdoll) or not rootBoneName then return end

            -- 获取骨骼及其所有子骨骼
            local boneNames = EDAE.GetBoneChain(ragdoll, rootBoneName)
            if #boneNames == 0 then return end

            -- 转换为 table<string, boolean>
            local bones = {}
            for _, name in ipairs(boneNames) do
                bones[name] = true
            end

            -- 申请控制权
            EDAE.RequestBoneControl(
                ragdoll,
                "NGM2_Dismember_" .. ragdoll:EntIndex(), -- ownerID
                bones,
                NGM2_PRIORITY,
                function() return true end, -- isActiveFunc：一直有效
                nil,                        -- onGranted：无需额外操作
                nil                         -- onLost：几乎不会发生
            )
        end

        -- 包裹 gore_mod_gib_PhysBone
        function gore_mod_gib_PhysBone(ragdoll, bone_name, dmg_data)
            if IsValid(ragdoll) and bone_name then
                ClaimBoneChain(ragdoll, bone_name)
            end
            return orig_gib_phys(ragdoll, bone_name, dmg_data)
        end

        -- 包裹 gore_mod_decap_ragdoll
        function gore_mod_decap_ragdoll(ragdoll, bone_name, dmg_data)
            if IsValid(ragdoll) and bone_name then
                ClaimBoneChain(ragdoll, bone_name)
            end
            return orig_decap(ragdoll, bone_name, dmg_data)
        end

        -- 包裹 gore_mod_gib_ragdolll（完全爆炸）
        function gore_mod_gib_ragdolll(ragdoll, force, Particle)
            if IsValid(ragdoll) then
                -- 停止当前 EDAE 播放
                EDAE.StopPlayback(ragdoll, "gore_exploded")
                -- 标记该布娃娃已被爆炸，若 EDAE 尚未初始化则阻止初始化
                ragdoll.goremod_is_gibbed = true
            end
            return orig_gib_all(ragdoll, force, Particle)
        end

        return true
    end

    -- 监听 EDAE 预初始化事件：如果布娃娃已被 NGM2 标记为爆炸，则阻止 EDAE 初始化
    hook.Add("EDAE_PreRagdollInitialized", "NGM2_Block_EDA_Init", function(owner, ragdoll, initFunc)
        if IsValid(ragdoll) and ragdoll.goremod_is_gibbed then
            return true -- 返回 true 表示外部接管初始化，EDAE 将不会调用 initFunc
        end
    end)

    -- 尝试立即应用补丁，失败则延迟重试（处理加载顺序）
    local attempts = 0
    local function TryApply()
        if ApplyPatch() then return end
        attempts = attempts + 1
        if attempts <= 20 then
            timer.Simple(0.5, TryApply)
        else
            print("[NGM2-EDAE Compat] Failed to apply patch: dependencies not found.")
        end
    end
    TryApply()
end
