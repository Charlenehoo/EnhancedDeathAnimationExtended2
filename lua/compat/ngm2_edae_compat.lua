-- Noob Gore Mod 2 与 Enhanced Death Animation Extended 兼容补丁
-- 功能：
--   1. 当 NGM2 肢解骨骼时，通过 EDAE.SetBoneSkip 跳过该骨骼及其子骨骼的动画控制
--   2. 当 NGM2 完全炸碎布娃娃时，停止 EDAE 播放并阻止其初始化
--   3. 若布娃娃在 EDAE 初始化前已被标记为爆炸，则阻止 EDAE 初始化

if SERVER then
    local function ApplyPatch()
        -- 检查依赖是否已加载
        if not gore_mod_gib_PhysBone or not gore_mod_decap_ragdoll or not gore_mod_gib_ragdolll then
            return false
        end
        if not EnhancedDeathAnimationExtended or not EnhancedDeathAnimationExtended.Interface then
            return false
        end

        local EDAE = EnhancedDeathAnimationExtended.Interface

        -- 保存原始函数
        local orig_gib_phys = gore_mod_gib_PhysBone
        local orig_decap = gore_mod_decap_ragdoll
        local orig_gib_all = gore_mod_gib_ragdolll

        -- 包裹 gore_mod_gib_PhysBone
        function gore_mod_gib_PhysBone(ragdoll, bone_name, dmg_data)
            if IsValid(ragdoll) and bone_name then
                -- 跳过该骨骼及其所有子骨骼的 EDAE 控制
                EDAE.SetBoneSkip(ragdoll, bone_name, true, true)
            end
            return orig_gib_phys(ragdoll, bone_name, dmg_data)
        end

        -- 包裹 gore_mod_decap_ragdoll
        function gore_mod_decap_ragdoll(ragdoll, bone_name, dmg_data)
            if IsValid(ragdoll) and bone_name then
                -- 切片同样会移除原布娃娃上的骨骼链，需要跳过
                EDAE.SetBoneSkip(ragdoll, bone_name, true, true)
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
