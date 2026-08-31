AddCSLuaFile()

ENT.Base = "base_ai"
ENT.Type = "ai"

if CLIENT then return end

local CONSTANTS                     = include("npc_monitor/config/constants.lua")
local log                           = include("npc_monitor/logging/log.lua")
local helpers                       = include("npc_monitor/helpers.lua")
local findRandomEntity              = helpers.findRandomEntity
local getEyePos                     = helpers.getEyePos
local getRagdollStateMod            = helpers.getRagdollStateMod
local isRagdollMovingNow            = helpers.isRagdollMovingNow

local BONE_FALLBACK_ORDER           = include("npc_monitor/config/bones.lua")

local PROXY_MODEL                   = CONSTANTS.RAGDOLL_DUMMY.PROXY_MODEL
local SCALE_1                       = CONSTANTS.RAGDOLL_DUMMY.SCALE
local OFFSET                        = CONSTANTS.RAGDOLL_DUMMY.OFFSET
local MAX                           = CONSTANTS.RAGDOLL_DUMMY.RELATIONSHIP_MAX_PRIORITY

local MAX_INIT_DURATION             = CONSTANTS.RAGDOLL_DUMMY.MAX_INIT_DURATION
local EXECUTIONER_SEARCH_INTERVAL   = CONSTANTS.RAGDOLL_DUMMY.EXECUTIONER_SEARCH_INTERVAL
local EXECUTIONER_VALIDATE_INTERVAL = CONSTANTS.RAGDOLL_DUMMY.EXECUTIONER_VALIDATE_INTERVAL
local EXECUTIONER_MAX_FAIL_COUNT    = CONSTANTS.RAGDOLL_DUMMY.EXECUTIONER_MAX_FAIL_COUNT
local EXECUTIONER_TIMEOUT           = CONSTANTS.RAGDOLL_DUMMY.EXECUTIONER_TIMEOUT

local STATE_TO_SEARCH_RADIUS        = CONSTANTS.RAGDOLL_DUMMY.STATE_TO_SEARCH_RADIUS

local REPOSITION_INTERVAL           = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_INTERVAL
-- local REPOSITION_OFFSET_RANGE       = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_OFFSET_RANGE

-- 定期重置回最高优先级策略的时间间隔（秒）
local POSITION_RESET_INTERVAL       = CONSTANTS.RAGDOLL_DUMMY.POSITION_RESET_INTERVAL
local BROAD_CAST_INTERVAL           = 9

function ENT:Initialize()
    self:SetModel(PROXY_MODEL)
    self:SetModelScale(SCALE_1)
    self:SetNPCClass(CLASS_NONE)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:SetNoDraw(true)
end

function ENT:_TryRefreshPotentialExecutioners()
    local owner = self._Owner
    local ragdoll = self._Ragdoll

    if not IsValid(ragdoll) then
        self._PotentialExecutioners = {}
        return
    end

    if IsValid(owner) then
        local newList = {}
        NPCMonitor.ForEachActiveNPC(function(npc)
            if not IsValid(npc) then return end
            local d = npc:Disposition(owner)
            if d == D_HT or d == D_FR then
                table.insert(newList, npc)
            end
        end)
        self._PotentialExecutioners = newList
    else
        local oldList = self._PotentialExecutioners or {}
        local cleaned = {}
        for _, npc in ipairs(oldList) do
            if IsValid(npc) then
                table.insert(cleaned, npc)
            end
        end
        self._PotentialExecutioners = cleaned
    end
end

function ENT:IsPotentialExecutioner(npc)
    if not IsValid(npc) then return false end

    -- 新增：如果 ragdoll 已死或 dummy 自身处于 dead 监控状态，则不作为潜在执行者目标
    if self._LastRagdollState == "dead" then return false end

    local potentials = self._PotentialExecutioners or {}
    for _, p in ipairs(potentials) do
        if p == npc then
            return true
        end
    end
    return false
end

function ENT:_TryReposition(activePos)
    local ragdoll = self._Ragdoll
    local filter = { self }
    if IsValid(ragdoll) then
        table.insert(filter, ragdoll)
    end

    local maxAttempts      = 20
    local rMin             = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_RADIUS_MIN
    local rMax             = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_RADIUS_MAX
    local traceStartHeight = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_TRACE_START_HEIGHT or 100
    local traceEndDepth    = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_TRACE_END_DEPTH or -100
    local navBeneathLimit  = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_NAV_BENEATH_LIMIT or 100

    -- 检查一个水平点是否可作为稳定的地面放置点
    -- 返回：成功时返回地面位置（Vector），失败返回 nil
    local function tryGetValidGroundPos(horizontalPos)
        local traceStart = horizontalPos + Vector(0, 0, traceStartHeight)
        local traceEnd   = horizontalPos + Vector(0, 0, traceEndDepth)

        local groundTr   = util.TraceLine({
            start = traceStart,
            endpos = traceEnd,
            filter = filter,
            mask = MASK_SOLID
        })

        if not groundTr.Hit then return nil end

        local normal = groundTr.HitNormal
        if not normal or normal.z < 0.7 then return nil end

        local groundPos = groundTr.HitPos

        -- 视线检查：activePos 到地面点不能被阻挡
        local losTr = util.TraceLine({
            start = activePos,
            endpos = groundPos,
            filter = filter,
            mask = MASK_SOLID
        })
        if losTr.Hit then return nil end

        -- 导航网格检查
        local navArea = navmesh.GetNavArea(groundPos, navBeneathLimit)
        if not navArea then return nil end

        return groundPos
    end

    -- 随机尝试
    for _ = 1, maxAttempts do
        local theta = math.random() * 2 * math.pi
        local r = rMin + (rMax - rMin) * math.random()
        local horizontalPos = activePos + Vector(r * math.cos(theta), r * math.sin(theta), 0)

        local groundPos = tryGetValidGroundPos(horizontalPos)
        if groundPos then
            self:SetPos(groundPos + Vector(0, 0, 1))
            return
        end
    end

    -- 所有随机尝试失败：尝试直接放在 activePos 正下方的地面
    local fallbackGround = tryGetValidGroundPos(activePos)
    if fallbackGround then
        self:SetPos(fallbackGround + Vector(0, 0, 1))
    end
    -- 如果连脚下都没有稳定地面，则保持原位置不变
end

function ENT:Init(owner, ragdoll)
    if not IsValid(owner) then return end
    if not IsValid(ragdoll) then return end

    local now = CurTime()

    -- ==============================
    -- 实体关联（Owner / Ragdoll）
    -- ==============================
    -- 所有者实体（通常为玩家），用于判断仇恨关系和广播执行者
    self._Owner = owner

    -- 关联的布娃娃实体，dummy 的目标就是模拟其位置
    self._Ragdoll = ragdoll

    -- ==============================
    -- 执行者（Executioner）管理
    -- ==============================
    -- 上次搜索执行者的时间（初始设为 now + MAX_INIT_DURATION，延迟首次搜索）
    self._LastSearchTime = now + MAX_INIT_DURATION

    -- 上次验证执行者的时间（初始设为 now - 1，确保第一次 Think 立即验证）
    self._LastExecutionerCheckTime = now - 1

    -- 执行者验证连续失败次数（用于判断是否需要降级位置策略）
    self._ExecutionerFailCount = 0

    -- 当前指定的执行者 NPC（负责攻击 dummy 的实体）
    self._Executioner = nil

    -- 执行者被指派的时间（用于超时判断）
    self._ExecutionerAssignedTime = nil

    -- 潜在执行者列表（所有对 owner 有仇恨的 NPC）
    self._PotentialExecutioners = {}
    self:_TryRefreshPotentialExecutioners()

    -- ==============================
    -- 重定位（Reposition）控制
    -- ==============================
    -- 上次执行重定位的时间（初始为 0，表示立即可以重定位）
    self._LastRepositionTime = 0

    -- ==============================
    -- 位置提取策略（Position Strategies）
    -- ==============================
    -- 存储所有可行的位置提取策略，按优先级排序（首个为眼睛位置，后续为骨骼）
    self._PositionStrategies = {
        { name = "eye", getPos = function(ragdoll) return getEyePos(ragdoll) end },
    }

    -- 根据准备好的骨骼顺序表构建后续策略
    for _, boneName in ipairs(BONE_FALLBACK_ORDER) do
        local bone = boneName -- 避免闭包捕获循环变量
        table.insert(self._PositionStrategies, {
            name = bone,
            getPos = function(ragdoll)
                local boneID = ragdoll:LookupBone(bone)
                if boneID then
                    local pos = ragdoll:GetBonePosition(boneID)
                    if pos then return pos end
                end
                return nil -- 骨骼不存在或获取失败
            end
        })
    end

    -- 当前使用的位置策略索引（初始为 1，即最高优先级：眼睛）
    self._PositionStrategyIndex = 1

    -- 当前策略连续失败次数（达到阈值会降级到下一个策略）
    self._PositionStrategyFailCount = 0

    -- 上次重置位置策略到最高优先级的时间（用于定期重新尝试眼睛位置）
    self._LastPositionStrategyResetTime = now

    -- ==============================
    -- 广播控制（Broadcast Control）
    -- ==============================
    -- 上次向潜在执行者广播控制请求的时间（用于定期尝试控制空闲 NPC）
    self._LastBroadCastTime = now

    -- ==============================
    -- 死亡状态检测（Death State Detection）
    -- ==============================
    -- 当前由 MOD 内部逻辑推断出的 ragdoll 状态字符串（如 "init"、"falling"、"writhing"、"crawling"、"reviving"、"dead"）
    self._RagdollState = "init"

    -- 上一次的 MOD 状态（用于检测状态变化，触发日志和策略重置）
    self._LastRagdollState = nil

    -- MOD 判定是否死亡（布尔值，来自 getRagdollStateMod 的结果）
    self._modDead = false

    -- 速度判定是否死亡（布尔值，来自骨骼物理速度检测）
    self._velocityDead = false

    -- 连续静止检查计数（速度检测中，连续静止达到阈值则判定死亡）
    self._staticCheckCount = 0

    -- 下一次执行静止检查的时间（用于限制定期检查频率）
    self._nextStaticCheck = 0

    -- 上一次静止检查的结果（true 表示判定为静止）
    self._lastStaticResult = false

    -- 综合死亡状态（上一次的值，用于检测变化并记录日志）
    self._wasDead = false

    -- ==============================
    -- 死亡移除定时器（Death Removal Timer）
    -- ==============================
    -- 存储死亡移除定时器的名称（用于取消定时器），nil 表示无定时器
    self._DeadRemoveTimer = nil
end

function ENT:_GetActivePosition()
    local ragdoll = self._Ragdoll
    if not IsValid(ragdoll) then return nil end

    local strategies = self._PositionStrategies
    local index = self._PositionStrategyIndex or 1
    local maxAttempts = #strategies
    local attempts = 0

    -- 从当前索引开始，依次尝试所有策略，跳过返回 nil 的
    while attempts < maxAttempts do
        local strategy = strategies[index]
        if strategy then
            local pos = strategy.getPos(ragdoll)
            if pos then
                self._PositionStrategyIndex = index
                return pos
            end
        end
        -- 当前策略无效，尝试下一个（循环）
        index = index % maxAttempts + 1
        attempts = attempts + 1
    end

    -- 所有策略都失败，回退到实体坐标
    self._PositionStrategyIndex = 1
    return ragdoll:GetPos()
end

function ENT:_AdvancePositionStrategy()
    if self._PositionStrategyIndex < #self._PositionStrategies then
        self._PositionStrategyIndex = self._PositionStrategyIndex + 1
        log.trace(self, "Position strategy degraded to: ", self._PositionStrategies[self._PositionStrategyIndex].name)
    else
        log.trace(self, "All position strategies exhausted, staying at: ",
            self._PositionStrategies[self._PositionStrategyIndex].name)
    end
    self._PositionStrategyFailCount = 0
end

function ENT:_ResetPositionStrategy()
    if self._PositionStrategyIndex ~= 1 then
        self._PositionStrategyIndex = 1
        self._PositionStrategyFailCount = 0
        self._LastPositionStrategyResetTime = CurTime()
        log.trace(self, "Position strategy reset to eye")
    end
end

function ENT:_CancelExecutioner()
    local exec = self._Executioner
    if IsValid(exec) then
        exec:AddEntityRelationship(self, D_NU, MAX)
        if exec:GetEnemy() == self then
            exec:ClearEnemyMemory()
            exec:SetEnemy(NULL)
        end
    end
    self._Executioner = nil
    self._ExecutionerFailCount = 0
    self._ExecutionerAssignedTime = nil
    self._LastSearchTime = 0
end

function ENT:_UpdateVelocityDead(ragdoll, now)
    local interval = CONSTANTS.RAGDOLL_DUMMY.STATIC_CHECK_INTERVAL or 1
    local consecutiveRequired = CONSTANTS.RAGDOLL_DUMMY.STATIC_CONSECUTIVE_COUNT or 2

    if now >= self._nextStaticCheck then
        local moving = isRagdollMovingNow(ragdoll) -- 纯函数
        if moving then
            self._staticCheckCount = 0
            self._lastStaticResult = false
        else
            self._staticCheckCount = self._staticCheckCount + 1
            self._lastStaticResult = (self._staticCheckCount >= consecutiveRequired)
        end
        self._nextStaticCheck = now + interval
    end

    return self._lastStaticResult
end

function ENT:_UpdateDeathState(ragdoll, now)
    -- 获取 MOD 内部状态
    local modState, decision = getRagdollStateMod(ragdoll)

    -- 状态变化处理（保留原 _GetRagdollState 的日志与重置逻辑）
    if self._LastRagdollState ~= modState then
        local owner = self._Owner
        if IsValid(owner) and owner:IsPlayer() then
            log.trace(ragdoll, "RagdollState: ", self._LastRagdollState or "(none)", " -> ", modState)
            log.trace("  mainStateDecisionMaker=", decision.mainStateDecisionMaker)
            log.trace("  subStateDecisionMaker=", decision.subStateDecisionMaker)
            log.trace("  stateNW=", decision.stateNW)
            log.trace("  inDeath=", decision.inDeath)
            log.trace("  inCrawl=", decision.inCrawl)
            log.trace("  isWrithing=", decision.isWrithing)
            log.trace("  isTwitching=", decision.isTwitching)
            log.trace("  isReviving=", decision.isReviving)
            log.trace("  isDead_c=", decision.isDead_c)
            log.trace("  isDead_d=", decision.isDead_d)
            log.trace("  hp_c=", tostring(decision.hp_c))
            log.trace("  hp_d=", tostring(decision.hp_d))
        end

        self._LastRagdollState = modState
        self:_ResetPositionStrategy()
    end

    -- 保存当前 MOD 状态（供 Think 使用）
    self._RagdollState = modState

    local modDead = (modState == "dead")

    -- 更新速度死亡判定
    local velocityDead = self:_UpdateVelocityDead(ragdoll, now)

    if self._modDead ~= modDead then
        log.trace(self, "ModDead changed: ", self._modDead, " -> ", modDead)
        self._modDead = modDead
    end
    if self._velocityDead ~= velocityDead then
        log.trace(self, "VelocityDead changed: ", self._velocityDead, " -> ", velocityDead)
        self._velocityDead = velocityDead
    end

    -- 综合计数（0~2）
    local deathCount = (modDead and 1 or 0) + (velocityDead and 1 or 0)
    local isDead = deathCount > 0

    if isDead ~= self._wasDead then
        log.info(self, "Overall death state: ", self._wasDead, " -> ", isDead,
            " (modDead=", modDead, ", velocityDead=", velocityDead, ", count=", deathCount, ")")
        self._wasDead = isDead
    end

    return isDead
end

function ENT:_HandleDeathState(isDead, ragdoll)
    if isDead then
        -- 进入死亡：取消执行者并启动移除定时器
        if not self._DeadRemoveTimer then
            self:_CancelExecutioner() -- 解除仇恨和敌人关系
            local timerName = CONSTANTS.PLUGIN_NAME .. self:EntIndex() .. "_" .. CurTime() .. "_" .. math.random()
            self._DeadRemoveTimer = timerName
            timer.Create(timerName, CONSTANTS.RAGDOLL_DUMMY.DEAD_REMOVE_DELAY, 1, function()
                if IsValid(self) then
                    log.info(self, "Removing ragdoll dummy due to death timeout")
                    self:Remove()
                end
            end)
            log.info(self, "Ragdoll entered dead state, starting remove timer")
        end
        return true -- 表示处于死亡状态，跳过后续逻辑
    else
        -- 非死亡：若之前有定时器则取消
        if self._DeadRemoveTimer then
            timer.Remove(self._DeadRemoveTimer)
            self._DeadRemoveTimer = nil
            log.info(self, "Ragdoll revived, cancelled dead remove timer")
        end
        return false
    end
end

function ENT:Think()
    local now = CurTime()

    local ragdoll = self._Ragdoll
    if not IsValid(ragdoll) then
        if self._DeadRemoveTimer then
            timer.Remove(self._DeadRemoveTimer)
            self._DeadRemoveTimer = nil
        end
        self:Remove()
        return
    end

    -- 更新死亡状态（综合 MOD 与速度）
    local isDead = self:_UpdateDeathState(ragdoll, now)

    -- 处理死亡定时器与执行者
    if self:_HandleDeathState(isDead, ragdoll) then
        return -- 死亡状态下不再执行后续逻辑
    end

    local ragdollState = self._RagdollState

    -- 获取当前策略下的活动位置
    local activePos = self:_GetActivePosition()
    if not activePos then
        -- 无法获取有效位置（理论上不会发生，但防止 nil）
        return
    end

    -- 进入检查：手动计算可见性
    local function canEnterExecution(npc)
        if not IsValid(npc) then return false end

        local shootPos = npc:GetShootPos() or npc:GetPos()
        if not shootPos then return false end

        -- if (shootPos - activePos):LengthSqr() < MIN_DIST_ENTER_SQR then return false end

        if not npc:TestPVS(activePos) then return false end
        if not npc:IsInViewCone(activePos) then return false end
        if not npc:IsLineOfSightClear(activePos) then return false end
        return true
    end

    -- 维持检查：执行者已选定，验证其是否仍能有效攻击 dummy
    local function canSustainExecution(npc)
        if not IsValid(npc) then return false end

        local shootPos = npc:GetShootPos() or npc:GetPos()
        if not shootPos then return false end

        -- if (shootPos - activePos):LengthSqr() < MIN_DIST_SUSTAIN_SQR then return false end

        if npc:GetEnemy() ~= self then
            return canEnterExecution(npc)
        end

        if not npc:HasCondition(COND.SEE_ENEMY) then return false end
        if npc:HasCondition(COND.WEAPON_BLOCKED_BY_FRIEND) then return false end
        return true
    end

    -- 执行者存在时的验证与定位
    if IsValid(self._Executioner) then
        if now - self._LastExecutionerCheckTime > EXECUTIONER_VALIDATE_INTERVAL then
            self._LastExecutionerCheckTime = now

            local exec = self._Executioner
            if canSustainExecution(exec) then
                self._ExecutionerFailCount = 0

                if now - self._ExecutionerAssignedTime > EXECUTIONER_TIMEOUT then
                    self:_CancelExecutioner()
                    -- 超时也考虑降级，可能是当前位置无法持续维持
                    self:_AdvancePositionStrategy()
                end
            else
                self._ExecutionerFailCount = self._ExecutionerFailCount + 1
                if self._ExecutionerFailCount >= EXECUTIONER_MAX_FAIL_COUNT then
                    self:_CancelExecutioner()
                    -- 验证连续失败，很可能当前参考点失效，降级
                    self:_AdvancePositionStrategy()
                end
            end
        end

        if IsValid(self._Executioner) then
            local shootPos = self._Executioner:GetShootPos() or self._Executioner:GetPos()

            local tr = util.TraceLine({
                start = shootPos,
                endpos = activePos,
                filter = { self, self._Executioner }, -- 忽略 dummy 自己和执行者自身
                mask = MASK_SOLID
            })

            local dummyPos
            local toShooter
            if tr.Hit then
                -- 射线被 ragdoll 或其他物体阻挡，说明目标点被遮挡
                -- 将 dummy 放置在命中点向执行者方向偏移一小段距离，确保它不被遮挡
                toShooter = (shootPos - tr.HitPos):GetNormalized()
                dummyPos = tr.HitPos + toShooter * OFFSET
            else
                -- 无遮挡，使用原有固定偏移方式（保持旧行为作为回退）
                toShooter = (shootPos - activePos):GetNormalized()
                dummyPos = activePos + toShooter * OFFSET
            end

            self:SetPos(dummyPos)
            self:SetAngles(toShooter:Angle())
            return
        end
    end

    -- 搜索阶段
    if now - self._LastSearchTime > EXECUTIONER_SEARCH_INTERVAL then
        self._LastSearchTime = now

        if ragdollState == "init" then
            self:Remove()
            return
        end

        self:_TryRefreshPotentialExecutioners()
        if table.IsEmpty(self._PotentialExecutioners) then
            self:Remove()
            return
        end

        local searchRadius = STATE_TO_SEARCH_RADIUS[ragdollState]
        if searchRadius then
            local chosen = findRandomEntity(activePos, searchRadius, self._PotentialExecutioners, canEnterExecution)
            if IsValid(chosen) then
                self._Executioner = chosen
                self._ExecutionerAssignedTime = CurTime()
                self._Executioner:AddEntityRelationship(self, D_HT, MAX)
                -- 搜索成功，重置当前策略失败计数
                self._PositionStrategyFailCount = 0
            else
                -- 搜索失败，累计当前策略失败
                self._PositionStrategyFailCount = self._PositionStrategyFailCount + 1
                if self._PositionStrategyFailCount >= EXECUTIONER_MAX_FAIL_COUNT then
                    self:_AdvancePositionStrategy()
                    -- 降级后等待下一搜索周期再尝试，避免同帧重复搜索
                end
            end
        end
    end

    if now - self._LastBroadCastTime > BROAD_CAST_INTERVAL then
        self._LastBroadCastTime = now
        for _, exec in ipairs(self._PotentialExecutioners) do
            NPCMonitor.TryControlNPC(exec)
        end
    end

    -- 重定位（使用当前活动位置）
    if now - self._LastRepositionTime > REPOSITION_INTERVAL then
        self._LastRepositionTime = now
        self:_TryReposition(activePos)
    end

    -- 定期重置策略到最高优先级（给眼睛位置重新尝试的机会）
    if now - self._LastPositionStrategyResetTime > POSITION_RESET_INTERVAL then
        self:_ResetPositionStrategy()
    end
end
