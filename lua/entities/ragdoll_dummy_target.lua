AddCSLuaFile()

ENT.Base = "base_ai"
ENT.Type = "ai"

if CLIENT then return end

-- 加载配置与辅助模块
local CONSTANTS                     = include("npc_monitor/config/constants.lua")
local log                           = include("npc_monitor/logging/log.lua")
local helpers                       = include("npc_monitor/helpers.lua")
local findNearestEntity             = helpers.findNearestEntity
local findRandomEntity              = helpers.findRandomEntity
local getEyePos                     = helpers.getEyePos

-- EDAE 生命周期处理器（用于获取 ragdoll 状态）
local LifeCycleHandler              = include("edae/lch/life_cycle_handler.lua")

local BONE_FALLBACK_ORDER           = include("npc_monitor/config/bones.lua")

local PROXY_MODEL                   = CONSTANTS.RAGDOLL_DUMMY.PROXY_MODEL
local SCALE_1                       = CONSTANTS.RAGDOLL_DUMMY.SCALE
local OFFSET                        = CONSTANTS.RAGDOLL_DUMMY.OFFSET
local MIN_DIST_SUSTAIN_SQR          = CONSTANTS.RAGDOLL_DUMMY.MIN_DIST_SUSTAIN_SQR
local MIN_DIST_ENTER_SQR            = CONSTANTS.RAGDOLL_DUMMY.MIN_DIST_ENTER_SQR
local MAX                           = CONSTANTS.RAGDOLL_DUMMY.RELATIONSHIP_MAX_PRIORITY

local MAX_INIT_DURATION             = CONSTANTS.RAGDOLL_DUMMY.MAX_INIT_DURATION
local EXECUTIONER_SEARCH_INTERVAL   = CONSTANTS.RAGDOLL_DUMMY.EXECUTIONER_SEARCH_INTERVAL
local EXECUTIONER_VALIDATE_INTERVAL = CONSTANTS.RAGDOLL_DUMMY.EXECUTIONER_VALIDATE_INTERVAL
local EXECUTIONER_MAX_FAIL_COUNT    = CONSTANTS.RAGDOLL_DUMMY.EXECUTIONER_MAX_FAIL_COUNT
local EXECUTIONER_TIMEOUT           = CONSTANTS.RAGDOLL_DUMMY.EXECUTIONER_TIMEOUT

local STATE_TO_SEARCH_RADIUS        = CONSTANTS.RAGDOLL_DUMMY.STATE_TO_SEARCH_RADIUS

local REPOSITION_INTERVAL           = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_INTERVAL
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

        local losTr = util.TraceLine({
            start = activePos,
            endpos = groundPos,
            filter = filter,
            mask = MASK_SOLID
        })
        if losTr.Hit then return nil end

        local navArea = navmesh.GetNavArea(groundPos, navBeneathLimit)
        if not navArea then return nil end

        return groundPos
    end

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

    local fallbackGround = tryGetValidGroundPos(activePos)
    if fallbackGround then
        self:SetPos(fallbackGround + Vector(0, 0, 1))
    end
end

function ENT:Init(owner, ragdoll)
    if not IsValid(owner) then return end
    if not IsValid(ragdoll) then return end

    local now = CurTime()

    self._Owner = owner
    self._Ragdoll = ragdoll
    self._LastSearchTime = now + MAX_INIT_DURATION
    self._LastExecutionerCheckTime = now - 1
    self._ExecutionerFailCount = 0
    self._Executioner = nil
    self._ExecutionerAssignedTime = nil

    self._PotentialExecutioners = {}
    self:_TryRefreshPotentialExecutioners()

    self._LastRepositionTime = 0
    self._RepositionAttempt = 0

    self._PositionStrategies = {
        { name = "eye", getPos = function(ragdoll) return getEyePos(ragdoll) end },
    }

    for _, boneName in ipairs(BONE_FALLBACK_ORDER) do
        local bone = boneName
        table.insert(self._PositionStrategies, {
            name = bone,
            getPos = function(ragdoll)
                local boneID = ragdoll:LookupBone(bone)
                if boneID then
                    local pos = ragdoll:GetBonePosition(boneID)
                    if pos then return pos end
                end
                return nil
            end
        })
    end

    self._PositionStrategyIndex = 1
    self._PositionStrategyFailCount = 0
    self._LastPositionStrategyResetTime = now
    self._LastBroadCastTime = now

    self._LastRagdollState = nil
    self._RagdollState = "init"
end

function ENT:_GetActivePosition()
    local ragdoll = self._Ragdoll
    if not IsValid(ragdoll) then return nil end

    local strategies = self._PositionStrategies
    local index = self._PositionStrategyIndex or 1
    local maxAttempts = #strategies
    local attempts = 0

    while attempts < maxAttempts do
        local strategy = strategies[index]
        if strategy then
            local pos = strategy.getPos(ragdoll)
            if pos then
                self._PositionStrategyIndex = index
                return pos
            end
        end
        index = index % maxAttempts + 1
        attempts = attempts + 1
    end

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

function ENT:_UpdateState(ragdoll, now)
    -- 直接获取 EDAE 状态
    local modState = LifeCycleHandler:GetState(ragdoll) or "init"

    if self._LastRagdollState ~= modState then
        local owner = self._Owner
        if IsValid(owner) and owner:IsPlayer() then
            log.trace(ragdoll, "RagdollState: ", self._LastRagdollState or "(none)", " -> ", modState)
        end

        self._LastRagdollState = modState
        self:_ResetPositionStrategy()
    end

    self._RagdollState = modState
    return modState
end

function ENT:Think()
    local now = CurTime()

    local ragdoll = self._Ragdoll
    if not IsValid(ragdoll) then
        self:Remove()
        return
    end

    -- 更新状态，如果死亡则移除 dummy
    local state = self:_UpdateState(ragdoll, now)
    if state == "dead" then
        log.info(self, "Ragdoll entered dead state, removing dummy")
        self:_CancelExecutioner()
        self:Remove()
        return
    end

    local activePos = self:_GetActivePosition()
    if not activePos then
        return
    end

    local function canEnterExecution(npc)
        if not IsValid(npc) then return false end

        local shootPos = npc:GetShootPos() or npc:GetPos()
        if not shootPos then return false end

        if not npc:TestPVS(activePos) then return false end
        if not npc:IsInViewCone(activePos) then return false end
        if not npc:IsLineOfSightClear(activePos) then return false end
        return true
    end

    local function canSustainExecution(npc)
        if not IsValid(npc) then return false end

        local shootPos = npc:GetShootPos() or npc:GetPos()
        if not shootPos then return false end

        if npc:GetEnemy() ~= self then
            return canEnterExecution(npc)
        end

        if not npc:HasCondition(COND.SEE_ENEMY) then return false end
        if npc:HasCondition(COND.WEAPON_BLOCKED_BY_FRIEND) then return false end
        return true
    end

    if IsValid(self._Executioner) then
        if now - self._LastExecutionerCheckTime > EXECUTIONER_VALIDATE_INTERVAL then
            self._LastExecutionerCheckTime = now

            local exec = self._Executioner
            if canSustainExecution(exec) then
                self._ExecutionerFailCount = 0

                if now - self._ExecutionerAssignedTime > EXECUTIONER_TIMEOUT then
                    self:_CancelExecutioner()
                    self:_AdvancePositionStrategy()
                end
            else
                self._ExecutionerFailCount = self._ExecutionerFailCount + 1
                if self._ExecutionerFailCount >= EXECUTIONER_MAX_FAIL_COUNT then
                    self:_CancelExecutioner()
                    self:_AdvancePositionStrategy()
                end
            end
        end

        if IsValid(self._Executioner) then
            local shootPos = self._Executioner:GetShootPos() or self._Executioner:GetPos()

            local tr = util.TraceLine({
                start = shootPos,
                endpos = activePos,
                filter = { self, self._Executioner },
                mask = MASK_SOLID
            })

            local dummyPos
            local toShooter
            if tr.Hit then
                toShooter = (shootPos - tr.HitPos):GetNormalized()
                dummyPos = tr.HitPos + toShooter * OFFSET
            else
                toShooter = (shootPos - activePos):GetNormalized()
                dummyPos = activePos + toShooter * OFFSET
            end

            self:SetPos(dummyPos)
            self:SetAngles(toShooter:Angle())
            return
        end
    end

    if now - self._LastSearchTime > EXECUTIONER_SEARCH_INTERVAL then
        self._LastSearchTime = now

        if state == "init" then
            self:Remove()
            return
        end

        self:_TryRefreshPotentialExecutioners()
        if table.IsEmpty(self._PotentialExecutioners) then
            self:Remove()
            return
        end

        local searchRadius = STATE_TO_SEARCH_RADIUS[state]
        if searchRadius then
            local chosen = findRandomEntity(activePos, searchRadius, self._PotentialExecutioners, canEnterExecution)
            if IsValid(chosen) then
                self._Executioner = chosen
                self._ExecutionerAssignedTime = CurTime()
                self._Executioner:AddEntityRelationship(self, D_HT, MAX)
                self._PositionStrategyFailCount = 0
            else
                self._PositionStrategyFailCount = self._PositionStrategyFailCount + 1
                if self._PositionStrategyFailCount >= EXECUTIONER_MAX_FAIL_COUNT then
                    self:_AdvancePositionStrategy()
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

    if now - self._LastRepositionTime > REPOSITION_INTERVAL then
        self._LastRepositionTime = now
        self:_TryReposition(activePos)
    end

    if now - self._LastPositionStrategyResetTime > POSITION_RESET_INTERVAL then
        self:_ResetPositionStrategy()
    end
end
