-- BigAurasLite (WotLK 3.3.5a) v1.11.0
-- Updates:
--  - Sound options from DB.sound:
--      * once (bool, default true) -> play only once per aura instance
--      * eps (number, default 0.010) -> instance detection tolerance for startTime
--      * useCooldown (bool, default false) -> additional time cooldown limiter
--      * cooldownSec (number, default 2.0) -> seconds for time cooldown
--  - Safer auto-demote (only when switching to a different aura)
--  - Fewer allocations in CheckUnit, upvalued WoW API, small guards/cleanups

------------------------------------------------------------
-- Upvalues / fast locals (reduce global lookups on 3.3.5)
------------------------------------------------------------
local pairs, type, math, string = pairs, type, math, string
local abs, ceil, floor, max, cos = math.abs, math.ceil, math.floor, math.max, math.cos
local format = string.format
local wipe = wipe

local UIParent = UIParent
local CreateFrame = CreateFrame
local GetTime = GetTime
local GetSpellInfo = GetSpellInfo
local GetSpellLink = GetSpellLink
local UnitAura = UnitAura
local UnitExists = UnitExists
local UnitIsFriend = UnitIsFriend
local UnitGUID = UnitGUID
local UnitAffectingCombat = UnitAffectingCombat
local PlaySoundFile = PlaySoundFile

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function clamp(v, lo, hi)
  if v==nil then return lo end
  if v<lo then return lo elseif v>hi then return hi else return v end
end

local function copyInto(dst, src)
  for k,v in pairs(src) do
    if type(v)=="table" then
      dst[k]=dst[k] or {}; copyInto(dst[k], v)
    elseif dst[k]==nil then
      dst[k]=v
    end
  end
end

local function fmtCompact(rem)
  if rem>=10 then return ""..ceil(rem) else return format("%.1f", rem) end
end

local function colorTime(rem)
  if rem<2 then return "|cffff4444" elseif rem<5 then return "|cffffcc33" else return "|cffffffff" end
end

local STICKY_MS = 0.30
local TICK_INTERVAL = 0.05  -- OnUpdate throttle

-- pixel & grid helpers
local function UIPhysicalPixel() local scale=UIParent:GetEffectiveScale() return 1/scale end
local function RoundToPixel(x) local px=UIPhysicalPixel(); return floor(x/px+0.5)*px end
local function Snap(value, step) return floor(value/step + 0.5)*step end
local function ModDown(which)
  if which=="ALT" then return IsAltKeyDown()
  elseif which=="SHIFT" then return IsShiftKeyDown()
  elseif which=="CTRL" then return IsControlKeyDown() end
end

assert(BAL_Defaults, "BigAurasLite: defaults missing")
local DEFAULTS = BAL_Defaults()
local USER_STYLE={ fontPath="Fonts\\FRIZQT__.TTF", fontOutline="OUTLINE", baseSize=26, cdAlpha=0.55, showSpiral=true }
local DB

-- WotLK-safe ticker shim (replacement for C_Timer.NewTicker)
local function NewTicker(interval, func)
  local f=CreateFrame("Frame")
  local acc, canceled = 0, false
  f:SetScript("OnUpdate", function(_, elapsed)
    if canceled then return end
    acc = acc + (elapsed or 0)
    while acc >= interval do
      acc = acc - interval
      if canceled then return end
      func(f)
    end
  end)
  function f:Cancel() canceled=true; f:SetScript("OnUpdate", nil) end
  return f
end

------------------------------------------------------------
-- Colors / edges
------------------------------------------------------------
local BORDER_COLOR_IMMUNE   ={1.00,0.35,0.15,1}
local BORDER_COLOR_OFFENSE  ={1.00,0.75,0.10,1}
local BORDER_COLOR_DEFENSIVE={0.20,0.65,1.00,1}
local BORDER_COLOR_ANCHOR   ={1.00,0.90,0.20,1}

local function colorFor(typeKey)
  if typeKey=="immune" then return BORDER_COLOR_IMMUNE
  elseif typeKey=="offense" then return BORDER_COLOR_OFFENSE end
  return BORDER_COLOR_DEFENSIVE
end

local function edgeFileFor(style)
  if style=="dialog" then return "Interface\\DialogFrame\\UI-DialogBox-Border" end
  return "Interface\\Tooltips\\UI-Tooltip-Border"
end

------------------------------------------------------------
-- Solid border helpers (square)
------------------------------------------------------------
local function EnsureSolidBorder(frame)
  if frame._balBorder then return frame._balBorder end
  local b={}
  local tex="Interface\\CHATFRAME\\CHATFRAMEBACKGROUND"
  b.t=frame:CreateTexture(nil,"OVERLAY"); b.t:SetTexture(tex); b.t:SetDrawLayer("OVERLAY",3)
  b.b=frame:CreateTexture(nil,"OVERLAY"); b.b:SetTexture(tex); b.b:SetDrawLayer("OVERLAY",3)
  b.l=frame:CreateTexture(nil,"OVERLAY"); b.l:SetTexture(tex); b.l:SetDrawLayer("OVERLAY",3)
  b.r=frame:CreateTexture(nil,"OVERLAY"); b.r:SetTexture(tex); b.r:SetDrawLayer("OVERLAY",3)
  frame._balBorder=b; return b
end

local function ShowSolidBorder(frame, thickness, r,g,b,a, inset)
  local t = clamp(floor(thickness or 4),1,64)
  local i = clamp(floor(inset or 0),0,64)
  local B = EnsureSolidBorder(frame)
  B.t:ClearAllPoints(); B.t:SetPoint("TOPLEFT", frame, "TOPLEFT",  i, -i); B.t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -i, -i)
  B.t:SetHeight(t); B.t:SetVertexColor(r,g,b,a or 1); B.t:Show()
  B.b:ClearAllPoints(); B.b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT",  i,  i); B.b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -i,  i)
  B.b:SetHeight(t); B.b:SetVertexColor(r,g,b,a or 1); B.b:Show()
  B.l:ClearAllPoints(); B.l:SetPoint("TOPLEFT", frame, "TOPLEFT",  i, -i); B.l:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT",  i,  i)
  B.l:SetWidth(t); B.l:SetVertexColor(r,g,b,a or 1); B.l:Show()
  B.r:ClearAllPoints(); B.r:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -i, -i); B.r:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -i,  i)
  B.r:SetWidth(t); B.r:SetVertexColor(r,g,b,a or 1); B.r:Show()
end

local function HideSolidBorder(frame)
  local B=frame._balBorder; if not B then return end
  B.t:Hide(); B.b:Hide(); B.l:Hide(); B.r:Hide()
end

------------------------------------------------------------
-- Sound limiter helpers (config-driven)
------------------------------------------------------------
-- treat two occurrences as the same aura instance if they share spellID and startTime within eps
local function sameAuraInstance(active, spellID, startTime)
  local eps = ((DB and DB.sound and DB.sound.eps) or 0.010)
  if not active or not active.lastSpell or not active.start then return false end
  if active.lastSpell ~= spellID then return false end
  if (active.endsAt or 0) <= GetTime() then return false end
  return abs((startTime or -1) - (active.start or -2)) <= eps
end

------------------------------------------------------------
-- Tracker
------------------------------------------------------------
local function CreateTracker(kind)
  local T={}; T.kind=kind

  T.holder=CreateFrame("Frame","BigAurasLite_"..kind,UIParent); T.holder:Hide()
  T.icon=T.holder:CreateTexture(nil,"ARTWORK"); T.icon:SetDrawLayer("ARTWORK",0)
  T.cd=CreateFrame("Cooldown",nil,T.holder,"CooldownFrameTemplate"); T.cd:SetReverse(false)
  if USER_STYLE.showSpiral==false then T.cd:Hide() else T.cd:Show(); T.cd:SetAlpha(USER_STYLE.cdAlpha or 1.0) end

  T.holder:SetBackdrop({edgeFile=edgeFileFor(DEFAULTS.ui.borderStyle), edgeSize=DEFAULTS.ui.edgeSize})
  T.holder:SetBackdropBorderColor(0,0,0,0)

  T.tag=CreateFrame("Frame",nil,T.holder)
  T.tag:SetFrameLevel(T.holder:GetFrameLevel()+2)
  T.tag.bg=T.tag:CreateTexture(nil,"OVERLAY"); T.tag.bg:SetTexture("Interface\\CHATFRAME\\CHATFRAMEBACKGROUND")
  T.tag.text=T.tag:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); T.tag.text:SetTextColor(1,1,1,1); T.tag:Hide()

  -- OmniCC compat
  T.applyOmni=function(block)
    local v=block and true or nil
    T.holder.noCooldownCount=v; T.cd.noCooldownCount=v
    if T.holder2 then T.holder2.noCooldownCount=v end
    if T.cd2 then T.cd2.noCooldownCount=v end
  end

  -- numeric timer
  T.num=T.holder:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
  T.num:SetPoint("CENTER",T.holder,"CENTER",0,0); T.num:SetText("")
  function T:setNumFont()
    local s=clamp(self.holder:GetScale() or 1, 0.5, 3.0)
    self.num:SetFont(USER_STYLE.fontPath or "Fonts\\FRIZQT__.TTF", max(12, floor((USER_STYLE.baseSize or 32)*s)), USER_STYLE.fontOutline or "OUTLINE")
  end

  -- Tooltip MAIN
  local function HideTooltip() if GameTooltip:IsOwned(T.holder) or GameTooltip:IsOwned(T.holder2) then GameTooltip:Hide() end end
  local function ShowTooltipMain()
    if not DB or not DB.tooltip then return end
    local spellID=T.active.lastSpell; if not spellID then return end
    GameTooltip:SetOwner(T.holder,"ANCHOR_TOP")
    local link=GetSpellLink(spellID)
    if link then GameTooltip:SetHyperlink(link) else
      local name=GetSpellInfo(spellID) or ("SpellID "..spellID)
      GameTooltip:AddLine(name,1,1,1)
    end
    local cat=T.active.lastType; local txt=(cat=="immune" and "|cffff5533IMMUNE|r") or (cat=="offense" and "|cffffcc33OFFENSE|r") or "|cff3399ffDEFENSE|r"
    local now=GetTime(); local rem=(T.active.endsAt and T.active.endsAt>now) and (T.active.endsAt-now) or 0
    if rem>0 then GameTooltip:AddLine(("Category: %s  |  Left: %.1fs"):format(txt,rem),0.9,0.9,0.9) end
    local meta=DB.tracked[spellID]; if meta and meta.note and meta.note~="custom" then GameTooltip:AddLine(meta.note,0.8,0.8,0.8,true) end
    GameTooltip:Show()
  end
  T.holder:EnableMouse(true); T.holder:SetScript("OnEnter",ShowTooltipMain); T.holder:SetScript("OnLeave",HideTooltip)

  -- anchor/drag
  T.anchorText=T.holder:CreateFontString(nil,"OVERLAY","GameFontNormal")
  T.anchorText:SetPoint("BOTTOM",T.holder,"TOP",0,4); T.anchorText:SetTextColor(1,1,0.2,0.95); T.anchorText:SetText("")
  function T:showAnchor(show)
    if show then
      self.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); self.icon:SetVertexColor(1,1,1,0.5)
      self.num:SetText(""); self.cd:Hide()
      self.holder:SetBackdropBorderColor(unpack(BORDER_COLOR_ANCHOR))
      if DB.ui.useSolid then
        local shape = DB.ui.solidShape or "square"
        if shape=="rounded" then
          self.holder:SetBackdrop({edgeFile=edgeFileFor("tooltip"), edgeSize=DB.ui.borderPx or 6})
          HideSolidBorder(self.holder)
        else
          ShowSolidBorder(self.holder, DB.ui.borderPx, 1,0.9,0.2,1, DB.ui.solidInset or 0)
        end
      end
      self.anchorText:SetText("MOVE ("..self.kind..")"); self.holder:Show(); self:HideSecondary()
    else
      self.icon:SetVertexColor(1,1,1,1); self.anchorText:SetText(""); if USER_STYLE.showSpiral~=false then self.cd:Show() end
      if self.active.endsAt==0 or not self.active.endsAt then
        self.holder:SetBackdropBorderColor(0,0,0,0); HideSolidBorder(self.holder)
        if not self.secondary then self.holder:Hide() end
      end
    end
  end
  T.unlocked=false
  T.holder:SetMovable(true); T.holder:RegisterForDrag("LeftButton")
  T.holder:SetScript("OnDragStart",function(f) if T.unlocked then f:StartMoving() end end)
  T.holder:SetScript("OnDragStop",function(f)
    f:StopMovingOrSizing()
    if DB then
      local p,_,r,x,y=f:GetPoint(1)
      if DB.pixelPerfect then x=RoundToPixel(x); y=RoundToPixel(y) end
      if DB.grid and DB.grid.enabled then local step=max(2, DB.grid.size or 8); x=Snap(x,step); y=Snap(y,step) end
      f:ClearAllPoints(); f:SetPoint(p,UIParent,r,x,y)
      DB.pos[T.kind].point,DB.pos[T.kind].rel,DB.pos[T.kind].x,DB.pos[T.kind].y=p,r,x,y
    end
  end)

  -- runtime state
  T.active={start=0,dur=0,endsAt=0,lastSpell=nil,lastType="defense"}
  T.lastSoundAt={immune=0,offense=0,defense=0}; T.lastAnnouncedSpell=nil

  -- SECONDARY
  T.holder2=CreateFrame("Frame",nil,T.holder); T.holder2:Hide()
  T.holder2:SetFrameLevel(T.holder:GetFrameLevel()-1)
  T.icon2=T.holder2:CreateTexture(nil,"ARTWORK"); T.icon2:SetDrawLayer("ARTWORK",0)
  T.cd2=CreateFrame("Cooldown",nil,T.holder2,"CooldownFrameTemplate"); T.cd2:SetReverse(false)
  if USER_STYLE.showSpiral==false then T.cd2:Hide() else T.cd2:Show(); T.cd2:SetAlpha(USER_STYLE.cdAlpha or 1.0) end
  T.holder2:SetBackdrop({edgeFile=edgeFileFor(DEFAULTS.ui.borderStyle), edgeSize=(DEFAULTS.ui.edgeSize2 or DEFAULTS.ui.edgeSize)})
  T.holder2:SetBackdropBorderColor(0,0,0,0)

  -- tooltip second
  local function ShowTooltipSecond()
    if not DB or not DB.tooltip then return end
    if not T.secondary or not T.secondary.id then return end
    GameTooltip:SetOwner(T.holder2,"ANCHOR_TOP")
    local id=T.secondary.id; local link=GetSpellLink(id)
    if link then GameTooltip:SetHyperlink(link) else
      local name=GetSpellInfo(id) or ("SpellID "..id); GameTooltip:AddLine(name,1,1,1)
    end
    local cat=T.secondary.type or "defense"
    local txt=(cat=="immune" and "|cffff5533IMMUNE|r") or (cat=="offense" and "|cffffcc33OFFENSE|r") or "|cff3399ffDEFENSE|r"
    local now=GetTime(); local rem=(T.secondary.ends and T.secondary.ends>now) and (T.secondary.ends-now) or 0
    if rem>0 then GameTooltip:AddLine(("Category: %s  |  Left: %.1fs"):format(txt,rem),0.9,0.9,0.9) end
    local meta=DB.tracked[id]; if meta and meta.note and meta.note~="custom" then GameTooltip:AddLine(meta.note,0.8,0.8,0.8,true) end
    GameTooltip:Show()
  end
  T.holder2:EnableMouse(true); T.holder2:SetScript("OnEnter",ShowTooltipSecond); T.holder2:SetScript("OnLeave",function() if GameTooltip:IsOwned(T.holder2) then GameTooltip:Hide() end end)

  T.num2=T.holder2:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
  T.num2:SetPoint("CENTER",T.holder2,"CENTER",0,0); T.num2:SetText("")
  function T:setNumFont2()
    local s=clamp((self.holder:GetScale() or 1)*(DB.second.scale or 0.75), 0.25, 4.0)
    self.num2:SetFont(USER_STYLE.fontPath or "Fonts\\FRIZQT__.TTF", max(10, floor((USER_STYLE.baseSize or 32)*s)), USER_STYLE.fontOutline or "OUTLINE")
  end

  T.tag2=CreateFrame("Frame",nil,T.holder2); T.tag2:SetFrameLevel(T.holder2:GetFrameLevel()+2)
  T.tag2.bg=T.tag2:CreateTexture(nil,"OVERLAY"); T.tag2.bg:SetTexture("Interface\\CHATFRAME\\CHATFRAMEBACKGROUND")
  T.tag2.text=T.tag2:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); T.tag2.text:SetTextColor(1,1,1,1); T.tag2:Hide()

  local function showTag2(typeKey)
    if not DB or not DB.second.tag then T.tag2:Hide(); return end
    local label=(typeKey=="immune" and "IMMUNE") or (typeKey=="offense" and "OFFENSE") or "DEFENSE"
    T.tag2:SetSize(38,12); T.tag2:ClearAllPoints(); T.tag2:SetPoint("TOPLEFT",T.holder2,"TOPLEFT",2,-2)
    T.tag2.bg:ClearAllPoints(); T.tag2.bg:SetAllPoints(T.tag2)
    local c = (typeKey=="immune" and {0.9,0.35,0.15,0.85}) or (typeKey=="offense" and {1.0,0.75,0.1,0.85}) or {0.2,0.65,1.0,0.85}
    T.tag2.bg:SetVertexColor(c[1],c[2],c[3],c[4])
    T.tag2.text:ClearAllPoints(); T.tag2.text:SetPoint("CENTER",T.tag2,"CENTER",0,0)
    T.tag2.text:SetText(label); T.tag2:Show()
  end

  function T:HideSecondary()
    self.num2:SetText(""); self.holder2:SetBackdropBorderColor(0,0,0,0); HideSolidBorder(self.holder2)
    self.holder2:Hide(); self.tag2:Hide(); self.secondary=nil
  end

  local function SafeSetCooldown(cd,start,dur)
    if cd.SetCooldown then cd:SetCooldown(start,dur) else CooldownFrame_SetTimer(cd,start,dur,1) end
  end

  function T:StartSecondary(spellID,startTime,duration,typeKey)
    if not DB.second.enabled then return end
    if (duration or 0) < (DB.second.minRemain or 1.0) then return end
    self.holder:Show()
    local tex=select(3,GetSpellInfo(spellID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
    self.icon2:SetTexture(tex)
    SafeSetCooldown(self.cd2,startTime,duration)
    self.secondary={ id=spellID, start=startTime, dur=duration, ends=startTime+duration, type=typeKey or "defense" }
    local c=colorFor(typeKey)
    if DB.ui.useSolid then
      local shape = DB.ui.solidShape or "square"
      if shape=="rounded" then
        self.holder2:SetBackdrop({edgeFile=edgeFileFor("tooltip"), edgeSize=(DB.ui.borderPx2 or DB.ui.borderPx or 6)})
        self.holder2:SetBackdropBorderColor(c[1],c[2],c[3],1)
        HideSolidBorder(self.holder2)
      else
        ShowSolidBorder(self.holder2, DB.ui.borderPx2 or DB.ui.borderPx or 6, c[1],c[2],c[3],1, DB.ui.solidInset2 or DB.ui.solidInset or 0)
      end
    else
      self.holder2:SetBackdrop({edgeFile=edgeFileFor(DB.ui.borderStyle), edgeSize=(DB.ui.edgeSize2 or DB.ui.edgeSize or 16)})
      self.holder2:SetBackdropBorderColor(c[1],c[2],c[3],1)
    end
    showTag2(typeKey); self.holder2:Show()
  end

  -- helpers
  function T:HideMainVisuals()
    self.icon:SetTexture(nil); self.icon:Hide(); self.cd:Hide(); self.num:SetText(""); self.tag:Hide()
  end
  function T:ShowMainVisuals()
    self.icon:Show(); if USER_STYLE.showSpiral~=false then self.cd:Show() end; if DB and DB.showTag then self.tag:Show() end
  end

  -- soft glow
  T.glow = T.holder:CreateTexture(nil,"OVERLAY", nil, 7)
  T.glow:SetTexture("Interface\\BUTTONS\\UI-Quickslot-Depress")
  T.glow:SetAllPoints(T.holder)
  T.glow:SetBlendMode("ADD")
  T.glow:Hide()

  -- throttled update (+ hold-modifier click-through)
  T._nextTick = 0
  T.holder:SetScript("OnUpdate",function()
    local now=GetTime()
    if now < (T._nextTick or 0) then return end
    T._nextTick = now + TICK_INTERVAL

    -- hold modifier: toggle mouse for tooltips
    if T._ctHold then
      local want = ModDown(T._ctHold)
      if want ~= T._ctState then
        T._ctState = want
        T.holder:EnableMouse(want); T.holder2:EnableMouse(want)
      end
    end

    if not T.holder:IsShown() then return end
    local a=T.active
    local hasMain=(a.endsAt and a.endsAt>0)

    if hasMain then
      local remain=a.endsAt-now
      if remain<=-STICKY_MS then
        T:HideMainVisuals()
        a.start,a.dur,a.endsAt=0,0,0; a.lastSpell=nil; T.lastAnnouncedSpell=nil
        T.holder:SetAlpha(1); T.glow:Hide()
        if not T.unlocked then
          T.holder:SetBackdropBorderColor(0,0,0,0); HideSolidBorder(T.holder)
          if not T.secondary then T.holder:Hide() end
        end
      else
        if DB.blockOmniCC then T.num:SetText(colorTime(remain)..fmtCompact(remain).."|r") else T.num:SetText("") end
        if remain<1.2 then
          local p=remain*3.0
          local aPulse=0.4+0.4*abs(cos(p))
          T.holder:SetAlpha(0.6+0.4*abs(cos(p))); T.glow:SetAlpha(aPulse); T.glow:Show()
        else
          T.holder:SetAlpha(1); T.glow:Hide()
        end
      end
    else
      T.num:SetText(""); T.holder:SetAlpha(1); T.glow:Hide()
    end

    if T.secondary and T.holder2:IsShown() then
      local rem2=(T.secondary.ends or 0)-now
      if rem2<=0 then
        T:HideSecondary()
        if (not hasMain) and (not T.unlocked) then
          T.holder:SetBackdropBorderColor(0,0,0,0); HideSolidBorder(T.holder); T.holder:Hide()
        end
      else
        if DB.blockOmniCC then T.num2:SetText(colorTime(rem2)..fmtCompact(rem2).."|r") else T.num2:SetText("") end
      end
    end
  end)

  local function borderFor(typeKey)
    if typeKey=="immune" then return BORDER_COLOR_IMMUNE,"IMMUNE"
    elseif typeKey=="offense" then return BORDER_COLOR_OFFENSE,"OFFENSE"
    else return BORDER_COLOR_DEFENSIVE,"DEFENSE" end
  end

  local function showTagMain(typeKey)
    if not DB or not DB.showTag then T.tag:Hide(); return end
    local label=(typeKey=="immune" and "IMMUNE") or (typeKey=="offense" and "OFFENSE") or "DEFENSE"
    local w=max(36,(label=="IMMUNE" and 44 or 50))
    T.tag:SetSize(w,14); T.tag:ClearAllPoints(); T.tag:SetPoint("TOPLEFT",T.holder,"TOPLEFT",2,-2)
    T.tag.bg:ClearAllPoints(); T.tag.bg:SetAllPoints(T.tag)
    local c = (typeKey=="immune" and {0.9,0.35,0.15,0.85}) or (typeKey=="offense" and {1.0,0.75,0.1,0.85}) or {0.2,0.65,1.0,0.85}
    T.tag.bg:SetVertexColor(c[1],c[2],c[3],c[4])
    T.tag.text:ClearAllPoints(); T.tag.text:SetPoint("CENTER",T.tag,"CENTER",0,0); T.tag.text:SetText(label); T.tag:Show()
  end

  -- Reusable entries buffer (reduce allocs in CheckUnit)
  T._entries = {}

  function T:StartCooldown(spellID,startTime,duration,typeKey)
    if DB.combatOnly and not UnitAffectingCombat("player") then return end

    local isNewInstance = not sameAuraInstance(self.active, spellID, startTime)
    local isDifferentSpell = (self.active.lastSpell ~= nil and self.active.lastSpell ~= spellID)

    -- auto-demote only when switching to a different aura
    if isNewInstance and isDifferentSpell and DB.second and DB.second.enabled and (DB.autoDemotePrevious or DEFAULTS.autoDemotePrevious) then
      local now=GetTime()
      if self.active and self.active.lastSpell and (self.active.endsAt or 0)>now then
        local remain=(self.active.endsAt or now)-now
        if remain >= (DB.second.minRemain or 1.0) then
          local start2 = now-remain
          self:StartSecondary(self.active.lastSpell, start2, remain, self.active.lastType or "defense")
        end
      end
    end

    self:showAnchor(false)
    local tex = select(3,GetSpellInfo(spellID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
    self.icon:SetTexture(tex)
    self:ShowMainVisuals()
    SafeSetCooldown(self.cd,startTime,duration)

    self.active.start,self.active.dur,self.active.endsAt=startTime,duration,startTime+duration
    self.active.lastSpell=spellID; self.active.lastType=typeKey or "defense"
    local c,label=borderFor(self.active.lastType)

    -- borders
    if DB.ui.useSolid then
      local shape = DB.ui.solidShape or "square"
      if shape=="rounded" then
        self.holder:SetBackdrop({edgeFile=edgeFileFor("tooltip"), edgeSize=DB.ui.borderPx or 6})
        self.holder:SetBackdropBorderColor(c[1],c[2],c[3],1)
        HideSolidBorder(self.holder)
      else
        ShowSolidBorder(self.holder, DB.ui.borderPx or 6, c[1],c[2],c[3],1, DB.ui.solidInset or 0)
      end
    else
      self.holder:SetBackdrop({edgeFile=edgeFileFor(DB.ui.borderStyle), edgeSize=DB.ui.edgeSize or 16})
      self.holder:SetBackdropBorderColor(c[1],c[2],c[3],c[4])
    end
    showTagMain(self.active.lastType)

    -- SOUND: config-driven
    do
      local snd = DB.sounds and (DB.sounds[self.active.lastType] or DB.sounds.defense)
      if snd then
        local soundCfg = DB.sound or {}
        local onceEnabled = (soundCfg.once ~= false) -- default ON
        local shouldPlay = true

        if onceEnabled and not isNewInstance then
          shouldPlay = false
        end

        if shouldPlay and soundCfg.useCooldown then
          local now = GetTime()
          local last = self.lastSoundAt[self.active.lastType] or 0
          local cd = soundCfg.cooldownSec or 2.0
          if (now - last) < cd then
            shouldPlay = false
          else
            self.lastSoundAt[self.active.lastType] = now
          end
        end

        if shouldPlay then
          PlaySoundFile(snd)
        end
      end
    end

    if DB.history and (isNewInstance or self.active.lastSpell~=self.lastAnnouncedSpell) then
      local name = GetSpellInfo(spellID) or ("SpellID "..spellID)
      DEFAULT_CHAT_FRAME:AddMessage(format("|cff00ff00BAL|r [%s] %s – %ds",label, name, floor(duration+0.5)))
      self.lastAnnouncedSpell=self.active.lastSpell
    end
    self.holder:Show()
  end

  function T:ShowSpell(spellID,durOpt,typeKey)
    local now=GetTime(); local meta=DB.tracked[spellID]
    local fallback = DB.durationFallback or DEFAULTS.durationFallback or 1.2
    local dur = durOpt or (meta and meta.dur) or fallback
    self:StartCooldown(spellID,now,dur,typeKey or (meta and meta.type) or "defense")
  end

  function T:Clear()
    self:HideSecondary(); self:HideMainVisuals()
    self.active.start,self.active.dur,self.active.endsAt=0,0,0; self.active.lastSpell=nil; self.lastAnnouncedSpell=nil
    self.holder:SetAlpha(1); self.glow:Hide()
    if not self.unlocked then self.holder:SetBackdropBorderColor(0,0,0,0); HideSolidBorder(self.holder); self.holder:Hide() end
  end

  local function catPrio(c) return (c=="immune" and 3) or (c=="offense" and 2) or 1 end
  local function hardRank(id) return (DB and DB.hardprioEnabled and DB.hardprio and DB.hardprio[id]) or 0 end

  function T:CheckUnit(unit)
    if DB.combatOnly and not UnitAffectingCombat("player") then return false end
    if not UnitExists(unit) then return false end

    -- friendly/enemy filter
    if DB.filter=="enemies" and UnitIsFriend("player", unit) then return false end
    if DB.filter=="friends" and not UnitIsFriend("player", unit) then return false end

    -- reuse buffer
    local entries = self._entries; wipe(entries)
    local now=GetTime()

    for i=1,40 do
      local _,_,_,_,_,duration,expirationTime,_,_,_,id=UnitAura(unit,i,"HELPFUL")
      if not id then break end
      local meta=DB.tracked[id]
      if meta then
        local dur=(duration and duration>0) and duration or (meta.dur or DB.durationFallback)
        local remain,start
        if duration and duration>0 and expirationTime and expirationTime>now then
          remain=expirationTime-now; start=expirationTime-duration
        else
          remain=dur; start=now
        end
        if remain >= (DB.mainMinRemain or 0) then
          local tkey=meta.type or "defense"
          local idx=#entries+1
          entries[idx]=entries[idx] or {}
          local e=entries[idx]
          e.id, e.start, e.dur, e.remain, e.tkey = id, start, dur, remain, tkey
          e.prio, e.hrd = catPrio(tkey), hardRank(id)
        end
      end
    end

    -- sort: hardprio > cat > remain
    table.sort(entries,function(a,b)
      if a.hrd~=b.hrd then return a.hrd>b.hrd end
      if a.prio~=b.prio then return a.prio>b.prio end
      return a.remain>b.remain
    end)

    local top1=entries[1]
    local top2=(entries[2] and entries[2].id~=(top1 and top1.id)) and entries[2] or nil

    if top1 then
      self:StartCooldown(top1.id,top1.start,top1.dur,top1.tkey)
      if top2 and DB.second.enabled then
        self:StartSecondary(top2.id,top2.start,top2.dur,top2.tkey)
      else
        self:HideSecondary()
      end
      return true
    else
      self:HideSecondary()
      return false
    end
  end

  function T:ApplyUIMetrics()
    local U=DB.ui
    local content = clamp(U.contentSize or 64, 16, 256)
    U.contentSize = content
    U.inset = clamp(U.inset or 6, 0, 32)

    local W=(U.contentSize+2*U.inset)
    if DB.pixelPerfect then W=RoundToPixel(W) end
    self.holder:SetSize(W,W); self.holder:SetFrameStrata(U.strata or "LOW")

    self.icon:ClearAllPoints(); self.icon:SetPoint("TOPLEFT",self.holder,"TOPLEFT",U.inset,-U.inset)
    self.icon:SetPoint("BOTTOMRIGHT",self.holder,"BOTTOMRIGHT",-U.inset,U.inset)
    self.cd:ClearAllPoints(); self.cd:SetPoint("TOPLEFT",self.holder,"TOPLEFT",U.inset,-U.inset)
    self.cd:SetPoint("BOTTOMRIGHT",self.holder,"BOTTOMRIGHT",-U.inset,U.inset)
    if USER_STYLE.showSpiral==false then self.cd:Hide() else self.cd:Show(); self.cd:SetAlpha(USER_STYLE.cdAlpha or 1.0) end
    self.tag:ClearAllPoints(); self.tag:SetPoint("TOPLEFT",self.holder,"TOPLEFT",2,-2); self:setNumFont()

    local s=clamp(DB.second.scale or 0.75, 0.25, 4.0)
    local W2 = W*s; if DB.pixelPerfect then W2=RoundToPixel(W2) end
    self.holder2:SetSize(W2,W2); self.holder2:ClearAllPoints()
    local gap=DB.second.gap or 8
    local a=(DB.second.anchor or "below")
    if a=="right" then
      self.holder2:SetPoint("LEFT", self.holder, "RIGHT", (gap + (DB.second.offsetX or 0)), (DB.second.offsetY or 0))
    elseif a=="left" then
      self.holder2:SetPoint("RIGHT", self.holder, "LEFT", -(gap - (DB.second.offsetX or 0)), (DB.second.offsetY or 0))
    elseif a=="above" then
      self.holder2:SetPoint("BOTTOM", self.holder, "TOP", (DB.second.offsetX or 0), (gap + (DB.second.offsetY or 0)))
    else -- below
      self.holder2:SetPoint("TOP", self.holder, "BOTTOM", (DB.second.offsetX or 0), -(gap - (DB.second.offsetY or 0)))
    end

    self.icon2:ClearAllPoints(); self.icon2:SetPoint("TOPLEFT",self.holder2,"TOPLEFT",U.inset*s,-U.inset*s)
    self.icon2:SetPoint("BOTTOMRIGHT",self.holder2,"BOTTOMRIGHT",-U.inset*s,U.inset*s)
    self.cd2:ClearAllPoints(); self.cd2:SetPoint("TOPLEFT",self.holder2,"TOPLEFT",U.inset*s,-U.inset*s)
    self.cd2:SetPoint("BOTTOMRIGHT",self.holder2,"BOTTOMRIGHT",-U.inset*s,U.inset*s)
    if USER_STYLE.showSpiral==false then self.cd2:Hide() else self.cd2:Show(); self.cd2:SetAlpha(USER_STYLE.cdAlpha or 1.0) end
    self.tag2:ClearAllPoints(); self.tag2:SetPoint("TOPLEFT",self.holder2,"TOPLEFT",2,-2); self:setNumFont2()

    if U.useSolid then
      local shape = U.solidShape or "square"
      if shape=="rounded" then
        self.holder:SetBackdrop({edgeFile=edgeFileFor("tooltip"), edgeSize=U.borderPx or 6})
        local cMain=colorFor(self.active.lastType or "defense")
        self.holder:SetBackdropBorderColor(cMain[1],cMain[2],cMain[3],1)
        HideSolidBorder(self.holder)

        self.holder2:SetBackdrop({edgeFile=edgeFileFor("tooltip"), edgeSize=(U.borderPx2 or U.borderPx or 6)})
        local cSec=(self.secondary and colorFor(self.secondary.type)) or cMain
        self.holder2:SetBackdropBorderColor(cSec[1],cSec[2],cSec[3],1)
        HideSolidBorder(self.holder2)
      else
        local cMain=colorFor(self.active.lastType or "defense")
        ShowSolidBorder(self.holder,  U.borderPx  or 6, cMain[1],cMain[2],cMain[3],1, U.solidInset or 0)
        local cSec=(self.secondary and colorFor(self.secondary.type)) or cMain
        ShowSolidBorder(self.holder2, U.borderPx2 or U.borderPx or 6, cSec[1],cSec[2],cSec[3],1, U.solidInset2 or U.solidInset or 0)
      end
    else
      HideSolidBorder(self.holder); HideSolidBorder(self.holder2)
      self.holder:SetBackdrop({edgeFile=edgeFileFor(U.borderStyle or "tooltip"), edgeSize=U.edgeSize or 16})
      self.holder2:SetBackdrop({edgeFile=edgeFileFor(U.borderStyle or "tooltip"), edgeSize=(U.edgeSize2 or U.edgeSize or 16)})
    end
  end

  function T:ApplyMouseMode()
    local mode = (DB.clickThrough and DB.clickThrough.mode) or "off"
    if mode=="off" then
      self.holder:EnableMouse(true);  self.holder2:EnableMouse(true); self._ctHold=nil; self._ctState=nil
    elseif mode=="on" then
      self.holder:EnableMouse(false); self.holder2:EnableMouse(false); self._ctHold=nil; self._ctState=nil
    else
      self._ctHold = (DB.clickThrough and DB.clickThrough.modifier) or "ALT"
      self._ctState = false
      self.holder:EnableMouse(false); self.holder2:EnableMouse(false)
    end
  end

  function T:ApplyFromDB()
    local cfg=DB.pos[self.kind]
    local x,y = cfg.x or 0, cfg.y or 0
    if DB.pixelPerfect then x=RoundToPixel(x); y=RoundToPixel(y) end
    if DB.grid and DB.grid.enabled then local s=max(2, DB.grid.size or 8); x=Snap(x,s); y=Snap(y,s) end
    self.holder:ClearAllPoints(); self.holder:SetPoint(cfg.point or "CENTER",UIParent,cfg.rel or "CENTER",x,y)
    DB.pos[self.kind].x, DB.pos[self.kind].y = x, y

    self.holder:SetScale(clamp(cfg.scale or 1.0, 0.5, 3.0))
    self:ApplyUIMetrics(); self.applyOmni(DB.blockOmniCC)
    self:ApplyMouseMode()
  end

  return T
end

------------------------------------------------------------
-- Public style apply
------------------------------------------------------------
function BigAurasLite_ApplyStyle()
  if not DB then return end
  DB.style = DB.style or {}
  if DB.style.fontPath    then USER_STYLE.fontPath    = DB.style.fontPath    end
  if DB.style.fontOutline then USER_STYLE.fontOutline = DB.style.fontOutline end
  if DB.style.baseSize    then USER_STYLE.baseSize    = DB.style.baseSize    end
  if DB.style.cdAlpha     then USER_STYLE.cdAlpha     = DB.style.cdAlpha     end
  if DB.style.showSpiral~=nil then USER_STYLE.showSpiral = DB.style.showSpiral and true or false end

  if TargetTracker and TargetTracker.setNumFont then TargetTracker:setNumFont(); TargetTracker:setNumFont2() end
  if FocusTracker  and FocusTracker.setNumFont  then FocusTracker:setNumFont();  FocusTracker:setNumFont2()  end
  if BigAurasLite_ApplyBoth then BigAurasLite_ApplyBoth() end
end

------------------------------------------------------------
-- Instances
------------------------------------------------------------
local TargetTracker=CreateTracker("target")
local FocusTracker =CreateTracker("focus")

_G.TargetTracker=TargetTracker; _G.FocusTracker=FocusTracker
function BigAurasLite_ApplyBoth() if TargetTracker and TargetTracker.ApplyUIMetrics then TargetTracker:ApplyUIMetrics() end if FocusTracker and FocusTracker.ApplyUIMetrics then FocusTracker:ApplyUIMetrics() end end
function BigAurasLite_ApplyFromDBBoth() if TargetTracker and TargetTracker.ApplyFromDB then TargetTracker:ApplyFromDB() end if FocusTracker and FocusTracker.ApplyFromDB then FocusTracker:ApplyFromDB() end end

------------------------------------------------------------
-- Events
------------------------------------------------------------
local f=CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED"); f:RegisterEvent("PLAYER_LOGOUT"); f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("PLAYER_TARGET_CHANGED"); f:RegisterEvent("PLAYER_FOCUS_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED"); f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") -- fallback

f:SetScript("OnEvent",function(_,evt,...)
  if evt=="ADDON_LOADED" then
    local name = ...
    if name=="BigAurasLite" then
      BigAurasLiteDB=BigAurasLiteDB or {}; DB=BigAurasLiteDB; copyInto(DB,DEFAULTS)

      -- ensure sound table exists (do not override user choices)
      DB.sound = DB.sound or {}
      if DB.sound.once == nil then DB.sound.once = true end
      if DB.sound.eps  == nil then DB.sound.eps  = 0.010 end
      if DB.sound.useCooldown == nil then DB.sound.useCooldown = false end
      if DB.sound.cooldownSec == nil then DB.sound.cooldownSec = 2.0 end

      BigAurasLite_ApplyStyle()

      if DB.filter==nil and DB.allowFriendly~=nil then
        DB.filter = (DB.allowFriendly and "both") or "enemies"
      end

      if not DB._conflictHintShown then
        local hasExt = (_G.OmniCC ~= nil) or (_G.tullaCC ~= nil) or (_G.CooldownCount ~= nil)
        if hasExt then
          if DB.blockOmniCC then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BAL|r: Wykryto OmniCC/tullaCC. 'Własny licznik' BAL jest włączony – jeśli widzisz podwójne cyfry, wyłącz licznik w tamtym addon'ie.")
          else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BAL|r: Wykryto OmniCC/tullaCC. Jeśli chcesz cyfry licznika na ikonach BAL, włącz 'Własny licznik' w opcjach BigAurasLite.")
          end
        end
        DB._conflictHintShown = true
      end

      DB.pos.target=DB.pos.target or {}; copyInto(DB.pos.target,DEFAULTS.pos.target)
      DB.pos.focus =DB.pos.focus  or {}; copyInto(DB.pos.focus ,DEFAULTS.pos.focus)
      TargetTracker:ApplyFromDB(); FocusTracker:ApplyFromDB()
    end

  elseif evt=="PLAYER_LOGOUT" then
    DB.blockOmniCC=DB.blockOmniCC and true or false; DB.combatOnly=DB.combatOnly and true or false
    DB.tooltip=DB.tooltip and true or false; DB.history=DB.history and true or false
    DB.showTag=DB.showTag and true or false; DB.hardprioEnabled=DB.hardprioEnabled and true or false

  elseif evt=="PLAYER_TARGET_CHANGED" then
    TargetTracker:Clear(); TargetTracker:CheckUnit("target")

  elseif evt=="PLAYER_FOCUS_CHANGED" then
    FocusTracker:Clear();  FocusTracker:CheckUnit("focus")

  elseif evt=="UNIT_AURA" then
    local unit = ...
    if unit=="target" then
      local found=TargetTracker:CheckUnit("target"); if TargetTracker.active.lastSpell and not found then TargetTracker:Clear() end
    elseif unit=="focus" then
      local found=FocusTracker:CheckUnit("focus"); if FocusTracker.active.lastSpell and not found then FocusTracker:Clear() end
    end

  elseif evt=="PLAYER_REGEN_DISABLED" then
    if DB.combatOnly then TargetTracker:CheckUnit("target"); FocusTracker:CheckUnit("focus") end

  elseif evt=="PLAYER_REGEN_ENABLED" then
    if DB.combatOnly then TargetTracker:Clear(); FocusTracker:Clear() end

  elseif evt=="COMBAT_LOG_EVENT_UNFILTERED" then
    -- WotLK varargs layout
    local _, sub, _, _,_,_,_, destGUID, _,_,_, spellID = ...
    if (sub=="SPELL_AURA_APPLIED" or sub=="SPELL_AURA_REFRESH") and spellID and DB.tracked[spellID] then
      local function maybeKick(T, unit)
        if not UnitExists(unit) then return end
        if UnitGUID(unit)~=destGUID then return end
        -- VERIFY aura is actually on the unit
        local seen=false
        for i=1,40 do
          local _,_,_,_,_,_,_,_,_,_,id=UnitAura(unit,i,"HELPFUL")
          if id==spellID then seen=true break end
          if not id then break end
        end
        if not seen then
          local meta=DB.tracked[spellID]
          T:ShowSpell(spellID, meta and meta.dur or DB.durationFallback, meta and meta.type)
        end
      end
      maybeKick(TargetTracker,"target"); maybeKick(FocusTracker,"focus")
    end
  end
end)

------------------------------------------------------------
-- Test loop & slash
------------------------------------------------------------
local _BAL_Loop = {
  t = { ticker=nil, second=false },
  f = { ticker=nil, second=false },
}
local function _BAL_Stop(kind)
  local s=_BAL_Loop[kind]; if s and s.ticker and s.ticker.Cancel then s.ticker:Cancel(); s.ticker=nil end
end
local function _BAL_ClearVisuals(kind)
  if kind=="t" then TargetTracker:Clear()
  elseif kind=="f" then FocusTracker:Clear()
  elseif kind=="both" then TargetTracker:Clear(); FocusTracker:Clear() end
end

SLASH_BIGA1="/bal"
SlashCmdList.BIGA=function(msg)
  local a,b,c=msg:match("^(%S*)%s*(%S*)%s*(%S*)")
  local cmd=(a or ""):lower(); local arg1=(b or ""):lower(); local arg2=(c or ""):lower()
  local function applyUIToBoth()
    TargetTracker:ApplyUIMetrics(); FocusTracker:ApplyUIMetrics()
    local U=DB.ui; print( ("|cff00ff00BAL:|r UI size=%d inset=%d %s strata=%s")
      :format(U.contentSize, U.inset, U.useSolid and ("solid="..(U.borderPx or 6).."/"..(U.borderPx2 or U.borderPx or 6).." inset="..(U.solidInset or 0).."/"..(U.solidInset2 or U.solidInset or 0).." shape="..(U.solidShape or "square"))
                               or ("edge="..(U.edgeSize or 16).."/"..(U.edgeSize2 or U.edgeSize or 16).." style="..(U.borderStyle or "tooltip")), U.strata or "LOW"))
  end

  if cmd=="" or cmd=="help" then
    print("|cff00ff00BigAurasLite|r — pełna konfiguracja w |cffffff00/balopt|r (Options > AddOns > BigAurasLite).")
    print("Szybki test: |cffffff00/bal test t|r  lub  |cffffff00/bal test t second|r.")
    return

  elseif cmd=="test" then
    local T=(arg1=="f" or arg1=="focus") and FocusTracker or TargetTracker
    local wantSecond=(arg1=="second" or arg2=="second")
    local mainID, secID = 19574, 31884
    local now=GetTime()
    local mainDur=(DEFAULTS.tracked[mainID] and DEFAULTS.tracked[mainID].dur) or 10
    local secDur =(DEFAULTS.tracked[secID]  and DEFAULTS.tracked[secID].dur)  or 20
    local mainType=(DEFAULTS.tracked[mainID] and DEFAULTS.tracked[mainID].type) or "immune"
    local secType =(DEFAULTS.tracked[secID]  and DEFAULTS.tracked[secID].type) or "offense"
    T:StartCooldown(mainID,now,mainDur,mainType)
    if wantSecond then local prev=DB.second.enabled; DB.second.enabled=true; T:StartSecondary(secID,now,secDur,secType); DB.second.enabled=prev end
    print("|cff00ff00BAL:|r test "..((T==FocusTracker) and "focus" or "target")..(wantSecond and " + second" or ""))

  elseif cmd=="testloop" then
    local k = (arg1=="f" or arg1=="focus") and "f" or "t"
    local wantSecond = (arg1=="second" or arg2=="second")
    _BAL_Stop(k); _BAL_ClearVisuals(k)
    local T = (k=="f") and FocusTracker or TargetTracker
    local mainID, secID = 19574, 31884
    _BAL_Loop[k].second = wantSecond
    _BAL_Loop[k].ticker = NewTicker(0.1, function()
      local now=GetTime()
      local a=T.active
      if not a.lastSpell or (a.endsAt-now)<=0 then
        local md = (DEFAULTS.tracked[mainID] and DEFAULTS.tracked[mainID].dur) or 10
        local mt = (DEFAULTS.tracked[mainID] and DEFAULTS.tracked[mainID].type) or "immune"
        T:StartCooldown(mainID,now,md,mt)
        if _BAL_Loop[k].second then
          local sd = (DEFAULTS.tracked[secID] and DEFAULTS.tracked[secID].dur) or 20
          local st = (DEFAULTS.tracked[secID] and DEFAULTS.tracked[secID].type) or "offense"
          local prev=DB.second.enabled; DB.second.enabled=true; T:StartSecondary(secID,now,sd,st); DB.second.enabled=prev
        end
      end
    end)
    print("|cff00ff00BAL:|r loop start "..(k=="f" and "focus" or "target")..(wantSecond and " + second" or ""))

  elseif cmd=="stoploop" then
    local k = (arg1=="f" or arg1=="focus") and "f" or ((arg1=="both") and "both" or "t")
    if k=="both" then _BAL_Stop("t"); _BAL_Stop("f"); _BAL_ClearVisuals("both")
    else _BAL_Stop(k); _BAL_ClearVisuals(k) end
    print("|cff00ff00BAL:|r loop stopped "..(k=="both" and "both" or (k=="f" and "focus" or "target")))

  elseif cmd=="stoptest" then
    _BAL_Stop("t"); _BAL_Stop("f"); _BAL_ClearVisuals("both")
    print("|cff00ff00BAL:|r tests stopped & cleared.")

  elseif cmd=="style" then
    local v=(arg1=="dialog" and "dialog") or "tooltip"; DB.ui.borderStyle=v; applyUIToBoth()
  elseif cmd=="solid" then
    if arg1=="on" then DB.ui.useSolid=true; applyUIToBoth()
    elseif arg1=="off" then
      DB.ui.useSolid=false
      HideSolidBorder(TargetTracker.holder); HideSolidBorder(TargetTracker.holder2)
      HideSolidBorder(FocusTracker.holder);  HideSolidBorder(FocusTracker.holder2)
      applyUIToBoth()
    elseif arg1=="shape" and (arg2=="rounded" or arg2=="square") then DB.ui.solidShape=arg2; applyUIToBoth()
    else
      print("Użyj /balopt aby skonfigurować. (Legacy: /bal solid on|off|shape rounded|square)")
    end
  else
    print("|cff00ff00BAL|r: Nieznana komenda. Otwórz opcje: |cffffff00/balopt|r.")
  end
end
