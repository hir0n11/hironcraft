local PT = HironCraftProfit

local Tracker = {}
PT.Tracker = Tracker

local trackedItem = nil
Tracker.tomtomUid = nil

function Tracker:GetTrackedItem()
    return trackedItem
end

function Tracker:ClearWaypoints()
    C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    C_Map.ClearUserWaypoint()
    if TomTom and self.tomtomUid then
        TomTom:RemoveWaypoint(self.tomtomUid)
        self.tomtomUid = nil
    end
end

function Tracker:SetWaypointForItem(item)
    self:ClearWaypoints()

    local wp = item.waypoint
    if not wp then return end

    local mapPoint = UiMapPoint.CreateFromCoordinates(wp.map, wp.x, wp.y)
    C_Map.SetUserWaypoint(mapPoint)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)

    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local _, isTomTomLoaded = C_AddOns.IsAddOnLoaded("TomTom")
        if isTomTomLoaded and TomTom then
            local itemName = item:GetName() or "Profession treasure"
            self.tomtomUid = TomTom:AddWaypoint(wp.map, wp.x, wp.y, {
                title      = itemName,
                persistent = false,
                source     = "HironCraftProfit_ProfessionTracker",
            })
        end
    end
end

function Tracker:ToggleTrackedItem(item)
    if trackedItem == item then
        trackedItem.isTracked = false
        trackedItem = nil
        self:ClearWaypoints()
        if PT.RefreshUI then PT:RefreshUI() end
        return
    end

    if trackedItem then
        trackedItem.isTracked = false
    end

    trackedItem = item
    trackedItem.isTracked = true

    self:SetWaypointForItem(item)

    if PT.RefreshUI then
        PT:RefreshUI()
    end
end
