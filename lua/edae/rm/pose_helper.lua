-- lua/edae/rm/pose_helper.lua
-- 布娃娃姿态辅助模块：提供与布娃娃朝向和姿态相关的查询函数
-- 包括判断是否面朝上、以及根据不同动画状态计算正确的偏航角

local MODULE_NAME = "RagdollPoseHelper"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants         = include("edae/config/constants.lua")
local log               = include("edae/log/init.lua")

local STATE_ENUM        = Constants.LifeCycleHandler.STATE_ENUM

local RagdollPoseHelper = {}

--- 判断布娃娃是否面朝上
--- @param ragdoll Entity
--- @return boolean true = 面朝上, false = 面朝下（或无法判断时默认返回 false）
function RagdollPoseHelper:IsFacingUp(ragdoll)
    if not IsValid(ragdoll) then
        log.warn("RagdollPoseHelper:IsFacingUp called with invalid ragdoll")
        return false
    end

    -- 优先检查 chest 附件
    local chestAttach = ragdoll:LookupAttachment("chest")
    if chestAttach and chestAttach > 0 then
        local chestData = ragdoll:GetAttachment(chestAttach)
        if chestData and chestData.Ang then
            return chestData.Ang:Forward().z >= 0
        end
    end

    -- 回退到 eyes 附件
    local eyesAttach = ragdoll:LookupAttachment("eyes")
    if eyesAttach and eyesAttach > 0 then
        local eyesData = ragdoll:GetAttachment(eyesAttach)
        if eyesData and eyesData.Ang then
            return eyesData.Ang:Forward().z >= 0
        end
    end

    -- 默认视为面朝下
    return false
end

-- 从所有者实体获取偏航角（仅用于 FALLING 状态，布娃娃尚未倒地）
--- @param owner Entity
--- @return number yaw
function RagdollPoseHelper:GetYawFromOwner(owner)
    if not IsValid(owner) then
        log.warn("RagdollPoseHelper:GetYawFromOwner called with invalid owner")
        return 0
    end
    return owner:GetAngles().yaw
end

-- 从布娃娃自身骨骼提取水平偏航角（用于已倒地状态）
--- @param ragdoll Entity
--- @return number yaw
function RagdollPoseHelper:GetYawFromRagdoll(ragdoll)
    if not IsValid(ragdoll) then
        log.warn("RagdollPoseHelper:GetYawFromRagdoll called with invalid ragdoll")
        return 0
    end

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
                    return forward:Angle().y
                end
            end
        end
    end
    return ragdoll:GetAngles().yaw
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = RagdollPoseHelper
return RagdollPoseHelper
