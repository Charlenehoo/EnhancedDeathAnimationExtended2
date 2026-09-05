-- BSMod KillMove → EDAE 兼容补丁（延迟初始化 + 加载时序修正）
if SERVER then
    hook.Add("InitPostEntity", "BSMod_EDAE_Compat", function()
        -- 此时 BSMod 和 EDAE 的服务器文件都应该已加载
        if not KMCheck then
            MsgC(Color(255, 200, 0), "[BSMod-EDAE Compat] BSMod not found, patch not applied.\n")
            return
        end
        if not EnhancedDeathAnimationExtended or not EnhancedDeathAnimationExtended.Interface then
            MsgC(Color(255, 200, 0), "[BSMod-EDAE Compat] EDAE not found, patch not applied.\n")
            return
        end

        local cv_skip_state = CreateConVar(
            "bsmod_edae_skip_state",
            "random",
            { FCVAR_ARCHIVE, FCVAR_REPLICATED },
            "State after BSMod KillMove: random, writhing, twitching"
        )

        local function GetKillMoveInitialState()
            local mode = cv_skip_state:GetString():lower()
            if mode == "writhing" then return "writhing" end
            if mode == "twitching" then return "twitching" end
            return math.random(2) == 1 and "writhing" or "twitching"
        end

        local pendingInits = {}
        local kmRagdollAlreadyFired = {}

        -- 拦截 EDAE 预初始化：阻止默认，保存句柄
        hook.Add("EDAE_PreRagdollInitialized", "BSMod_EDAE_DelayInit", function(owner, ragdoll, initFunc)
            if not IsValid(owner) then return end

            if owner.bsmod_killed_by_killmove then
                if kmRagdollAlreadyFired[ragdoll] then
                    kmRagdollAlreadyFired[ragdoll] = nil
                    if initFunc then
                        initFunc(GetKillMoveInitialState())
                    end
                else
                    pendingInits[ragdoll] = {
                        owner = owner,
                        initFunc = initFunc
                    }
                end
                -- 始终阻止 EDAE 默认初始化
                return true
            end
        end)

        -- 监听 KMRagdoll：BSMod 定位完成后调用保存的初始化函数
        hook.Add("KMRagdoll", "BSMod_EDAE_TriggerInit", function(entity, ragdoll, animName)
            if not IsValid(ragdoll) then return end

            if pendingInits[ragdoll] then
                local info = pendingInits[ragdoll]
                pendingInits[ragdoll] = nil
                if info.initFunc then
                    info.initFunc(GetKillMoveInitialState())
                end
            else
                kmRagdollAlreadyFired[ragdoll] = true
            end
        end)
    end)
end
