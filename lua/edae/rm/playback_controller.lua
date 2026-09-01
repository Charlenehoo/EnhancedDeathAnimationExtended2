-- lua/edae/rm/playback_controller.lua
-- 动画播放控制器：根据布娃娃状态和伤害上下文，选择动画并组装播放参数，最终调用 AnimationPlayer
-- 职责：将 AnimationSelector 选择的动画数据与姿态辅助（yaw）等结合，形成完整的 opts 传递给 AnimationPlayer

local MODULE_NAME = "AnimationPlaybackController"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants                   = include("edae/config/constants.lua")
local log                         = include("edae/log/init.lua")
local AnimationSelector           = include("edae/as/animation_selector.lua")
local AnimationPlayer             = include("edae/ap/animation_player.lua")
local RagdollPoseHelper           = include("edae/rm/pose_helper.lua")

local STATE_ENUM                  = Constants.LifeCycleHandler.STATE_ENUM

local AnimationPlaybackController = {}

--- 为指定状态播放动画
--- @param ragdoll Entity 布娃娃实体
--- @param state string 当前状态（来自 STATE_ENUM）
--- @param damageContext table|nil 伤害上下文（仅在 FALLING 状态时需要，用于选择死亡动画）
--- @param owner Entity|nil 布娃娃的所有者（可选，用于 FALLING 状态计算 yaw；若未提供则回退到 ragdoll 自身角度）
--- @return boolean success 是否成功启动播放
function AnimationPlaybackController:PlayForState(ragdoll, state, damageContext, owner)
    if not IsValid(ragdoll) then
        log.warn("AnimationPlaybackController:PlayForState called with invalid ragdoll")
        return false
    end

    if not STATE_ENUM[state] then
        log.warn("AnimationPlaybackController:PlayForState invalid state: ", tostring(state))
        return false
    end

    -- 计算正确的偏航角
    local yaw
    if state == STATE_ENUM.FALLING then
        -- 死亡倒地动画：优先使用 owner 的角度，如果 owner 无效则退回 ragdoll 角度
        if IsValid(owner) then
            yaw = RagdollPoseHelper:GetYawForState(owner, ragdoll, state)
        else
            log.trace("AnimationPlaybackController: owner not provided for FALLING state, using ragdoll yaw as fallback")
            yaw = ragdoll:GetAngles().yaw
        end
    else
        -- 爬行/挣扎等状态：使用 ragdoll 自身姿态计算 yaw（此时不需要 owner）
        yaw = RagdollPoseHelper:GetYawForState(owner or ragdoll, ragdoll, state)
        -- 如果 owner 为 nil，RagdollPoseHelper 内部会拒绝计算并返回 0，所以这里传入 ragdoll 作为 owner 参数以绕过检查？
        -- 更好的做法：直接调用一个不需要 owner 的重载，这里简化处理：如果 owner 无效，则手动调用骨骼提取
        if not IsValid(owner) then
            -- 手动实现：从 ragdoll 提取偏航
            local spineBone = ragdoll:LookupBone("ValveBiped.Bip01_Spine4")
                or ragdoll:LookupBone("ValveBiped.Bip01_Spine2")
                or ragdoll:LookupBone("ValveBiped.Bip01_Spine1")
                or ragdoll:LookupBone("ValveBiped.Bip01_Spine")
            if spineBone then
                local matrix = ragdoll:GetBoneMatrix(spineBone)
                if matrix then
                    local angles = matrix:GetAngles()
                    if angles then
                        local forward = angles:Forward()
                        if forward then
                            yaw = forward:Angle().y
                        else
                            yaw = ragdoll:GetAngles().yaw
                        end
                    else
                        yaw = ragdoll:GetAngles().yaw
                    end
                else
                    yaw = ragdoll:GetAngles().yaw
                end
            else
                yaw = ragdoll:GetAngles().yaw
            end
        end
    end

    -- 组装选择器所需信息
    local playBackInfo = {
        state = state,
        damageContext = damageContext,
        isFacingUp = RagdollPoseHelper:IsFacingUp(ragdoll),
        yaw = yaw, -- 虽然选择器目前未使用，但保留以便扩展
    }

    -- 选择动画
    local playbackData = AnimationSelector:Select(playBackInfo)
    if not playbackData then
        log.warn("AnimationPlaybackController: no playback data for state ", state)
        return false
    end

    -- 组装 AnimationPlayer 的 opts
    local opts = {
        totalLoops = playbackData.totalLoops,
        preWait = playbackData.preWait,
        yaw = yaw, -- 关键：传递正确的偏航角
        -- 未来可扩展 decal 配置：
        -- decal = self:GetDecalConfig(ragdoll, state),
    }

    -- 启动播放
    local ctx = AnimationPlayer:Play(ragdoll, playbackData.animationName, opts)
    if not ctx then
        log.warn("AnimationPlaybackController: failed to start animation ", playbackData.animationName)
        return false
    end

    log.trace("AnimationPlaybackController: started animation '", playbackData.animationName, "' for state '", state,
        "' with yaw=", yaw)
    return true
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationPlaybackController
return AnimationPlaybackController
