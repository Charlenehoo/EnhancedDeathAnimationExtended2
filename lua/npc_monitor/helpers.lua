-- npc_monitor/helpers.lua
-- 通用辅助函数，供 NPC Monitor 各模块使用
local CONSTANTS           = include("npc_monitor/config/constants.lua")
local Enum                = include("npc_monitor/config/enum.lua")
local BONE_FALLBACK_ORDER = include("npc_monitor/config/bones.lua")

local M                   = {}

local function _addHook(eventName, func, appendix)
    appendix = appendix or ""
    local identifier = CONSTANTS.PLUGIN_NAME .. "_" .. appendix .. "_" .. eventName
    hook.Add(eventName, identifier, func)
    return identifier
end

local uniqueCounters = {}

--- Add a unique hook, yet people won't be able to remove it unless they got its return valve
---@param eventName string
---@param func function
---@return string identifier to remove this hook
function M.addUniqueHook(eventName, func)
    uniqueCounters[eventName] = uniqueCounters[eventName] or 1
    local uniqueCounter = uniqueCounters[eventName]

    local hotFixFriendly = CONSTANTS.HOT_FIX_FRIENDLY

    local appendix
    if hotFixFriendly then
        appendix = uniqueCounter
    else
        appendix = tostring(uniqueCounter) .. tostring(CurTime()) .. "_" .. "_" .. tostring(math.random())
    end

    uniqueCounters[eventName] = uniqueCounters[eventName] + 1

    return _addHook(eventName, func, appendix)
end

--- Add a hook, yet people will be able to remove it by even they didn't got its return valve,
--- yet caller of this function is responsible for the uniqueness of the appendix
---@param eventName string
---@param func function
---@return string identifier to remove this hook
function M.addHook(eventName, func, appendix)
    return _addHook(eventName, func, appendix)
end

function M.getStateName(id)
    if not id then
        return "NPC_STATE_UNKNOWN"
    else
        return Enum.NPC_STATE_ID_TO_NAME[id] or ("NPC_STATE_UNKNOWN_" .. id)
    end
end

-- 生成 schedule 名称
-- @param id  schedule 的整数编号
-- @param npc 可选，NPC 实体（用于区分不同类别的专属 schedule）
-- @return 字符串形式的 schedule 名称
function M.getScheduleName(id, npc)
    if not id then
        return "NIL"
    end

    if IsValid(npc) and npc:GetClass() == "npc_combine_s" then
        local combineName = Enum.COMBINE_SCHEDULE_ID_TO_NAME[id]
        if combineName then
            return combineName
        end
    end

    local sharedName = Enum.SCHEDULE_ID_TO_NAME[id]
    if sharedName then
        return sharedName
    end

    return "SCHED_UNKNOWN_" .. id
end

-- 使用 Box-Muller 变换生成标准正态分布随机数
-- 返回均值为 0，标准差为 1 的随机数
function M.gaussianRandom()
    local u1 = math.random()
    local u2 = math.random()
    -- 避免 u1 为 0 导致 log(0)
    if u1 == 0 then u1 = 1e-10 end
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

-- 通用函数：在指定位置附近查找最近的符合过滤条件的实体
-- @param pos Vector 中心位置
-- @param maxDist number|nil 最大搜索距离（单位），nil 表示无限制
-- @param source function|table|nil 数据源：函数（返回实体列表）或实体列表（表），默认 ents.GetAll
-- @param filterFunc function|nil 谓词函数，接收实体，返回 boolean，默认只检查 IsValid
-- @return Entity|nil 最近的实体，若没有则返回 nil
function M.findNearestEntity(pos, maxDist, source, filterFunc)
    source = source or ents.GetAll
    filterFunc = filterFunc or function(ent) return IsValid(ent) end

    local list = type(source) == "function" and source() or source
    local nearest, nearestDistSqr = nil, (maxDist and maxDist * maxDist) or math.huge

    for _, ent in ipairs(list) do
        if filterFunc(ent) then
            local distSqr = ent:GetPos():DistToSqr(pos)
            if distSqr < nearestDistSqr then
                nearestDistSqr = distSqr
                nearest = ent
            end
        end
    end
    return nearest
end

function M.findNearestPlayer(pos, maxDist)
    return M.findNearestEntity(pos, maxDist, player.GetAll, function(ent)
        return IsValid(ent) and ent:Alive()
    end)
end

--- 在指定位置附近随机选择一个符合过滤条件的实体
-- @param pos Vector 中心位置
-- @param maxDist number|nil 最大搜索距离（单位），nil 表示无限制
-- @param source function|table|nil 数据源：函数（返回实体列表）或实体列表（表），默认 ents.GetAll
-- @param filterFunc function|nil 谓词函数，接收实体，返回 boolean，默认只检查 IsValid
-- @return Entity|nil 随机选择的实体，若没有则返回 nil
function M.findRandomEntity(pos, maxDist, source, filterFunc)
    source = source or ents.GetAll
    filterFunc = filterFunc or function(ent) return IsValid(ent) end

    local list = type(source) == "function" and source() or source
    local candidates = {}
    local maxDistSqr = maxDist and maxDist * maxDist or nil

    for _, ent in ipairs(list) do
        if filterFunc(ent) then
            if not maxDistSqr or ent:GetPos():DistToSqr(pos) <= maxDistSqr then
                table.insert(candidates, ent)
            end
        end
    end

    if #candidates == 0 then return nil end
    return candidates[math.random(#candidates)]
end

function M.getEyePos(ent)
    if ent._GetEyePosStrategyCache then
        local s = ent._GetEyePosStrategyCache

        if s == "Attachment" then
            local attach = ent:GetAttachment(ent._GetEyePosIDCache)
            if attach and attach.Pos then
                return attach.Pos
            end
            ent._GetEyePosStrategyCache = nil
        elseif s == "Bone" then
            local pos = ent:GetBonePosition(ent._GetEyePosIDCache)
            if pos then
                return pos
            end
            ent._GetEyePosStrategyCache = nil
        elseif s == "EyePos" then
            local pos = ent:EyePos()
            if pos then
                return pos
            end
            ent._GetEyePosStrategyCache = nil
        elseif s == "Pos" then
            return ent:GetPos()
        end
    end

    local eyesID = ent:LookupAttachment("eyes")
    if eyesID and eyesID ~= 0 and eyesID ~= -1 then
        local attach = ent:GetAttachment(eyesID)
        if attach and attach.Pos then
            ent._GetEyePosStrategyCache = "Attachment"
            ent._GetEyePosIDCache = eyesID
            return attach.Pos
        end
    end

    local headID = ent:LookupBone("ValveBiped.Bip01_Head1")
    if headID then
        local headPos = ent:GetBonePosition(headID)
        if headPos then
            ent._GetEyePosStrategyCache = "Bone"
            ent._GetEyePosIDCache = headID
            return headPos
        end
    end

    local eyePos = ent:EyePos()
    if eyePos then
        ent._GetEyePosStrategyCache = "EyePos"
        return eyePos
    end

    ent._GetEyePosStrategyCache = "Pos"
    return ent:GetPos()
end

function M.getPelvisPos(ent)
    -- 如果之前已缓存骨骼策略，先尝试直接获取
    if ent._GetPelvisPosStrategyCache then
        local s = ent._GetPelvisPosStrategyCache
        if s == "Bone" then
            local pos = ent:GetBonePosition(ent._GetPelvisPosIDCache)
            if pos then return pos end
            ent._GetPelvisPosStrategyCache = nil
        elseif s == "Pos" then
            return ent:GetPos()
        end
    end

    -- 候选骨盆骨骼（按优先级排列）
    local bones = {
        "ValveBiped.Bip01_Pelvis",
        "ValveBiped.Bip01_Pelvis1",
        "ValveBiped.Bip01_Spine",
        "ValveBiped.Bip01_Spine1",
    }

    for _, boneName in ipairs(bones) do
        local boneID = ent:LookupBone(boneName)
        if boneID then
            local pos = ent:GetBonePosition(boneID)
            if pos then
                ent._GetPelvisPosStrategyCache = "Bone"
                ent._GetPelvisPosIDCache = boneID
                return pos
            end
        end
    end

    -- 回退到实体中心
    ent._GetPelvisPosStrategyCache = "Pos"
    return ent:GetPos()
end

return M
