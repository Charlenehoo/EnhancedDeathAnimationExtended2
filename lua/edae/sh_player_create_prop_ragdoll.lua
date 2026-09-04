-- lua/edae/sh_player_create_prop_ragdoll.lua
local MODULE_NAME = "PlayerCreatePropRagdoll"

local Constants = include("edae/config/constants.lua")
local log = include("edae/log/init.lua")

local ORIGIN_OFFSET = Constants.PlayerCreatePropRagdoll.ORIGIN_OFFSET
local ANTI_CLIP_OFFSET = Constants.PlayerCreatePropRagdoll.ANTI_CLIP_OFFSET

local meta = FindMetaTable("Player")
if not meta then
    log.fatal("Cannot find meta table: Player")
    return
end

local originalGetRagdollEntity = meta.GetRagdollEntity
if not originalGetRagdollEntity then
    log.fatal("Cannot find function: Player.GetRagdollEntity")
    return
end

local plyToRagdollMap = {}
meta.GetRagdollEntity = function(self)
    return plyToRagdollMap[self] or originalGetRagdollEntity(self)
end

-- 第一人称死亡视角状态标志
local enableFirstPersonDeathCam = false
local activeOffset = ORIGIN_OFFSET / 2
local activeOffsetSqr = activeOffset * activeOffset

if SERVER then
    local originalCreateRagdoll = meta.CreateRagdoll
    if not originalCreateRagdoll then
        log.fatal("Cannot find function: Player.CreateRagdoll")
        return
    end

    local cleanUp = function(ply)
        local ragdoll = ply:GetRagdollEntity()
        if IsValid(ragdoll) then
            ragdoll:Remove()
        end
        plyToRagdollMap[ply] = nil
        return originalCreateRagdoll(ply)
    end

    meta.CreateRagdoll = function(ply)
        log.trace("Player.CreateRagdoll called for player: ", ply)
        if not IsValid(ply) or not ply:IsPlayer() then
            log.warn("Invalid player: ", ply)
            return originalCreateRagdoll(ply)
        end

        local plyModel = ply:GetModel()
        if not plyModel then
            log.warn("Cannot find model for player: ", ply)
            return originalCreateRagdoll(ply)
        end

        local ragdoll = ents.Create("prop_ragdoll")
        plyToRagdollMap[ply] = ragdoll
        if not IsValid(ragdoll) then
            log.warn("Cannot create ragdoll for player: ", ply)
            return cleanUp(ply)
        end

        ragdoll:SetModel(plyModel)
        local ragdollModel = ragdoll:GetModel()
        if not ragdollModel or ragdollModel ~= plyModel then
            log.warn("Cannot set model for player: ", ply, "; Ragdoll: ", ragdoll)
            return cleanUp(ply)
        end
        ragdoll:Spawn()

        local physicsObjectCount = ragdoll:GetPhysicsObjectCount()
        if not physicsObjectCount or physicsObjectCount < 1 then
            log.warn("Cannot get physics object count for player: ", ply, "; Ragdoll: ", ragdoll)
            return cleanUp(ply)
        end

        for physObjNum = 0, physicsObjectCount - 1 do
            local boneID = ragdoll:TranslatePhysBoneToBone(physObjNum)
            if not boneID then
                log.trace("Cannot translate phys bone to bone for player: ", ply, "; Ragdoll: ", ragdoll,
                    "; PhysObjNum: ", physObjNum)
                continue
            end

            local pos, ang = ply:GetBonePosition(boneID)
            if not pos then
                log.trace("Cannot get bone position for player: ", ply, "; Ragdoll: ", ragdoll, "; BoneID: ", boneID)
                continue
            end

            local physObj = ragdoll:GetPhysicsObjectNum(physObjNum)
            if not physObj then
                log.trace("Cannot get physics object for player: ", ply, "; Ragdoll: ", ragdoll, "; PhysObjNum: ",
                    physObjNum)
                continue
            end

            physObj:SetPos(pos, true)
            physObj:SetAngles(ang)
            physObj:EnableMotion(true)
            physObj:Wake()
        end

        ragdoll.GetRagdollOwner = function(self)
            return ply
        end

        net.Start(Constants.NETWORK_STRING.Ragdoll)
        net.WriteEntity(ragdoll)
        net.Send(ply)

        hook.Run("CreateEntityRagdoll", ply, ragdoll)
        log.trace("Ragdoll created for player: ", ply, "; Ragdoll: ", ragdoll)
        return ragdoll
    end

    hook.Add("PlayerSpawn", Constants.ADDON_NAME .. MODULE_NAME .. "PlayerSpawn", function(player, transition)
        if transition then return end
        plyToRagdollMap[player] = nil
        net.Start(Constants.NETWORK_STRING.PlayerSpawn)
        net.WriteBool(true)
        net.Send(player)
    end)

    hook.Add("PlayerDisconnected", Constants.ADDON_NAME .. MODULE_NAME .. "PlayerDisconnected", function(ply)
        plyToRagdollMap[ply] = nil
    end)
else -- CLIENT
    net.Receive(Constants.NETWORK_STRING.Ragdoll, function()
        local ragdoll = net.ReadEntity()
        plyToRagdollMap[LocalPlayer()] = ragdoll
    end)

    net.Receive(Constants.NETWORK_STRING.PlayerSpawn, function()
        if net.ReadBool() then
            plyToRagdollMap[LocalPlayer()] = nil
        end
    end)

    hook.Add("CreateMove", Constants.ADDON_NAME .. MODULE_NAME .. "CreateMove", function(cmd)
        local ply = LocalPlayer()
        if not IsValid(ply) or ply:Alive() then return end

        local wheel = cmd:GetMouseWheel()
        if wheel == 0 then return end

        activeOffset = math.Clamp(activeOffset - wheel * Constants.PlayerCreatePropRagdoll.PER_WHEEL, ANTI_CLIP_OFFSET,
            ORIGIN_OFFSET)
        activeOffsetSqr = activeOffset * activeOffset

        -- 滚轮缩到最小时进入第一人称模式
        if activeOffset <= ANTI_CLIP_OFFSET and not enableFirstPersonDeathCam then
            enableFirstPersonDeathCam = true
            -- 滚轮放大时退出第一人称模式
        elseif activeOffset > ANTI_CLIP_OFFSET and enableFirstPersonDeathCam then
            enableFirstPersonDeathCam = false
        end
    end)

    hook.Add("CalcView", Constants.ADDON_NAME .. MODULE_NAME .. "CalcView",
        function(ply, origin, angles, fov, znear, zfar)
            if ply:Alive() then return end
            local ragdoll = ply:GetRagdollEntity()
            if not IsValid(ragdoll) then return end

            -- 公用：获取眼睛位置和附件数据
            local eyeAttachID = ragdoll:LookupAttachment("eyes")
            local eyeAttach = (eyeAttachID and eyeAttachID > 0) and ragdoll:GetAttachment(eyeAttachID) or nil
            local ragdollEye = eyeAttach and eyeAttach.Pos or ragdoll:EyePos()
            local ragdollEyeAng = eyeAttach and eyeAttach.Ang or nil

            -- ========== 第一人称死亡视角（固定视角） ==========
            if enableFirstPersonDeathCam then
                -- 使用布娃娃眼睛附件的角度，若不存在则回退到玩家视角角度
                local viewAngles = ragdollEyeAng or angles
                return {
                    origin = ragdollEye,
                    angles = viewAngles,
                    fov = fov,
                    znear = znear,
                    zfar = zfar,
                    drawviewer = false,
                }
            end

            -- ========== 原有第三人称逻辑 ==========
            local dir = -angles:Forward()
            local tr = util.TraceLine({
                start = ragdollEye,
                endpos = ragdollEye + dir * activeOffset,
                filter = { ply, ragdoll },
            })

            local newOrigin
            if tr.Hit then
                local hitPos = tr.HitPos
                local d = ragdollEye.z - hitPos.z

                if d > 0 then
                    local center = Vector(ragdollEye.x, ragdollEye.y, hitPos.z)
                    local horizDir = Vector(dir.x, dir.y, 0)

                    if horizDir:LengthSqr() < 0.0001 then
                        return
                    end

                    horizDir:Normalize()
                    local rCircleSqr = activeOffsetSqr - d * d
                    if hitPos:Distance2DSqr(center) < rCircleSqr then
                        local r_circle = math.sqrt(rCircleSqr)
                        local pointOnCircle = center + horizDir * r_circle
                        newOrigin = pointOnCircle - dir * ANTI_CLIP_OFFSET
                    else
                        newOrigin = hitPos - dir * ANTI_CLIP_OFFSET
                    end
                else
                    newOrigin = hitPos - dir * ANTI_CLIP_OFFSET
                end
            else
                newOrigin = ragdollEye + dir * activeOffset
            end

            local viewAngles = (ragdollEye - newOrigin):Angle()

            return {
                origin = newOrigin,
                angles = viewAngles,
                fov = fov,
                znear = znear,
                zfar = zfar,
                drawviewer = false,
            }
        end)
end
