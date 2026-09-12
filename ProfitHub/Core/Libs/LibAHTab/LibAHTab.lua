local lib = LibStub:NewLibrary("LibAHTab-1-0", 5)

if not lib then return end

local MIN_TAB_WIDTH = 70
local TAB_PADDING = 20
local OFFSET_X = 3
if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
  OFFSET_X = -14
end

local tabIDErrorMessage = "tabID should be a string"

local function SetPointFromTable(frame, anchor)
  if not frame or not anchor or not anchor[1] then return false end
  frame:ClearAllPoints()
  frame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4] or 0, anchor[5] or 0)
  return true
end

local function PositionTabs(state)
  if not state or not state.rootFrame or not AuctionHouseFrame then return end

  local firstAuctionTab = AuctionHouseFrame.Tabs and AuctionHouseFrame.Tabs[1]
  if not firstAuctionTab then return end

  if state.placeBeforeAuctionTabs then
    if not state.auctionTabsOriginalAnchor then
      local point, relativeTo, relativePoint, xOffset, yOffset = firstAuctionTab:GetPoint(1)
      if not point or relativeTo == state.rootFrame then return end
      state.auctionTabsOriginalAnchor = { point, relativeTo, relativePoint, xOffset or 0, yOffset or 0 }
    end

    local anchor = state.auctionTabsOriginalAnchor
    state.rootFrame:ClearAllPoints()
    state.rootFrame:SetPoint(anchor[1], anchor[2], anchor[3], (anchor[4] or 0) - OFFSET_X, anchor[5] or 0)

    local frontTab = state.Tabs[1]
    if frontTab then
      frontTab:ClearAllPoints()
      frontTab:SetPoint("TOPLEFT", state.rootFrame, "TOPLEFT", OFFSET_X, 0)
      firstAuctionTab:ClearAllPoints()
      firstAuctionTab:SetPoint("TOPLEFT", frontTab, "TOPRIGHT", OFFSET_X, 0)

      local previousTab = AuctionHouseFrame.Tabs[#AuctionHouseFrame.Tabs]
      for index = 2, #state.Tabs do
        local tab = state.Tabs[index]
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", previousTab, "TOPRIGHT", OFFSET_X, 0)
        previousTab = tab
      end
    end
  elseif state.auctionTabsOriginalAnchor then
    SetPointFromTable(firstAuctionTab, state.auctionTabsOriginalAnchor)
    state.rootFrame:ClearAllPoints()
    state.rootFrame:SetPoint("TOPLEFT", AuctionHouseFrame.Tabs[#AuctionHouseFrame.Tabs], "TOPRIGHT")
    for index, tab in ipairs(state.Tabs) do
      tab:ClearAllPoints()
      if index == 1 then
        tab:SetPoint("TOPLEFT", state.rootFrame, "TOPLEFT", OFFSET_X, 0)
      else
        tab:SetPoint("TOPLEFT", state.Tabs[index - 1], "TOPRIGHT", OFFSET_X, 0)
      end
    end
  end
end

function lib:DoesIDExist(tabID)
  assert(type(tabID) == "string", tabIDErrorMessage)
  return lib.internalState and lib.internalState.usedIDs[tabID] ~= nil
end

function lib:CreateTab(tabID, attachedFrame, displayText, tabHeader)
  assert(AuctionHouseFrame, "Wait for the AH to open before creating your tab")
  assert(type(tabID) == "string", tabIDErrorMessage)
  assert(type(attachedFrame) == "table" and attachedFrame.IsObjectType and attachedFrame:IsObjectType("Frame"), "attachedFrame should be a frame")
  assert(type(displayText) == "string", "displayText should be a string")
  assert(tabHeader == nil or type(tabHeader) == "string", "tabHeader should be a string")

  if not lib.internalState then
    lib.internalState = {
      Tabs = {},
      usedIDs = {},
      selectedTab = nil,
    }
    lib.internalState.rootFrame = CreateFrame("Frame", nil, AuctionHouseFrame)
    lib.internalState.rootFrame:SetSize(10, 10)
    lib.internalState.rootFrame:SetPoint("TOPLEFT", AuctionHouseFrame.Tabs[#AuctionHouseFrame.Tabs], "TOPRIGHT")

    hooksecurefunc(AuctionHouseFrame, "SetDisplayMode", function(self, mode)
      if mode ~= nil and #mode > 0 then
        for _, tab in ipairs(lib.internalState.Tabs) do
          tab.frameRef:Hide()
          PanelTemplates_DeselectTab(tab)
        end
      end
    end)
  end

  if lib:DoesIDExist(tabID) then
    error("The tab id already exists")
  end

  local newTab = CreateFrame("Button", "LibAHFrame-1.0-" .. tabID, lib.internalState.rootFrame, "AuctionHouseFrameDisplayModeTabTemplate")
  table.insert(lib.internalState.Tabs, newTab)

  newTab:SetText(displayText)

  lib.internalState.usedIDs[tabID] = newTab

  PanelTemplates_TabResize(newTab, TAB_PADDING, nil, MIN_TAB_WIDTH)

  if #lib.internalState.Tabs > 1 then
    newTab:SetPoint("TOPLEFT", lib.internalState.Tabs[#lib.internalState.Tabs - 1], "TOPRIGHT", OFFSET_X, 0)
  else
    newTab:SetPoint("TOPLEFT", lib.internalState.rootFrame, "TOPLEFT", OFFSET_X, 0)
  end
  newTab:SetHitRectInsets((math.abs(OFFSET_X) - 3) / 2, (math.abs(OFFSET_X) - 3) / 2, 0, 0)

  PositionTabs(lib.internalState)

  PanelTemplates_DeselectTab(newTab)

  newTab.frameRef = attachedFrame
  newTab.tabHeader = tabHeader or displayText

  attachedFrame:Hide()

  newTab:SetScript("OnClick", function()
    lib:SetSelected(tabID)
  end)
end

function lib:MoveTabToFront(tabID)
  assert(type(tabID) == "string", tabIDErrorMessage)
  if not lib.internalState or not lib:DoesIDExist(tabID) then return false end

  local selectedTab = lib:GetButton(tabID)
  for index, tab in ipairs(lib.internalState.Tabs) do
    if tab == selectedTab then
      table.remove(lib.internalState.Tabs, index)
      break
    end
  end
  table.insert(lib.internalState.Tabs, 1, selectedTab)
  lib.internalState.placeBeforeAuctionTabs = true
  PositionTabs(lib.internalState)
  return true
end

function lib:RestoreDefaultTabPosition()
  if not lib.internalState then return false end
  lib.internalState.placeBeforeAuctionTabs = false
  PositionTabs(lib.internalState)
  return true
end

function lib:GetButton(tabID)
  assert(type(tabID) == "string", tabIDErrorMessage)
  return lib.internalState.usedIDs[tabID]
end

function lib:SetSelected(tabID)
  assert(type(tabID) == "string", tabIDErrorMessage)
  if lib.internalState == nil or not lib:DoesIDExist(tabID) then
    error("Tab doesn't exist")
  end

  AuctionHouseFrame:SetDisplayMode({})
  AuctionHouseFrame.displayMode = nil

  for _, tab in ipairs(lib.internalState.Tabs) do
    tab.frameRef:Hide()
    PanelTemplates_DeselectTab(tab)
  end

  for _, tab in ipairs(AuctionHouseFrame.Tabs) do
    PanelTemplates_DeselectTab(tab)
  end

  local selectedTab = lib:GetButton(tabID)
  PanelTemplates_SelectTab(selectedTab)

  AuctionHouseFrame:SetTitle(selectedTab.tabHeader)
  selectedTab.frameRef:Show()
end
