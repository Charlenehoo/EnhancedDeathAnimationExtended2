-- lua/edae/helper.lua
-- 通用辅助函数模块，供各子系统使用

local helper = {}

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
    local rootBoneID = ragdoll:LookupBone(rootBoneName)
    if not rootBoneID then return {} end

    local names = {}
    local boneCount = ragdoll:GetBoneCount()
    for boneID = 0, boneCount - 1 do
        local currentID = boneID
        while currentID and currentID ~= 0 do
            if currentID == rootBoneID then
                local name = ragdoll:GetBoneName(boneID)
                if name and name ~= "__INVALIDBONE__" then
                    names[#names + 1] = name
                end
                break
            end
            currentID = ragdoll:GetBoneParent(currentID)
        end
    end
    return names
end

return helper
