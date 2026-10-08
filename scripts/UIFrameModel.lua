-- Execute the real widget factories against a small frame model. This catches
-- reparenting/anchor regressions without claiming to emulate protected WoW APIs.
if not setfenv then
    function setfenv(fn, env)
        if type(fn) == 'number' then fn = debug.getinfo(fn + 1, 'f').func end
        for i = 1, 100 do
            local name = debug.getupvalue(fn, i)
            if not name then break end
            if name == '_ENV' then
                debug.upvaluejoin(fn, i, function() return env end, 1)
                break
            end
        end
        return fn
    end
end
local frames, methods = {}, {}
local function noop() end
local function frame(kind, parent, template)
    local f = setmetatable({ kind = kind, parent = parent, template = template, anchors = {}, scripts = {}, visible = true }, { __index = methods })
    frames[#frames + 1] = f
    if template == 'UIPanelScrollFrameTemplate' then f.ScrollBar = frame('Slider', f) end
    return f
end
function methods:CreateFontString(_, _, template) return frame('FontString', self, template) end
function methods:CreateTexture() return frame('Texture', self) end
function methods:CreateLine() return frame('Line', self) end
function methods:SetStartPoint(point, relative, x, y) self.startPoint = {point, relative, x, y} end
function methods:SetEndPoint(point, relative, x, y) self.endPoint = {point, relative, x, y} end
function methods:SetThickness(value) self.thickness = value end
function methods:SetPoint(point, relative, relativePoint, x, y)
    if type(relative) == 'number' then x, y, relative, relativePoint = relative, relativePoint, self.parent, point end
    relative, relativePoint = relative or self.parent, relativePoint or point
    self.anchors[point] = { relative, relativePoint, x or 0, y or 0 }
end
function methods:ClearAllPoints() self.anchors = {} end
function methods:SetAllPoints(other)
    self:ClearAllPoints()
    self:SetPoint('TOPLEFT', other or self.parent, 'TOPLEFT', 0, 0)
    self:SetPoint('BOTTOMRIGHT', other or self.parent, 'BOTTOMRIGHT', 0, 0)
end
function methods:SetSize(w, h) self.w, self.h = w, h end
function methods:SetWidth(w) self.w = w end
function methods:SetHeight(h) self.h = h end
local factors = { TOPLEFT={0,0},TOP={.5,0},TOPRIGHT={1,0},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,1},BOTTOM={.5,1},BOTTOMRIGHT={1,1} }
local function bounds(f)
    if not f then return 0, 0, 0, 0 end
    local w, h = f.w or 0, f.h or (f.kind == 'FontString' and 14 or 0)
    if f.kind == 'FontString' and not f.w then w = utf8.len(f.text or '') * 6 end
    local points = {}
    for point, a in pairs(f.anchors) do
        local x0, y0, w0, h0 = bounds(a[1])
        local r, p = factors[a[2]], factors[point]
        points[#points+1] = { x0 + r[1]*w0 + a[3], y0 + r[2]*h0 - a[4], p[1], p[2] }
    end
    if #points == 0 then
        local x, y = bounds(f.parent)
        return x, y, w, h
    end
    local a = points[1]
    for i=2,#points do
        local b = points[i]
        if math.abs(b[3]-a[3]) == 1 then w = (b[1]-a[1])/(b[3]-a[3]) end
        if math.abs(b[4]-a[4]) == 1 then h = (b[2]-a[2])/(b[4]-a[4]) end
    end
    return a[1]-a[3]*w, a[2]-a[4]*h, w, h
end
function methods:GetWidth() local _,_,w = bounds(self); return w end
function methods:GetHeight() local _,_,_,h = bounds(self); return h end
function methods:GetParent() return self.parent end
function methods:SetParent(parent) self.parent = parent end
function methods:SetScale(scale) self.scale = scale end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:GetEffectiveScale() return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetFrameStrata(strata) self.strata = strata end
function methods:GetFrameStrata() return self.strata or 'MEDIUM' end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:GetAlpha() return self.alpha or 1 end
function methods:GetObjectType() return self.kind end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetFrameLevel(level) self.level = level end
function methods:SetText(text) self.text = tostring(text or '') end
function methods:GetText() return self.text end
function methods:SetTextColor(r,g,b,a) self.color = {r,g,b,a or 1} end
function methods:SetColorTexture(r,g,b,a) self.color = {r,g,b,a or 1} end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetAtlas(texture) self.texture = texture end
function methods:SetBackdrop(value) self.backdrop = value end
function methods:SetBackdropColor(r,g,b,a) self.fill = {r,g,b,a} end
function methods:SetBackdropBorderColor(r,g,b,a) self.border = {r,g,b,a} end
function methods:SetFont(path, size) self.fontPath, self.fontSize = path, size end
function methods:SetFontObject() self.fontPath, self.fontSize = STANDARD_TEXT_FONT, 12 end
function methods:SetJustifyH(value) self.justify = value end
function methods:SetJustifyV(value) self.justifyV = value end
function methods:GetStringWidth() return utf8.len(self.text or '') * 6 end
function methods:GetUnboundedStringWidth()
    local plain, textureCount = (self.text or ''):gsub('|T.-|t', '')
    return #plain * 7 + textureCount * 13
end
function methods:SetWordWrap(value) self.wordWrap = value end
function methods:SetMaxLines(value) self.maxLines = value end
function methods:GetFontString()
    self.fontString = self.fontString or frame('FontString', self)
    return self.fontString
end
for _, kind in ipairs({'Normal','Pushed','Disabled','Highlight'}) do
    methods['Set'..kind..'Texture'] = function(self, path)
        self[kind..'Texture'] = self[kind..'Texture'] or frame('Texture', self)
        self[kind..'Texture']:SetTexture(path)
    end
    methods['Get'..kind..'Texture'] = function(self) return self[kind..'Texture'] end
end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:HookScript(event, fn)
    local previous = self.scripts[event]
    self.scripts[event] = function(...) if previous then previous(...) end; fn(...) end
end
function methods:Click() if self.scripts.OnClick then self.scripts.OnClick(self, 'LeftButton') end end
function methods:Show() self.visible = true;self.showCalls=(self.showCalls or 0)+1 end
function methods:Hide() self.visible = false;self.hideCalls=(self.hideCalls or 0)+1 end
function methods:SetShown(value) self.visible = not not value end
methods.SetShadowColor,methods.SetShadowOffset=noop,noop
function methods:IsShown() return self.visible end
function methods:IsVisible() return self.visible and (not self.parent or self.parent:IsVisible()) end
function methods:IsEnabled() return true end
function methods:HasFocus() return false end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetScrollChild(child) self.child = child end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:GetChildren()
    local children = {}
    for _, child in ipairs(frames) do
        if child.parent == self and child.kind ~= 'Texture' and child.kind ~= 'FontString' then children[#children+1] = child end
    end
    return table.unpack(children)
end
function methods:GetRegions()
    local regions = {}
    for _, child in ipairs(frames) do
        if child.parent == self and (child.kind == 'Texture' or child.kind == 'FontString') then regions[#regions+1] = child end
    end
    return table.unpack(regions)
end
function methods:IsObjectType(kind) return self.kind == kind end
function methods:GetAtlas() return self.texture end
function methods:GetFont() return self.fontPath, self.fontSize, '' end
function methods:GetStringHeight() return self.fontSize or 14 end
function methods:GetLeft() local x = bounds(self); return x end
function methods:GetTop() local _,y = bounds(self); return -y end
function methods:GetRight() local x,_,w = bounds(self); return x+w end
function methods:GetBottom() local _,y,_,h = bounds(self); return -y-h end
function methods:GetPoint()
    local point, a = next(self.anchors)
    if a then return point, a[1], a[2], a[3], a[4] end
end
function methods:SetVertexColor(r,g,b,a) self.vertex = {r,g,b,a or 1} end
for _, name in ipairs({'RegisterForClicks','RegisterForDrag','SetTexCoord','SetRotation','SetAutoFocus','SetMaxLetters','SetCursorPosition','SetTextInsets','EnableMouse','EnableMouseWheel','LockHighlight','UnlockHighlight','SetStatusBarTexture','SetStatusBarColor','SetMinMaxValues','SetValue','RegisterEvent','UnregisterAllEvents','SetDesaturated','Enable','SetBlendMode','SetToplevel','SetMouseMotionEnabled','SetResizable','SetResizeBounds','SetUserPlaced','SetMovable','StartMoving','StopMovingOrSizing','Raise','SetMultiLine','SetFocus','ClearFocus','SetClipsChildren','SetHitRectInsets','SetMotionScriptsWhileDisabled','SetNormalFontObject','SetHighlightFontObject','SetDisabledFontObject','SetDrawLayer'}) do methods[name] = methods[name] or noop end
table.unpack = table.unpack or unpack
return { frames=frames, methods=methods, frame=frame, bounds=bounds, noop=noop }
