local PT = HironCraftProfit
if not PT then return end

local BLIZZ_ESC_FRAMES = {
    "AuctionHouseFrame", "BankFrame", "MerchantFrame", "MailFrame",
    "ProfessionsFrame", "TradeSkillFrame", "GossipFrame", "QuestFrame",
    "TradeFrame", "ClassTrainerFrame", "GuildBankFrame", "VoidStorageFrame",
    "ScrappingMachineFrame", "CharacterFrame", "BankPanel", "AccountBankPanel",
}

local function anyBlizzOpen()
    for _, name in ipairs(BLIZZ_ESC_FRAMES) do
        local fr = _G[name]
        if fr and fr.IsShown and fr:IsShown() then return true end
    end
    return false
end

local stack = {}

local function topVisible()
    for i = #stack, 1, -1 do
        local fr = stack[i]
        if fr and fr:IsShown() then return fr end
    end
    return nil
end

local function promote(frame)
    for i = #stack, 1, -1 do
        if stack[i] == frame then table.remove(stack, i) end
    end
    stack[#stack + 1] = frame
end

local catcher
local function updateCatcher()
    if catcher then catcher:EnableKeyboard(topVisible() ~= nil) end
end

local function ensureCatcher()
    if catcher then return end
    catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetFrameStrata("TOOLTIP")
    catcher:EnableKeyboard(false)
    catcher:SetPropagateKeyboardInput(true)
    catcher:SetScript("OnKeyDown", function(self, key)
        if key ~= "ESCAPE" then
            self:SetPropagateKeyboardInput(true)
            return
        end
        if anyBlizzOpen() then
            self:SetPropagateKeyboardInput(true)
            return
        end
        local t = topVisible()
        if t then
            self:SetPropagateKeyboardInput(false)
            t:Hide()
            updateCatcher()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    catcher:Show()
end

function PT:RegisterEscClose(frame)
    if type(frame) == "string" then frame = _G[frame] end
    if not frame or not frame.HookScript then return end
    ensureCatcher()

    local name = frame.GetName and frame:GetName()
    if name and UISpecialFrames then
        for i = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[i] == name then table.remove(UISpecialFrames, i) end
        end
    end

    if not frame.__ahuiEsc then
        frame.__ahuiEsc = true
        frame:HookScript("OnShow", function(self) promote(self); updateCatcher() end)
        frame:HookScript("OnMouseDown", function(self) promote(self); updateCatcher() end)
        frame:HookScript("OnHide", function() updateCatcher() end)
    end

    if frame:IsShown() then promote(frame); updateCatcher() end
end
