-- lua/edae/helper.lua
-- 通用辅助函数模块，供各子系统使用

-- 文件顶部添加
local RagdollBoneCache = include("edae/core/ragdoll_bone_cache.lua")

local helper = {}

-- 返回 x 的符号：正数返回 1，负数返回 -1，零返回 0
function helper.Sign(x)
    if x > 0 then
        return 1
    elseif x < 0 then
        return -1
    else
        return 0
    end
end

--- 从稠密表（数组）中随机选择一个元素
--- @param denseTable table 以连续整数索引的数组
--- @return any|nil 随机元素，若表为空或 nil 则返回 nil
function helper.RandomFromDenseTable(denseTable)
    if not denseTable or #denseTable == 0 then
        return nil
    end
    return denseTable[math.random(#denseTable)]
end

--- 递归获取指定骨骼及其所有子骨骼的完整名称列表
--- @param ragdoll Entity
--- @param rootBoneName string
--- @return table 骨骼名数组
function helper.GetBoneChain(ragdoll, rootBoneName)
    return RagdollBoneCache.GetBoneChain(ragdoll, rootBoneName)
end

local function getStandPosByBone(ent)
    local LEFT_FOOT = "ValveBiped.Bip01_L_Foot"
    local RIGHT_FOOT = "ValveBiped.Bip01_R_Foot"

    local leftFoot = ent:LookupBone(LEFT_FOOT)
    local rightFoot = ent:LookupBone(RIGHT_FOOT)
    if not leftFoot or not rightFoot then return nil end

    local leftPos, _ = ent:GetBonePosition(leftFoot)
    local rightPos, _ = ent:GetBonePosition(rightFoot)
    if not leftPos or not rightPos then return nil end

    return (leftPos + rightPos) * 0.5
end

function helper.GetStandPos(ent)
    local standPos = getStandPosByBone(ent)
    if standPos then return standPos end

    return ent:GetPos()
end

return helper
