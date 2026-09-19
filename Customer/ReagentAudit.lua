local Scan = select(2, ...)
local Audit = {}
Scan.ReagentAudit = Audit
local MAX_ROWS, MAX_SUPPLIED = 40, 12

local function L(text) return Scan.LOCAL:GetText(text) end
local function Number(value, max)
    if issecretvalue and issecretvalue(value) then return nil end
    value = tonumber(value)
    if not value or value ~= value or value < 0 or value > (max or 1000000) then return nil end
    return math.floor(value)
end
local function Plain(value)
    if (issecretvalue and issecretvalue(value)) or type(value) ~= 'string' then return nil end
    value = value:gsub('|H.-|h(.-)|h', '%1'):gsub('|A.-|a', ''):gsub('|T.-|t', '')
        :gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|cn[%w_]+:', ''):gsub('|r', '')
        :gsub('[%c{}|]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    local limit = math.min(128, #value)
    while limit > 0 and value:byte(limit + 1) and value:byte(limit + 1) >= 128
        and value:byte(limit + 1) < 192 do limit = limit - 1 end
    return value ~= '' and value:sub(1, limit) or nil
end
local function Read(info, key, depth)
    if type(info) ~= 'table' or (depth or 0) > 4 then return nil end
    if info[key] ~= nil then return info[key] end
    for _, child in ipairs({'reagentInfo','reagent','craftingReagentInfo','craftingReagent','item'}) do
        local value = Read(info[child], key, (depth or 0) + 1)
        if value ~= nil then return value end
    end
end
local function ItemName(id)
    local fn = C_Item and C_Item.GetItemNameByID or GetItemInfo
    if fn and id then
        local ok, name = pcall(fn, id)
        if ok then return Plain(name) end
    end
end
local function Quality(id)
    local fn = C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo
    if fn and id then
        local ok, quality = pcall(fn, id)
        local available = ok and not (issecretvalue and issecretvalue(quality))
        quality = available and Number(quality, 10)
        return quality and quality > 0 and quality or nil, available
    end
end
local function IsCustomer(entry)
    local source = Read(entry, 'source')
    local types = Enum and Enum.CraftingOrderReagentSource or {Crafter=2, None=3}
    if (types.Crafter~=nil and source == types.Crafter)
        or (types.None~=nil and source == types.None) then return false end
    for _, flag in ipairs({'providedByCrafter','crafterProvided','isCrafterProvided','providedByPlayer'}) do
        if Read(entry, flag) == true then return false end
    end
    -- The server's order.reagents list is customer-supplied by default; never
    -- read the live transaction or the crafter's inventory for this snapshot.
    return true
end

-- Bounded, plain SavedVariables/linked-account payload. Unknown values stay
-- unknown, not zero; incoming peers cannot inject hyperlinks or executable UI.
function Audit.Sanitize(snapshot)
    if type(snapshot) ~= 'table' or snapshot.version ~= 1 then return nil end
    local result = {version=1, orderID=Number(snapshot.orderID, 1e16),
        recipeID=Number(snapshot.recipeID), capturedAt=Number(snapshot.capturedAt, 1e12),
        complete=snapshot.complete == true, isRecraft=snapshot.isRecraft == true,
        reason=Plain(snapshot.reason), rows={}}
    if not result.orderID or not result.capturedAt or type(snapshot.rows) ~= 'table' then return nil end
    if type(snapshot.quality)=='table' then
        local quality=snapshot.quality
        result.quality={currentQuality=Number(quality.currentQuality,10),
            requestedQuality=Number(quality.requestedQuality,10),skill=Number(quality.skill),
            nextQualitySkill=Number(quality.nextQualitySkill),maxAllowed=Number(quality.maxAllowed),
            concentration=quality.concentration == true}
    end
    for i, row in ipairs(snapshot.rows) do
        if i > MAX_ROWS then result.complete=false; break end
        if type(row) == 'table' then
            local clean = {itemID=Number(row.itemID), name=Plain(row.name),
                required=Number(row.required), known=row.known == true,
                optional=row.optional == true, maxQuality=Number(row.maxQuality,10), supplied={}}
            for j, item in ipairs(type(row.supplied)=='table' and row.supplied or {}) do
                if j > MAX_SUPPLIED then clean.known=false; result.complete=false; break end
                if type(item)=='table' and Number(item.itemID) then
                    clean.supplied[#clean.supplied+1]={itemID=Number(item.itemID), name=Plain(item.name),
                        quantity=Number(item.quantity), quality=Number(item.quality,10),
                        maxQuality=Number(item.maxQuality,10),qualityKnown=item.qualityKnown == true}
                end
            end
            result.rows[#result.rows+1]=clean
        end
    end
    return result
end

function Audit.Capture(order, details)
    if type(order) ~= 'table' or not Number(order.orderID, 1e16) then return nil end
    local snapshot={version=1, orderID=order.orderID, recipeID=order.spellID,
        capturedAt=time(), complete=type(order.reagents)=='table', isRecraft=order.isRecraft == true,
        reason=details and details.reason, quality=details and details.quality, rows={}}
    local schematic
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic and order.spellID then
        local ok, value=pcall(C_TradeSkillUI.GetRecipeSchematic,order.spellID,order.isRecraft==true,order.recipeLevel)
        if ok and type(value)=='table' then schematic=value end
    end
    local slots=schematic and schematic.reagentSlotSchematics
    if type(slots)~='table' then snapshot.complete=false; slots={} end
    local prepared={}
    for index, slot in ipairs(slots) do
        local choices, ids={}, {}
        for _, choice in ipairs(slot.reagents or {}) do
            local id=Number(Read(choice,'itemID'))
            if id and not ids[id] then
                ids[id]=true
                choices[#choices+1]={itemID=id,name=ItemName(id),quality=Quality(id)}
            end
        end
        local optional=slot.required == false or slot.optional == true or slot.isOptional == true
        local types=Enum and Enum.CraftingReagentType or {}
        if slot.required==nil and slot.reagentType~=nil then
            optional=slot.reagentType==types.Modifying or slot.reagentType==types.Finishing
                or slot.reagentType==types.Optional
        end
        local row={itemID=choices[1] and choices[1].itemID,
            name=choices[1] and choices[1].name or Plain(slot.slotInfo and slot.slotInfo.slotText),
            required=Number(slot.quantityRequired), known=type(order.reagents)=='table' and #choices>0,
            optional=optional, supplied={}}
        prepared[#prepared+1]={row=row,choices=choices,ids=ids,slot=slot,index=index}
    end
    for _, entry in ipairs(type(order.reagents)=='table' and order.reagents or {}) do
        local id=Number(Read(entry,'itemID'))
        if id and IsCustomer(entry) then
            local tier,qualityAvailable=Quality(id)
            local supplied={itemID=id,name=ItemName(id),quality=tier,quantity=Number(Read(entry,'quantity'))}
            supplied.qualityKnown=supplied.quality~=nil
            if not supplied.qualityKnown and qualityAvailable and C_Item and C_Item.IsItemDataCachedByID then
                local ok,cached=pcall(C_Item.IsItemDataCachedByID,id)
                supplied.qualityKnown=ok and cached==true
            end
            local dataIndex=Number(Read(entry,'dataSlotIndex'))
            local slotIndex=Number(Read(entry,'slotIndex'))
            local candidates={}
            for _, candidate in ipairs(prepared) do
                if candidate.ids[id] then
                    candidates[#candidates+1]=candidate
                    if (dataIndex and candidate.slot.dataSlotIndex==dataIndex)
                        or (not dataIndex and slotIndex and candidate.slot.slotIndex==slotIndex) then
                        candidates={candidate}; break
                    end
                end
            end
            if #candidates==1 then
                local row=candidates[1].row
                row.supplied[#row.supplied+1]=supplied
                if supplied.quantity==nil then row.known=false end
            else
                -- An ambiguous item must not be counted twice, nor turn its
                -- possible slots into false "missing" accusations.
                for _, candidate in ipairs(candidates) do candidate.row.known=false end
                snapshot.complete=false
                snapshot.rows[#snapshot.rows+1]={itemID=id,name=supplied.name,known=false,
                    optional=true,supplied={supplied}}
            end
        end
    end
    for _, candidate in ipairs(prepared) do
        local row,slot=candidate.row,candidate.slot
        local allRanked,maxQuality=true,0
        for _, choice in ipairs(candidate.choices) do
            if not choice.quality then allRanked=false end
            maxQuality=math.max(maxQuality,choice.quality or 0)
        end
        if not row.optional and allRanked and maxQuality>0 then row.maxQuality=maxQuality end
        for _, supplied in ipairs(row.supplied) do
            if not row.optional then supplied.maxQuality=row.maxQuality
            elseif supplied.name and supplied.quality then
                -- Optional slots contain many unrelated missives/embellishments.
                -- Compare only cached equal-name variants, never another stat.
                local best,known=0,true
                for _, choice in ipairs(candidate.choices) do
                    if not choice.name then known=false end
                    if choice.name==supplied.name then
                        if not choice.quality then known=false end
                        best=math.max(best,choice.quality or 0)
                    end
                end
                if known and best>0 then supplied.maxQuality=best end
            end
        end
        if type(slot.variableQuantities)=='table' and #slot.variableQuantities>0 then
            -- Interchangeable sparks may require different amounts. Compare
            -- only a single selected variant; mixed ratios remain unknown.
            row.required=nil
            local selected=#row.supplied==1 and row.supplied[1].itemID
            for _, variable in ipairs(slot.variableQuantities) do
                if selected and Number(Read(variable,'itemID'))==selected then
                    row.required=Number(Read(variable,'quantity'))
                end
            end
        end
        if not row.optional or #row.supplied>0 then
            if not row.known or (not row.optional and not row.required) then snapshot.complete=false end
            snapshot.rows[#snapshot.rows+1]=row
        end
    end
    return Audit.Sanitize(snapshot)
end

function Audit.GetForOrder(order)
    local fulfillment=Scan.OrderFulfillment
    local status=fulfillment and fulfillment:GetStatus(order)
    if not status or status.status~=fulfillment.Status.Rejected then return nil end
    local snapshot=status.reagentAudit
    if snapshot and tostring(snapshot.orderID)==tostring(status.craftingOrderID) then return snapshot end
end
function Audit.ForResponse(response)
    for _, order in pairs(Scan.DB.listed_orders or {}) do
        if Scan.OrderToResponse(order)==response then return Audit.GetForOrder(order) end
    end
end
local function Name(item)
    return item.name or ItemName(item.itemID) or ('item:'..tostring(item.itemID or '?'))
end
function Audit.Analyze(row)
    local total,known=0,row.known
    local replacements={}
    for _, item in ipairs(row.supplied or {}) do
        if item.quantity==nil then known=false else total=total+item.quantity end
        if item.quantity and item.quantity>0 and item.quality and item.maxQuality
            and item.quality<item.maxQuality then replacements[#replacements+1]=item end
    end
    local missing=known and not row.optional and row.required and math.max(0,row.required-total) or nil
    return known and total or nil,missing,replacements
end
function Audit.MaterialsOK(snapshot)
    if not snapshot or not snapshot.complete or #snapshot.rows==0 then return false end
    for _, row in ipairs(snapshot.rows) do
        local total,missing,replacements=Audit.Analyze(row)
        if not total or (not row.optional and missing==nil) or (missing and missing>0)
            or #replacements>0 then return false end
        for _, item in ipairs(row.supplied) do
            if item.quantity and item.quantity>0
                and (not item.qualityKnown or (item.quality and not item.maxQuality)) then return false end
        end
    end
    return true
end
function Audit.QualityProblem(snapshot, localized)
    local quality=snapshot and snapshot.quality
    if not Audit.MaterialsOK(snapshot) or snapshot.reason~='insufficient_quality'
        or not quality or not quality.currentQuality or not quality.requestedQuality
        or quality.currentQuality>=quality.requestedQuality then return nil end
    local function text(key) return localized and L(key) or key end
    local message=string.format(text('Your materials are complete and at maximum tier. The game calculates T%d instead of T%d with my current skill/settings.'),
        quality.currentQuality,quality.requestedQuality)
    if snapshot.isRecraft then
        message=message..' '..text('Possible recraft calculation issue; replacing your materials is not indicated.')
    end
    return message
end
function Audit.Issues(snapshot, localized)
    local function text(key) return localized and L(key) or key end
    local issues={}
    local qualityProblem=Audit.QualityProblem(snapshot,localized)
    if qualityProblem then return qualityProblem end
    if snapshot then
        for _, row in ipairs(snapshot.rows) do
            local _,missing,replacements=Audit.Analyze(row)
            if missing and missing>0 then
                issues[#issues+1]=string.format(text('Missing: %dx %s'),missing,Name(row))
                    ..(row.maxQuality and (' (T'..row.maxQuality..')') or '')
            end
            for _, item in ipairs(replacements) do
                issues[#issues+1]=string.format(text('Replace: %dx %s T%d -> T%d'),
                    item.quantity,Name(item),item.quality,item.maxQuality)
            end
        end
    end
    if #issues==0 then
        return snapshot and text('No specific missing or lower-tier materials could be confirmed; please recheck the order.')
            or text('The declined order reagent details were not recorded; please recheck the materials.')
    end
    if snapshot.complete~=true then issues[#issues+1]=text('Some reagent data was unavailable; please recheck the remaining materials.') end
    return table.concat(issues,'; ')
end

function Audit.ShowTooltip(owner, name, history, snapshot)
    if not snapshot then
        if owner.reagentTooltip then owner.reagentTooltip:Hide() end
        return
    end
    local tip=owner.reagentTooltip
    if not tip then
        tip=CreateFrame('GameTooltip',name..'Reagents',UIParent,'GameTooltipTemplate')
        tip:SetClampedToScreen(true)
        owner.reagentTooltip=tip
    end
    tip:SetOwner(history,'ANCHOR_NONE');tip:ClearLines();tip:SetMinimumWidth(300)
    tip:AddLine(L('Customer reagents at decline'),1,0.82,0)
    tip:AddLine('#'..tostring(snapshot.orderID)..' - '..date('%d.%m %H:%M',snapshot.capturedAt),0.7,0.7,0.7)
    local qualityProblem=Audit.QualityProblem(snapshot,true)
    if qualityProblem then tip:AddLine(qualityProblem,1,0.65,0.1,true) end
    local quality=snapshot.quality
    if quality and quality.skill and quality.nextQualitySkill then
        tip:AddLine(string.format(L('Skill: %d; next quality threshold: %d'),quality.skill,quality.nextQualitySkill),1,1,1,true)
    end
    if quality and quality.maxAllowed then
        tip:AddLine(string.format(L('Configured finishing-reagent skill limit: +%d'),quality.maxAllowed),0.7,0.7,0.7,true)
    end
    local lines=0
    for _, row in ipairs(snapshot.rows) do
        if lines>=14 then tip:AddLine(L('More materials are saved in this order snapshot.'),0.7,0.7,0.7,true);break end
        local total,missing,replacements=Audit.Analyze(row)
        local bad=missing and missing>0 or #replacements>0
        tip:AddDoubleLine(Name(row),tostring(total or '?')..(not row.optional and (' / '..tostring(row.required or '?')) or ''),
            1,1,1,bad and 1 or 0.4,bad and 0.35 or 1,0.3)
        local parts={}
        for _, item in ipairs(row.supplied) do
            parts[#parts+1]=tostring(item.quantity or '?')..'x '..Name(item)
                ..(item.quality and (' T'..item.quality) or '')
        end
        if #parts>0 then tip:AddLine(table.concat(parts,', '),0.75,0.75,0.75,true) end
        if missing and missing>0 then tip:AddLine(string.format(L('Missing: %dx %s'),missing,Name(row)),1,0.3,0.3,true) end
        for _, item in ipairs(replacements) do
            tip:AddLine(string.format(L('Replace: %dx %s T%d -> T%d'),item.quantity,Name(item),item.quality,item.maxQuality),1,0.65,0.1,true)
        end
        lines=lines+1
    end
    if not snapshot.complete then tip:AddLine(L('Some reagent data was unavailable; please recheck the remaining materials.'),1,0.65,0.1,true) end
    tip:AddLine(L('Highest-tier materials alone do not guarantee maximum craft quality.'),0.7,0.7,0.7,true)
    tip:Show();tip:ClearAllPoints()
    local width=tip:GetWidth()
    if (history:GetLeft() or 0)>=width+8 then
        tip:SetPoint('TOPRIGHT',history,'TOPLEFT',-8,0)
    elseif (history:GetRight() or 0)+width+8<=UIParent:GetWidth() then
        tip:SetPoint('TOPLEFT',history,'TOPRIGHT',8,0)
    else tip:SetPoint('TOPLEFT',history,'BOTTOMLEFT',0,-8) end
end

_G.HironCraft = _G.HironCraft or {}
_G.HironCraft.CaptureCraftingOrderReagents = Audit.Capture
