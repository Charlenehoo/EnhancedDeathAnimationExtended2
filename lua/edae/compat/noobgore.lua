--[[-------------------------------------------------------------------------
    Noob Gore Mod 2 × EDAE 兼容层
    作用：在 Noob Gore Mod 2 对布娃娃进行肢解/碎尸前，先停止 EDAE 的动画播放
---------------------------------------------------------------------------]]
if SERVER then
    AddCSLuaFile()

    -- 保存 EDAE 正在控制的布娃娃
    local EDAE_ControlledRagdolls = {}

    -- 检查 EDAE 是否可用
    local function IsEDAEActive()
        return EnhancedDeathAnimationExtended and
            EnhancedDeathAnimationExtended.Interface and
            EnhancedDeathAnimationExtended.Interface.StopPlayback
    end

    -- 如果布娃娃处于 EDAE 控制中，则先停止其动画
    local function StopEDAEIfNeeded(ragdoll)
        if not IsValid(ragdoll) then return end
        if EDAE_ControlledRagdolls[ragdoll] and IsEDAEActive() then
            EnhancedDeathAnimationExtended.Interface.StopPlayback(ragdoll, "Cancelled")
            -- 停止后 EDAE 状态机会自动转为 DEAD 或相应状态，并触发状态变化事件，
            -- 届时会从 EDAE_ControlledRagdolls 中移除该布娃娃
        end
    end

    -- 监听 EDAE 状态变化，维护控制表
    hook.Add("EDAE_OnRagdollStateChange", "NoobGore_EDAE_Compat_StateChange", function(ragdoll, newState, oldState)
        if not IsValid(ragdoll) then return end
        if newState == "dead" then
            EDAE_ControlledRagdolls[ragdoll] = nil
        else
            EDAE_ControlledRagdolls[ragdoll] = true
        end
    end)

    -- 实体被移除时清理控制表
    hook.Add("EntityRemoved", "NoobGore_EDAE_Compat_EntityRemoved", function(ent)
        if EDAE_ControlledRagdolls[ent] then
            EDAE_ControlledRagdolls[ent] = nil
        end
    end)

    -- 在所有脚本加载完成后，覆盖 Noob Gore Mod 2 的破坏性函数
    hook.Add("InitPostEntity", "NoobGore_EDAE_Compat_Init", function()
        -- 检查 Noob Gore Mod 2 是否已加载
        if not gore_mod_dismember_limb then return end

        -- 保存原始函数
        local orig_dismember    = gore_mod_dismember_limb
        local orig_gib_ragdoll  = gore_mod_gib_ragdolll
        local orig_decap        = gore_mod_decap_ragdoll
        local orig_gib_phys     = gore_mod_gib_PhysBone

        -- 覆盖：肢解
        gore_mod_dismember_limb = function(ragdoll, bone_name, dmg_data)
            StopEDAEIfNeeded(ragdoll)
            return orig_dismember(ragdoll, bone_name, dmg_data)
        end

        -- 覆盖：整体碎尸
        gore_mod_gib_ragdolll   = function(ragdoll, force, Particle)
            StopEDAEIfNeeded(ragdoll)
            return orig_gib_ragdoll(ragdoll, force, Particle)
        end

        -- 覆盖：分离肢体（通常被上一个函数调用，但以防直接调用）
        gore_mod_decap_ragdoll  = function(ragdoll, bone_name, dmg_data)
            StopEDAEIfNeeded(ragdoll)
            return orig_decap(ragdoll, bone_name, dmg_data)
        end

        -- 覆盖：直接破坏骨骼物理
        gore_mod_gib_PhysBone   = function(ragdoll, bone_name, dmg_data)
            StopEDAEIfNeeded(ragdoll)
            return orig_gib_phys(ragdoll, bone_name, dmg_data)
        end
    end)
end
