local HironCraftScan = select(2, ...)

local function f(s, dict)
    return (s:gsub("{(.-)}", function(key)
        return dict[key] or "{"..key.."}"
    end))
end

HironCraftScan.Utils.FString = f;