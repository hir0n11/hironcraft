local frames, overrides, sent = {}, {}, {}
local now, combat, focus, typing = 10, false, nil, false
UIParent = {}
CreateFrame = function(_, name)
    local f = { name = name, scripts = {} }
    f.SetScript = function(self, key, fn) self.scripts[key] = fn end
    f.RegisterForClicks = function() end
    f.GetName = function(self) return self.name end
    frames[#frames + 1] = f
    return f
end
GetTime = function() return now end
InCombatLockdown = function() return combat end
GetCurrentKeyBoardFocus = function() return typing and {} or nil end
GetMouseFoci = function() return { focus } end
ClearOverrideBindings = function() overrides = {} end
SetOverrideBindingClick = function(_, _, key, name) overrides[key] = name end
local order = { customerName = 'Buyer', responseID = 1 }
local row = { hironExplanationRow = true, order = order, IsVisible = function() return true end }
local Scan = {
    DB = { settings = { explanations = { Yes = 'Sure', Fix = 'Resend {reagent_issues}' } }, listed_orders = { ['Buyer:1'] = order } },
    LOCAL = { GetText = function(_, s) return s end },
    OrderToOrderID = function(o) return o.customerName .. ':' .. o.responseID end,
    OrderToResponse = function() return {} end,
    CustomExplanations = { Send = function(_, text, target, exactOrder)
        sent[#sent + 1] = { text, target, exactOrder }; return true
    end },
}
assert(loadfile('Customer/ExplanationBindings.lua'))('HironCraft', Scan)
local B = Scan.ExplanationBindings
assert(B.Assign('Yes', 'SHIFT-1'))
assert(not B.Assign('Fix', 'SHIFT-1'), 'duplicate binding overwrote an explanation')
assert(not next(overrides) and not B.Send('Yes'), 'sent without a hovered row')
focus = { GetParent = function() return row end }
frames[1].scripts.OnUpdate(nil, 0.2)
assert(overrides['SHIFT-1'] and #sent == 0, 'hover must only bind, never send')
assert(B.Send('Yes') and sent[1][2] == 'Buyer' and sent[1][3] == order)
assert(not B.Send('Yes') and #sent == 1, 'repeat key bypassed cooldown')
now = 17; typing = true
assert(not B.Send('Yes'), 'typing in an editbox sent a whisper')
typing = false; combat = true
assert(not B.Send('Yes'), 'sent in combat')
combat = false
Scan.DB.listed_orders['Buyer:1'] = nil
assert(not B.Send('Yes'), 'a removed/recycled order was used')
Scan.DB.listed_orders['Buyer:1'] = order
Scan.DB.settings.explanations.OK = 'Sure'
Scan.DB.settings.explanations.Yes = nil
B.Rename('Yes', 'OK')
assert(not B.Key('Yes') and B.Key('OK') == 'SHIFT-1')
B.Remove('OK')
assert(not B.Key('OK') and not next(overrides), 'deletion left a live binding')
print('Explanation hotkeys passed (hover-only, child cells, explicit send, exact context, repeat protection, typing/combat, rename/delete).')
