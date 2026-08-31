local helper = {}

function helper.GetStandPosByBone(ent)
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

function helper.GetGroundPosByTrace(pos)
    local startPos = pos + Vector(0, 0, 100)
    local endPos = startPos - Vector(0, 0, 200)
    local trace = util.TraceLine({
        start = startPos,
        endpos = endPos,
        mask = MASK_SOLID_BRUSHONLY,
    })
    if trace.Hit then
        return trace.HitPos
    end
    return pos
end

function helper.GetStandPos(ent)
    if not IsValid(ent) then return end

    local standPos

    standPos = helper.GetStandPosByBone(ent)
    if standPos then return standPos end

    return ent:GetPos()
end

return helper
