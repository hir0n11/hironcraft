local HironCraftScan = select(2, ...)

function HironCraftScan.MakeTextWhite(text)
    return "|cFFFFFFFF" .. text .. "|r";
end

function HironCraftScan.GameTooltip_AddWhite(left)
    GameTooltip:AddLine(left, 255, 255, 255, true)
end

function HironCraftScan.GameTooltip_AddDoubleWhite(left, right)
    GameTooltip:AddDoubleLine(left, right, 255, 255, 255, 255, 255, 255)
end
