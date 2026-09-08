-- lua/edae/core/bone_control_manager.lua
-- 骨骼控制管理器：合作式骨骼占用与抢占。
-- 特点：
--   - 每个占用者可提供一个活动性谓词（如协程是否存活）。
--   - 低优先级请求不会丢失，会记录在等待队列中，当高优先级释放或失效时自动授予。
--   - 后台协程定期检查当前占用者是否活动，并自动转让。
--   - 使用 EntityDataStore 将数据存储在 ragdoll 实体上，随实体销毁自动清理。
-- 使用方式：
--   BoneControlManager:RequestBones(ragdoll, ownerID, bones, priority, isActiveFunc, onGranted, onLost)

local MODULE_NAME = "BoneControlManager"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local EntityDataStore            = include("edae/core/entity_data_store.lua")
local log                        = include("edae/core/log/init.lua")
local Scheduler                  = include("edae/core/coroutine_scheduler.lua")

local store                      = EntityDataStore:ForOwner(MODULE_NAME)

local BONE_RECORDS_KEY           = "BoneControlRecords"

local BoneControlManager         = {}

-- 后台检查间隔（秒）
BoneControlManager.checkInterval = 3

-- 活跃 ragdoll 集合（用于后台协程遍历）
local activeRagdolls             = {}

---@class BoneWaiter
---@field ownerID string|number 等待者标识
---@field priority number 优先级，数字越大越高
---@field isActiveFunc fun(ownerID: string|number, boneName: string): boolean 活动性谓词
---@field onGranted fun(ownerID: string|number, boneName: string)|nil 获得骨骼时回调
---@field onLost fun(ownerID: string|number, boneName: string)|nil 失去骨骼时回调

---@class BoneControlRecord
---@field ownerID string|number 当前占用者标识
---@field priority number 当前占用者优先级
---@field isActiveFunc fun(ownerID: string|number, boneName: string): boolean 当前占用者活动性谓词
---@field onLost fun(ownerID: string|number, boneName: string)|nil 当前占用者失去时回调
---@field waiters BoneWaiter[] 等待队列，按优先级降序排列

-- ============================================================
-- 内部辅助函数
-- ============================================================

--- 获取指定 ragdoll 的骨骼记录表（若不存在则创建）
---@param ragdoll Entity
---@return table<string, BoneControlRecord>|nil
local function GetBoneRecordsTable(ragdoll)
    if not IsValid(ragdoll) then return nil end
    local records = store:Get(ragdoll, BONE_RECORDS_KEY)
    if not records then
        records = {}
        store:Set(ragdoll, BONE_RECORDS_KEY, records)
    end
    return records
end

--- 默认活动性谓词：始终活动
---@param ownerID string|number
---@param boneName string
---@return boolean
local function DefaultIsActive(ownerID, boneName)
    return true
end

--- 检查占用者是否仍然活动（如果没有提供谓词则默认活动）
---@param record BoneControlRecord
---@param boneName string
---@return boolean
local function IsRecordActive(record, boneName)
    if not record or not record.ownerID then return false end
    local isActive = record.isActiveFunc or DefaultIsActive
    local ok, result = pcall(isActive, record.ownerID, boneName)
    if not ok then
        log.warn("BoneControlManager: isActiveFunc error for owner ", record.ownerID, " on bone ", boneName, ": ", result)
        return false
    end
    return result == true
end

--- 将等待者按优先级降序插入等待队列
---@param waiters BoneWaiter[]
---@param waiter BoneWaiter
local function InsertWaiter(waiters, waiter)
    local inserted = false
    for i, existing in ipairs(waiters) do
        if waiter.priority > existing.priority then
            table.insert(waiters, i, waiter)
            inserted = true
            break
        end
    end
    if not inserted then
        table.insert(waiters, waiter)
    end
end

--- 处理骨骼的占用转让（当占用者失效或主动释放时调用）
--- 从等待队列中按优先级降序移除所有失效的等待者，直到找到第一个有效的并授予。
---@param records table<string, BoneControlRecord>
---@param boneName string
local function ProcessNextWaiter(records, boneName)
    local record = records[boneName]
    if not record then return end

    -- 清空当前占用者（如果存在）
    if record.ownerID then
        if record.onLost then
            record.onLost(record.ownerID, boneName)
        end
        record.ownerID = nil
        record.priority = nil
        record.isActiveFunc = nil
        record.onLost = nil
    end

    -- 从等待队列头部开始，逐个检查并移除失效的等待者
    local waiters = record.waiters
    while #waiters > 0 do
        local waiter = waiters[1] -- 队首是当前优先级最高的

        -- 检查该等待者是否仍然有效
        local isActive = waiter.isActiveFunc or DefaultIsActive
        local ok, result = pcall(isActive, waiter.ownerID, boneName)

        if ok and result == true then
            -- 找到有效的等待者，授予控制权
            table.remove(waiters, 1) -- 从队列中移除
            record.ownerID      = waiter.ownerID
            record.priority     = waiter.priority
            record.isActiveFunc = waiter.isActiveFunc or DefaultIsActive
            record.onLost       = waiter.onLost
            if waiter.onGranted then
                waiter.onGranted(waiter.ownerID, boneName)
            end
            return
        else
            -- 无效，移除并继续检查下一个
            table.remove(waiters, 1)
            if not ok then
                log.warn("BoneControlManager: isActiveFunc error for owner ", waiter.ownerID, " on bone ", boneName, ": ",
                    result)
            end
        end
    end

    -- 如果循环结束仍未找到有效等待者，队列已清空，不进行任何授予
end

-- ============================================================
-- 后台定期检查
-- ============================================================

--- 检查所有活跃 ragdoll 的骨骼占用者活动性
local function CheckAllRagdolls()
    for ragdoll in pairs(activeRagdolls) do
        if not IsValid(ragdoll) then
            activeRagdolls[ragdoll] = nil
            store:Clear(ragdoll) -- 清理实体上的数据
            continue
        end

        local records = GetBoneRecordsTable(ragdoll)
        if not records then
            activeRagdolls[ragdoll] = nil
            continue
        end

        -- 找出失效的骨骼
        local expiredBones = {}
        for boneName, record in pairs(records) do
            if not IsRecordActive(record, boneName) then
                table.insert(expiredBones, boneName)
            end
        end

        -- 处理失效骨骼
        for _, boneName in ipairs(expiredBones) do
            ProcessNextWaiter(records, boneName)
        end
    end
end

-- 启动后台检查协程
Scheduler:Start(function()
    while true do
        Scheduler:Wait(BoneControlManager.checkInterval)
        CheckAllRagdolls()
    end
end)

-- ============================================================
-- 公共接口
-- ============================================================

--- 申请一组骨骼的控制权（合作式）
--- 若骨骼空闲，立即授予；若当前占用者优先级较低，则抢占；若优先级不够，则加入等待队列。
--- 当前占用者失效时会自动释放并授予等待队列中的最高优先级者。
---@param ragdoll Entity 布娃娃实体
---@param ownerID string|number 申请者唯一标识
---@param bones table<string, boolean> 请求的骨骼名称集合
---@param priority number 优先级，数字越大越高
---@param isActiveFunc fun(ownerID: string|number, boneName: string): boolean|nil 申请者活动性谓词，用于判断是否还活跃（如协程是否存活）
---@param onGranted fun(ownerID: string|number, boneName: string)|nil 成功获得骨骼时回调
---@param onLost fun(ownerID: string|number, boneName: string)|nil 将来失去骨骼时回调（被抢占或主动释放时调用）
---@param onDeny fun(ownerID: string|number, boneName: string)|nil 初次申请被拒绝（即未立即获得控制权）时回调
---@return table<string, boolean> 实际立即成功占用的骨骼集合
function BoneControlManager:RequestBones(ragdoll, ownerID, bones, priority, isActiveFunc, onGranted, onLost, onDeny)
    if not IsValid(ragdoll) or not ownerID or not bones or not priority then
        log.warn("BoneControlManager:RequestBones - invalid arguments")
        return {}
    end

    local records = GetBoneRecordsTable(ragdoll)
    if not records then return {} end

    -- 记录活跃 ragdoll
    activeRagdolls[ragdoll] = true

    local acquired = {}
    isActiveFunc = isActiveFunc or DefaultIsActive

    for boneName, _ in pairs(bones) do
        local record = records[boneName]

        -- 情况1：骨骼空闲，直接授予
        if not record or not record.ownerID then
            record = {
                ownerID      = ownerID,
                priority     = priority,
                isActiveFunc = isActiveFunc,
                onLost       = onLost,
                waiters      = {},
            }
            records[boneName] = record
            acquired[boneName] = true
            if onGranted then
                onGranted(ownerID, boneName)
            end
        else
            -- 检查当前占用者是否活动
            if not IsRecordActive(record, boneName) then -- 当前占用者失效，处理转让
                ProcessNextWaiter(records, boneName)
                -- 重新获取记录（可能已被修改）
                record = records[boneName]

                if not record.ownerID then
                    -- 授予当前申请者
                    record.ownerID      = ownerID
                    record.priority     = priority
                    record.isActiveFunc = isActiveFunc
                    record.onLost       = onLost
                    acquired[boneName]  = true
                    if onGranted then
                        onGranted(ownerID, boneName)
                    end
                elseif record.ownerID == ownerID then
                    acquired[boneName] = true
                    if onGranted then
                        onGranted(ownerID, boneName)
                    end
                else
                    -- 被更高优先级等待者获得，当前申请者加入等待队列并触发 onDeny
                    local waiter = {
                        ownerID      = ownerID,
                        priority     = priority,
                        isActiveFunc = isActiveFunc,
                        onGranted    = onGranted,
                        onLost       = onLost,
                    }
                    InsertWaiter(record.waiters, waiter)
                    if onDeny then
                        onDeny(ownerID, boneName)
                    end
                end
            elseif record.ownerID == ownerID then -- 自己已占用，视为成功
                acquired[boneName] = true
                if onGranted then
                    onGranted(ownerID, boneName)
                end
            elseif record.priority < priority then -- 抢占：当前占用者优先级较低
                local oldOwnerID    = record.ownerID
                local oldOnLost     = record.onLost

                -- 将旧占用者放入等待队列
                local oldWaiter     = {
                    ownerID      = oldOwnerID,
                    priority     = record.priority,
                    isActiveFunc = record.isActiveFunc or DefaultIsActive,
                    onGranted    = nil,
                    onLost       = oldOnLost,
                }

                -- 更新当前占用者
                record.ownerID      = ownerID
                record.priority     = priority
                record.isActiveFunc = isActiveFunc
                record.onLost       = onLost

                -- 将旧占用者插入等待队列
                InsertWaiter(record.waiters, oldWaiter)

                acquired[boneName] = true
                if onGranted then
                    onGranted(ownerID, boneName)
                end
                if oldOnLost then
                    oldOnLost(oldOwnerID, boneName)
                end
                log.trace("BoneControlManager: owner ", ownerID, " preempted bone ", boneName, " from ", oldOwnerID)
            else -- 优先级不够，加入等待队列并触发 onDeny
                local waiter = {
                    ownerID      = ownerID,
                    priority     = priority,
                    isActiveFunc = isActiveFunc,
                    onGranted    = onGranted,
                    onLost       = onLost,
                }
                InsertWaiter(record.waiters, waiter)
                if onDeny then
                    onDeny(ownerID, boneName)
                end
                log.trace("BoneControlManager: owner ", ownerID, " queued for bone ", boneName)
            end
        end
    end

    return acquired
end

--- 释放一组骨骼的控制权（由指定所有者主动释放）
--- 释放后会从等待队列中挑选最高优先级且活动的申请者授予。
---@param ragdoll Entity
---@param ownerID string|number
---@param bones table<string, boolean>
function BoneControlManager:ReleaseBones(ragdoll, ownerID, bones)
    if not IsValid(ragdoll) or not ownerID or not bones then return end

    local records = GetBoneRecordsTable(ragdoll)
    if not records then return end

    for boneName, _ in pairs(bones) do
        local record = records[boneName]
        if record and record.ownerID == ownerID then
            ProcessNextWaiter(records, boneName)
        end
    end
end

--- 释放指定所有者在某个 ragdoll 上占用的所有骨骼
---@param ragdoll Entity
---@param ownerID string|number
function BoneControlManager:ReleaseAllBones(ragdoll, ownerID)
    if not IsValid(ragdoll) or not ownerID then return end

    local records = GetBoneRecordsTable(ragdoll)
    if not records then return end

    local toRemove = {}
    for boneName, record in pairs(records) do
        if record.ownerID == ownerID then
            table.insert(toRemove, boneName)
        end
    end

    for _, boneName in ipairs(toRemove) do
        self:ReleaseBones(ragdoll, ownerID, { [boneName] = true })
    end
end

--- 查询某个骨骼当前由哪个所有者占用
---@param ragdoll Entity
---@param boneName string
---@return string|number|nil
function BoneControlManager:GetOwner(ragdoll, boneName)
    if not IsValid(ragdoll) then return nil end
    local records = GetBoneRecordsTable(ragdoll)
    if records and records[boneName] then
        return records[boneName].ownerID
    end
    return nil
end

--- 清理指定 ragdoll 的所有骨骼占用记录（当布娃娃被删除时调用）
---@param ragdoll Entity
function BoneControlManager:CleanupRagdoll(ragdoll)
    if not IsValid(ragdoll) then return end
    store:Clear(ragdoll)
    activeRagdolls[ragdoll] = nil
    log.trace("BoneControlManager:CleanupRagdoll - cleared records for ragdoll ", ragdoll)
end

-- ============================================================
-- 注册单例
-- ============================================================
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = BoneControlManager
return BoneControlManager
