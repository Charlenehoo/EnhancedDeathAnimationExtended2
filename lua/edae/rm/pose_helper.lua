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

--- 根据动画状态计算正确的偏航角
--- @param owner Entity 布娃娃的所有者（通常是 NPC 或玩家）
--- @param ragdoll Entity 布娃娃实体
--- @param state string 当前动画状态（来自 STATE_ENUM）
--- @return number yaw 角度值（度）
function RagdollPoseHelper:GetYawForState(owner, ragdoll, state)
    if not IsValid(owner) or not IsValid(ragdoll) then
        log.warn("RagdollPoseHelper:GetYawForState called with invalid entities")
        return 0
    end

    if state == STATE_ENUM.FALLING then
        -- 死亡倒地动画：布娃娃刚生成，尚未倒地，使用所有者的角度即可反映躯干朝向
        return owner:GetAngles().yaw
    else
        -- 爬行/挣扎动画：布娃娃已躺倒，需从胸部骨骼提取水平偏航
        -- 优先使用 Spine4，依次回退到 Spine2、Spine1、Spine
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

        -- 回退到布娃娃实体的偏航角
        return ragdoll:GetAngles().yaw
    end
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = RagdollPoseHelper
return RagdollPoseHelper
