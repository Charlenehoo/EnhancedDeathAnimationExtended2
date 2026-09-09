-- lua/edae/core/ragdoll_bone_cache.lua
-- 布娃娃骨骼数据缓存：构建一次，提供以骨骼名为键的完整数据表，包括骨骼ID、物理对象索引、物理对象引用、父子关系。
-- 所有数据随 ragdoll 实体弱引用自动清理。

local MODULE_NAME = "RagdollBoneCache"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local log = include("edae/core/log/init.lua")

local RagdollBoneCache = {}

-- 弱键缓存：键为 ragdoll 实体，值为完整数据表
local cache = setmetatable({}, { __mode = "k" })

--- 构建 ragdoll 的完整骨骼数据表
--- @param ragdoll Entity
--- @return table { [boneName] = { boneID=number, physID=number|nil, physObj=PhysObj|nil, parentName=string|nil, childrenNames=table } }
local function buildBoneDataMap(ragdoll)
    local boneCount = ragdoll:GetBoneCount()
    local physCount = ragdoll:GetPhysicsObjectCount()

    local dataMap = {}

    -- 第一遍：收集骨骼名称与父子关系（使用ID暂存）
    local idToName = {}
    local idToParent = {}
    local idToChildren = {}

    for boneID = 0, boneCount - 1 do
        local name = ragdoll:GetBoneName(boneID)
        if name and name ~= "__INVALIDBONE__" then
            idToName[boneID] = name
            local parent = ragdoll:GetBoneParent(boneID)
            if parent and parent >= 0 then
                idToParent[boneID] = parent
                idToChildren[parent] = idToChildren[parent] or {}
                table.insert(idToChildren[parent], boneID)
            end
        end
    end

    -- 第二遍：构建以名称为键的表，并填充物理映射
    for boneID, name in pairs(idToName) do
        local entry = {
            boneID = boneID,
            physID = nil,
            physObj = nil,
            parentName = idToParent[boneID] and idToName[idToParent[boneID]] or nil,
            childrenNames = {},
        }

        -- 查找该骨骼对应的物理对象
        for physID = 0, physCount - 1 do
            if ragdoll:TranslatePhysBoneToBone(physID) == boneID then
                entry.physID = physID
                entry.physObj = ragdoll:GetPhysicsObjectNum(physID)
                break
            end
        end

        -- 填充子骨骼名称
        local childrenIDs = idToChildren[boneID]
        if childrenIDs then
            for _, childID in ipairs(childrenIDs) do
                local childName = idToName[childID]
                if childName then
                    table.insert(entry.childrenNames, childName)
                end
            end
        end

        dataMap[name] = entry
    end

    return dataMap
end

--- 获取 ragdoll 的骨骼数据表（惰性构建并缓存）
--- @param ragdoll Entity
--- @return table
function RagdollBoneCache.GetBoneDataMap(ragdoll)
    if not IsValid(ragdoll) then return nil end

    local dataMap = cache[ragdoll]
    if not dataMap then
        dataMap = buildBoneDataMap(ragdoll)
        cache[ragdoll] = dataMap
    end
    return dataMap
end

--- 获取指定骨骼及其所有子骨骼的完整名称列表（基于缓存）
--- @param ragdoll Entity
--- @param rootBoneName string
--- @return table 骨骼名数组
function RagdollBoneCache.GetBoneChain(ragdoll, rootBoneName)
    local dataMap = RagdollBoneCache.GetBoneDataMap(ragdoll)
    if not dataMap or not dataMap[rootBoneName] then return {} end

    local result = {}
    local stack = { rootBoneName }
    local visited = {}

    while #stack > 0 do
        local name = table.remove(stack)
        if not visited[name] then
            visited[name] = true
            local entry = dataMap[name]
            if entry then
                result[#result + 1] = name
                for _, childName in ipairs(entry.childrenNames) do
                    table.insert(stack, childName)
                end
            end
        end
    end

    return result
end

--- 清空缓存（一般不需要手动调用）
function RagdollBoneCache.Clear(ragdoll)
    cache[ragdoll] = nil
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = RagdollBoneCache
return RagdollBoneCache
