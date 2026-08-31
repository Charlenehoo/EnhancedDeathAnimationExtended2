local MODULE_NAME = "PlayerCreatePropRagdoll"

local Constants = include("edae/config/constants.lua")
local log = include("edae/log/init.lua")





local playerRagdoll = nil

net.Receive(Constants.NETWORK_STRING.Ragdoll, function()
    local ragdoll = net.ReadEntity()
    playerRagdoll = ragdoll
end)

net.Receive(Constants.NETWORK_STRING.PlayerSpawn, function()
    if net.ReadBool() then
        playerRagdoll = nil
    end
end)

hook.Add("CreateMove", Constants.ADDON_NAME .. MODULE_NAME .. "CreateMove", function(cmd)
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:Alive() then return end

    local wheel = cmd:GetMouseWheel()
    if wheel == 0 then return end

    -- 步长 8，范围限制在 16 ~ 256
    ORIGIN_OFFSET = math.Clamp(ORIGIN_OFFSET - wheel * 8, 16, 256)
    ORIGIN_OFFSET_SQR = ORIGIN_OFFSET * ORIGIN_OFFSET
end)

hook.Add("CalcView", Constants.ADDON_NAME .. MODULE_NAME .. "CalcView", function(ply, origin, angles, fov, znear, zfar)
    if ply:Alive() then return end
    local ragdoll = ply:GetRagdollEntity()
    if not IsValid(ragdoll) then return end

    local ragdollEye
    local eyesID = ragdoll:LookupAttachment("eyes")
    if eyesID and eyesID ~= 0 and eyesID ~= -1 then
        local attach = ragdoll:GetAttachment(eyesID)
        if attach then
            ragdollEye = attach.Pos
        end
    end

    if not ragdollEye then
        ragdollEye = ragdoll:EyePos()
    end

    local dir = -angles:Forward()
    local tr = util.TraceLine({
        start = ragdollEye,
        endpos = ragdollEye + dir * ORIGIN_OFFSET,
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
            local rCircleSqr = ORIGIN_OFFSET_SQR - d * d
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
        newOrigin = ragdollEye + dir * ORIGIN_OFFSET
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
