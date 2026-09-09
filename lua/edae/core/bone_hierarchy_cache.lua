-- lua/edae/core/bone_hierarchy_cache.lua
-- 骨骼层级缓存模块：在首次查询时构建 ragdoll 的骨骼父子关系并缓存，后续查询 O(子树大小)。
-- 使用弱键表存储，ragdoll 销毁后自动清理，无内存泄漏。

local MODULE_NAME = "BoneHierarchyCache"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local log = include("edae/core/log/init.lua")

local BoneHierarchyCache = {}

-- 弱键缓存：键为 ragdoll 实体，值为构建好的层级数据
local cache = setmetatable({}, { __mode = "k" })

--- 构建骨骼层级缓存
--- @param ragdoll Entity
--- @return table { children = table<boneID, boneID[]>, names = table<boneID, string> }
local function buildCache(ragdoll)
    local boneCount = ragdoll:GetBoneCount()
    local children = {}
    local names = {}

    for boneID = 0, boneCount - 1 do
        local parent = ragdoll:GetBoneParent(boneID)
        if parent and parent >= 0 then
            children[parent] = children[parent] or {}
            table.insert(children[parent], boneID)
        end

        local boneName = ragdoll:GetBoneName(boneID)
        if boneName and boneName ~= "__INVALIDBONE__" then
            names[boneID] = boneName
        end
    end

    return {
        children = children,
        names = names,
    }
end

--- 获取 ragdoll 的缓存数据（不存在则构建）
--- @param ragdoll Entity
--- @return table
local function getCache(ragdoll)
    local data = cache[ragdoll]
    if not data then
        data = buildCache(ragdoll)
        cache[ragdoll] = data
    end
    return data
end

--- 获取指定骨骼及其所有子骨骼的完整名称列表
--- @param ragdoll Entity
--- @param rootBoneName string
--- @return table 骨骼名数组
function BoneHierarchyCache.GetBoneChain(ragdoll, rootBoneName)
    if not IsValid(ragdoll) then return {} end

    local rootBoneID = ragdoll:LookupBone(rootBoneName)
    if not rootBoneID then return {} end

    local data = getCache(ragdoll)

    local names = {}
    local stack = { rootBoneID }
    local visited = {} -- 防止异常循环

    while #stack > 0 do
        local boneID = table.remove(stack)
        if not visited[boneID] then
            visited[boneID] = true
            local name = data.names[boneID]
            if name then
                names[#names + 1] = name
            end
            local children = data.children[boneID]
            if children then
                for _, childID in ipairs(children) do
                    table.insert(stack, childID)
                end
            end
        end
    end

    return names
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = BoneHierarchyCache
return BoneHierarchyCache
