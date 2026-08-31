local HironCraftScan = select(2, ...)

HironCraftScan.LOCAL = {}

-- Swap this with the real implementation so anything not localized will stand
-- out as not ~'s.
--[[
---@param ID HironCraftScan.LOCALIZATION_IDS
function HironCraftScan.LOCAL:GetText(ID)
    local result = HironCraftScan.L[ID]
    if result then
        return string.rep("~", #result)
    end
    return nil;
end
]]

function HironCraftScan.LOCAL:Exists(ID)
    return HironCraftScan.L[ID] ~= nil
end

function HironCraftScan.LOCAL:GetText(ID)
    return HironCraftScan.L[ID] or ID
end
