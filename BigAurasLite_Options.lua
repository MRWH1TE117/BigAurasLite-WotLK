-- BigAurasLite_Options.lua (WotLK 3.3.5a, v1.11.0)
-- Responsive layout: sliders & dropdowns stretch to the right; values never hide
-- Spells: lists scale with panel width; editors kept safe widths
-- Testing: narrow buttons, safe positions
-- Fix: no method chaining after SetPoint (WoW API returns nil)

local PANEL_NAME="BigAurasLite"; local panel
local function GetDB() if BigAurasLiteDB==nil and BAL_Defaults then BigAurasLiteDB=BAL_Defaults() end return BigAurasLiteDB end
local function BAL(cmd) if SlashCmdList and SlashCmdList.BIGA then SlashCmdList.BIGA(cmd or "") end end

local _id={cb=0,sl=0,dd=0,eb=0}

-- === helpers ===
local function MakeCheck(parent,label,tip,x,y,onClick)
  _id.cb=_id.cb+1; local name=PANEL_NAME.."_CB".._id.cb
  local cb=CreateFrame("CheckButton",name,parent,"OptionsCheckButtonTemplate")
  cb:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); _G[name.."Text"]:SetText(label)
  if tip then cb.tooltipText=label; cb.tooltipRequirement=tip end
  cb:SetScript("OnClick",function(self) PlaySound("igMainMenuOptionCheckBoxOn"); onClick(self:GetChecked()) end)
  return cb
end

local function MakeButton(parent,label,x,y,w,h,onClick)
  local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
  b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); b:SetSize(w or 140,h or 22); b:SetText(label)
  b:SetScript("OnClick",function() PlaySound("igMainMenuOptionCheckBoxOn"); onClick(b) end)
  return b
end

-- Responsive slider row (value label sits next to the slider and always shows)
local function MakeSlider(parent,label,minV,maxV,step,x,y,onValue,fmt)
  _id.sl=_id.sl+1; local name=PANEL_NAME.."_SL".._id.sl

  local row = CreateFrame("Frame", nil, parent)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  row:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
  row:SetHeight(24)

  local s=CreateFrame("Slider",name,row,"OptionsSliderTemplate")
  s:SetPoint("LEFT", row, "LEFT", 0, 0)
  s:SetMinMaxValues(minV,maxV)
  s:SetValueStep(step or 1)

  _G[name.."Low"]:SetText(tostring(minV))
  _G[name.."High"]:SetText(tostring(maxV))
  _G[name.."Text"]:SetText(label)

  local valFS=row:CreateFontString(nil,"ARTWORK","GameFontHighlight")
  valFS:SetJustifyH("LEFT")
  valFS:SetWidth(90)
  valFS:SetPoint("LEFT", s, "RIGHT", 8, 0)

  local function layoutSlider()
    local rowW = row:GetWidth() or 320
    local sw = math.max(180, rowW - 98) -- 98px for value (90 + 8 margin)
    s:SetWidth(sw)
  end
  row:SetScript("OnSizeChanged", layoutSlider)

  local function setValText(v) valFS:SetText((fmt and fmt(v)) or tostring(v)) end
  s.SetValueAndText=function(self,v) self:SetValue(v); setValText(v) end
  s:SetScript("OnValueChanged",function(self,val)
    val=math.floor((val or 0)*1000+0.5)/1000 -- 3dp safety for eps/seconds
    setValText(val)
    onValue(val)
  end)

  layoutSlider()
  setValText(s:GetValue() or minV)

  return s,valFS
end

-- Responsive dropdown row (stretches to right; width capped by optional 'width')
local function MakeDrop(parent,label,items,x,y,onSelect,width)
  local row = CreateFrame("Frame", nil, parent)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  row:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
  row:SetHeight(44)

  local fs=row:CreateFontString(nil,"ARTWORK","GameFontNormal")
  fs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  fs:SetText(label)

  _id.dd=_id.dd+1; local name=PANEL_NAME.."_DD".._id.dd
  local dd=CreateFrame("Frame",name,row,"UIDropDownMenuTemplate")
  dd:SetPoint("TOPLEFT",fs,"BOTTOMLEFT",-16,-2)

  UIDropDownMenu_Initialize(dd,function(self,level)
    for _,it in ipairs(items) do
      local info=UIDropDownMenu_CreateInfo()
      info.text=it.text; info.value=it.value
      info.func=function() UIDropDownMenu_SetSelectedValue(dd,it.value); onSelect(it.value) end
      UIDropDownMenu_AddButton(info,level)
    end
  end)

  local function layoutDD()
    local rowW = row:GetWidth() or 320
    local w = math.max(140, math.min(width or 220, rowW - 32))
    UIDropDownMenu_SetWidth(dd, w)
  end
  row:SetScript("OnSizeChanged", function() layoutDD() end)
  layoutDD()

  return dd,fs
end

local function MakeEditBox(parent,label,x,y,w,onEnterPressed)
  _id.eb=_id.eb+1; local name=PANEL_NAME.."_EB".._id.eb
  local fs=parent:CreateFontString(nil,"ARTWORK","GameFontNormal")
  fs:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  fs:SetText(label)
  local eb=CreateFrame("EditBox",name,parent,"InputBoxTemplate")
  eb:SetAutoFocus(false); eb:SetSize(w or 120,20); eb:SetPoint("TOPLEFT",fs,"BOTTOMLEFT",0,-4)
  eb:SetScript("OnEnterPressed", function(self) if onEnterPressed then onEnterPressed(self:GetText()) end self:ClearFocus() end)
  return eb,fs
end

local function MakeScrollPanel(parent)
  local sf = CreateFrame("ScrollFrame", PANEL_NAME.."_ScrollFrame", parent, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -4)
  sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 4)

  local content = CreateFrame("Frame", PANEL_NAME.."_ScrollChild", sf)
  content:SetSize(1,1)
  sf:SetScrollChild(content)

  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll() or 0
    local step = 26
    local rng = self:GetVerticalScrollRange() or 0
    self:SetVerticalScroll(math.max(0, math.min(cur - delta*step, rng)))
  end)

  return sf, content
end

local function Divider(parent, y)
  local t=parent:CreateTexture(nil,"ARTWORK"); t:SetTexture(1,1,1,0.15)
  t:SetPoint("TOPLEFT",16,y); t:SetPoint("RIGHT",-16,y); t:SetHeight(1)
  return t
end

local function ApplyBoth() if BigAurasLite_ApplyBoth then BigAurasLite_ApplyBoth() end end

-- === Tabs ===
local TabsDef = {
  { key="general",  title="General" },
  { key="filters",  title="Filters" },
  { key="style",    title="Style" },
  { key="layout",   title="Layout" },
  { key="second",   title="Secondary" },
  { key="precision",title="Precision" },
  { key="sound",    title="Sound" },        -- NEW
  { key="testing",  title="Testing" },
  { key="spells",   title="Spells" },
}
local TabFrames = {}
local function SelectTab(idx)
  for i,def in ipairs(TabsDef) do
    local btn=TabFrames["tabbtn"..i]
    local page=TabFrames[def.key]
    if btn then PanelTemplates_DeselectTab(btn) end
    if page then page:Hide() end
  end
  local def=TabsDef[idx]
  if def then
    local btn=TabFrames["tabbtn"..idx]; if btn then PanelTemplates_SelectTab(btn) end
    if TabFrames[def.key] then TabFrames[def.key]:Show() end
    TabFrames.active = idx
    if TabFrames[def.key] and TabFrames[def.key].refresh then TabFrames[def.key].refresh() end
  end
end

-- ====== builders ======
local function BuildGeneralTab(frame)
  local sf, content = MakeScrollPanel(frame)
  local y=-48
  local title=content:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
  title:SetPoint("TOPLEFT",16,-16)
  title:SetText("General")

  local db=GetDB(); db.ui=db.ui or {}; db.second=db.second or {}

  local cbUnlock  =MakeCheck(content,"Unlock frames (drag)","Odblokuj i przeciągaj ramki",16,y-24,function(v)
    local unlocked = not not v
    if TargetTracker then TargetTracker.unlocked=unlocked; TargetTracker:showAnchor(unlocked) end
    if FocusTracker  then FocusTracker.unlocked =unlocked; FocusTracker:showAnchor(unlocked)  end
  end); y=y-40

  local cbCombat  =MakeCheck(content,"Only in combat","Ikony tylko podczas walki",16,y,function(v) db.combatOnly=not not v end); y=y-28
  local cbTooltip =MakeCheck(content,"Tooltip","Pokaż tooltip po najechaniu (Hold)",16,y,function(v) db.tooltip=not not v end); y=y-28
  local cbHistory =MakeCheck(content,"Chat log (announce self)","Wypisz na czat przy nowym buffie (lokalnie)",16,y,function(v) db.history=not not v end); y=y-28
  local cbTag     =MakeCheck(content,"Category badge","IMMUNE/OFFENSE/DEFENSE",16,y,function(v) db.showTag=not not v end); y=y-28
  local cbOmni    =MakeCheck(content,"Own timer (block OmniCC-style)","Własne cyfry (blokuj zewnętrzne liczniki)",16,y,function(v) db.blockOmniCC=not not v; ApplyBoth() end); y=y-36

  frame.refresh=function()
    db=GetDB(); db.ui=db.ui or {}; db.second=db.second or {}
    local unlocked = (TargetTracker and TargetTracker.unlocked) or (FocusTracker and FocusTracker.unlocked)
    cbUnlock:SetChecked(unlocked and true or false)
    cbCombat:SetChecked(db.combatOnly or false)
    cbTooltip:SetChecked(db.tooltip~=false)
    cbHistory:SetChecked(db.history~=false)
    cbTag:SetChecked(db.showTag~=false)
    cbOmni:SetChecked(db.blockOmniCC~=false)
  end
end

local function BuildFiltersTab(frame)
  local sf, content = MakeScrollPanel(frame)
  local y=-56
  local title=content:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
  title:SetPoint("TOPLEFT",16,-16)
  title:SetText("Visibility & Filters")

  local db=GetDB()

  local ddFilter,_=MakeDrop(content,"Target filter",{
      {text="Both (enemies & friends)", value="both"},
      {text="Enemies only", value="enemies"},
      {text="Friends only", value="friends"},
    },16,y-8,function(val) db.filter=val end, 240)

  local sMainMin =MakeSlider(content,"Main min remain (sec)",0,3,0.1,340,y-8,function(v) db.mainMinRemain=tonumber(string.format("%.1f",v)) or 0 end,function(v) return string.format("%.1f s",v) end)

  frame.refresh=function()
    db=GetDB()
    UIDropDownMenu_SetSelectedValue(ddFilter, db.filter or "enemies")
    UIDropDownMenu_SetText(ddFilter, (db.filter or "enemies"):gsub("^%l", string.upper))
    sMainMin:SetValueAndText(db.mainMinRemain or 0.0)
  end
end

local function BuildStyleTab(frame)
  local sf, content = MakeScrollPanel(frame)
  local y=-56
  local title=content:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
  title:SetPoint("TOPLEFT",16,-16)
  title:SetText("Borders & Style")

  local db=GetDB(); db.ui=db.ui or {}

  local cbSolid   =MakeCheck(content,"Solid border (custom)","Zamiast klasycznego",16,y-24,function(v) db.ui.useSolid=not not v; ApplyBoth() end)
  local ddStyle,_=MakeDrop(content,"Classic style",{
      {text="Tooltip", value="tooltip"},
      {text="Dialog",  value="dialog"},
    },16,y-64,function(val) db.ui.borderStyle=val; ApplyBoth() end, 220)
  local sEdge  =MakeSlider(content,"Classic edgeSize (main)",10,24,1,340,y-26,function(v) db.ui.edgeSize=math.floor(v); ApplyBoth() end,function(v)return string.format("%d px",math.floor(v)) end)
  local sEdge2 =MakeSlider(content,"Classic edgeSize (second)",10,24,1,340,y-86,function(v) db.ui.edgeSize2=math.floor(v); ApplyBoth() end,function(v)return string.format("%d px",math.floor(v)) end)

  local ddSolidShape,_=MakeDrop(content,"Solid shape",{
      {text="Square",   value="square"},
      {text="Rounded",  value="rounded"},
    },16,y-128,function(val) db.ui.solidShape=val; ApplyBoth() end, 220)
  local sSolidMain   =MakeSlider(content,"Solid thickness (main)",1,32,1,340,y-128,function(v) db.ui.borderPx=math.floor(v); ApplyBoth() end,function(v)return string.format("%d px",math.floor(v)) end)
  local sSolidSecond =MakeSlider(content,"Solid thickness (second)",1,32,1,340,y-188,function(v) db.ui.borderPx2=math.floor(v); ApplyBoth() end,function(v)return string.format("%d px",math.floor(v)) end)
  local sSolidInset  =MakeSlider(content,"Solid inset (main)",0,20,1,340,y-248,function(v) db.ui.solidInset=math.floor(v); ApplyBoth() end,function(v)return string.format("%d px",math.floor(v)) end)
  local sSolidInset2 =MakeSlider(content,"Solid inset (second)",0,20,1,340,y-308,function(v) db.ui.solidInset2=math.floor(v); ApplyBoth() end,function(v)return string.format("%d px",math.floor(v)) end)

  -- === Font & Timer ===
  local yFont = y - 340

  local ddFontPreset,_ = MakeDrop(content,"Font preset",{
      {text="FRIZQT (default)",  value="Fonts\\FRIZQT__.TTF"},
      {text="ARIALN",            value="Fonts\\ARIALN.TTF"},
      {text="MORPHEUS (fancy)",  value="Fonts\\MORPHEUS.TTF"},
      {text="SKURRI (bold)",     value="Fonts\\SKURRI.TTF"},
    },16,yFont,function(val)
      db.style = db.style or {}; db.style.fontPath = val
      if BigAurasLite_ApplyStyle then BigAurasLite_ApplyStyle() end
    end, 240)

  local ebFont,_ = MakeEditBox(content,"Custom font path (overrides preset)", 16, yFont-54, 360)
  ebFont:SetScript("OnEnterPressed", function(self)
    local p = self:GetText() or ""
    if p ~= "" then db.style = db.style or {}; db.style.fontPath = p; UIDropDownMenu_SetSelectedValue(ddFontPreset, nil); UIDropDownMenu_SetText(ddFontPreset, "Custom") end
    if BigAurasLite_ApplyStyle then BigAurasLite_ApplyStyle() end
    self:ClearFocus()
  end)

  local ddOutline,_ = MakeDrop(content,"Font outline",{
      {text="NONE",         value="NONE"},
      {text="OUTLINE",      value="OUTLINE"},
      {text="THICKOUTLINE", value="THICKOUTLINE"},
    },16,yFont-100,function(val)
      db.style = db.style or {}; db.style.fontOutline = val
      if BigAurasLite_ApplyStyle then BigAurasLite_ApplyStyle() end
    end, 180)

  local sBaseSize = MakeSlider(content,"Digits base size",14,48,1,340,yFont,function(v)
    db.style = db.style or {}; db.style.baseSize = math.floor(v)
    if BigAurasLite_ApplyStyle then BigAurasLite_ApplyStyle() end
  end,function(v)return string.format("%d px",math.floor(v)) end)

  local sCdAlpha = MakeSlider(content,"Cooldown spiral alpha",0.0,1.0,0.05,340,yFont-60,function(v)
    db.style = db.style or {}; db.style.cdAlpha = tonumber(string.format("%.2f",v)) or 0.55
    if BigAurasLite_ApplyStyle then BigAurasLite_ApplyStyle() end
  end,function(v) return string.format("%.2f",v) end)

  local cbSpiral = MakeCheck(content,"Show cooldown spiral","Ukryj/pokaż spiralę Cooldown",340,yFont-110,function(v)
    db.style = db.style or {}; db.style.showSpiral = not not v
    if BigAurasLite_ApplyStyle then BigAurasLite_ApplyStyle() end
  end)

  frame.refresh=function()
    db=GetDB(); db.ui=db.ui or {}; db.style=db.style or {}

    cbSolid:SetChecked(db.ui.useSolid==true)
    UIDropDownMenu_SetSelectedValue(ddStyle, db.ui.borderStyle or "tooltip")
    UIDropDownMenu_SetText(ddStyle, (db.ui.borderStyle or "tooltip"):gsub("^%l", string.upper))
    UIDropDownMenu_SetSelectedValue(ddSolidShape, db.ui.solidShape or "square")
    UIDropDownMenu_SetText(ddSolidShape, (db.ui.solidShape or "square"):gsub("^%l", string.upper))
    sEdge:SetValueAndText(db.ui.edgeSize or 16)
    sEdge2:SetValueAndText(db.ui.edgeSize2 or db.ui.edgeSize or 16)
    sSolidMain:SetValueAndText(db.ui.borderPx or 6)
    sSolidSecond:SetValueAndText(db.ui.borderPx2 or db.ui.borderPx or 6)
    sSolidInset:SetValueAndText(db.ui.solidInset or 0)
    sSolidInset2:SetValueAndText(db.ui.solidInset2 or db.ui.solidInset or 0)

    local preset = db.style.fontPath
    local known = {["Fonts\\FRIZQT__.TTF"]=true,["Fonts\\ARIALN.TTF"]=true,["Fonts\\MORPHEUS.TTF"]=true,["Fonts\\SKURRI.TTF"]=true}
    if known[preset] then
      UIDropDownMenu_SetSelectedValue(ddFontPreset, preset)
      UIDropDownMenu_SetText(ddFontPreset, (preset:match("([^\\]+)%.TTF") or "FRIZQT"))
      ebFont:SetText("")
    else
      UIDropDownMenu_SetSelectedValue(ddFontPreset, nil)
      UIDropDownMenu_SetText(ddFontPreset, "Custom")
      ebFont:SetText(preset or "")
    end

    UIDropDownMenu_SetSelectedValue(ddOutline, db.style.fontOutline or "OUTLINE")
    UIDropDownMenu_SetText(ddOutline, db.style.fontOutline or "OUTLINE")
    sBaseSize:SetValueAndText(db.style.baseSize or 26)
    sCdAlpha:SetValueAndText(db.style.cdAlpha or 0.55)
    cbSpiral:SetChecked(db.style.showSpiral~=false)
  end
end

local function BuildLayoutTab(frame)
  local sf, content = MakeScrollPanel(frame)
  local y=-56
  local title=content:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
  title:SetPoint("TOPLEFT",16,-16)
  title:SetText("Layout & Sizing")

  local db=GetDB(); db.ui=db.ui or {}

  -- PRE-DECLARE local helpers so callbacks see them
  local SetPos, Nudge, Center, ApplyAndRefresh, RefreshFields, num, readPointOf

  -- podstawowe kontrolki wyglądu
  local sSize  =MakeSlider(content,"Icon size (contentSize)",32,128,1,340,y-26,function(v) db.ui.contentSize=math.floor(v); ApplyBoth() end,function(v)return string.format("%d px",math.floor(v)) end)
  local sInset =MakeSlider(content,"Content margin (inset)",2,12,1,340,y-86,function(v) db.ui.inset=math.floor(v); ApplyBoth() end,function(v)return string.format("%d px",math.floor(v)) end)
  local ddStrata,_=MakeDrop(content,"Frame Strata",{
      {text="LOW",value="LOW"},{text="MEDIUM",value="MEDIUM"},{text="HIGH",value="HIGH"},
    },16,y-26,function(val) db.ui.strata=val; ApplyBoth() end, 200)

  -- === Positions (Target / Focus) ===
  local yPos = y - 150
  Divider(content, yPos+14)
  local posTitle=content:CreateFontString(nil,"ARTWORK","GameFontNormal")
  posTitle:SetPoint("TOPLEFT",16,yPos)
  posTitle:SetText("Positions (Target / Focus)")

  -- krok przesuwania
  local stepVal = 5
  local sStep = MakeSlider(content, "Nudge step (px)", 1, 50, 1, 340, yPos+2, function(v)
    stepVal = math.floor(v)
  end, function(v) return string.format("%d px", math.floor(v)) end)

  -- Target: strzałki + pola
  local tgtLabel = content:CreateFontString(nil,"ARTWORK","GameFontHighlight")
  tgtLabel:SetPoint("TOPLEFT",16,yPos-36); tgtLabel:SetText("Target")

  local btnTL = MakeButton(content, "<",  16, yPos-56, 28, 22, function() Nudge("target", -stepVal, 0) end)
  local btnTR = MakeButton(content, ">",  48, yPos-56, 28, 22, function() Nudge("target",  stepVal, 0) end)
  local btnTU = MakeButton(content, "^",  80, yPos-56, 28, 22, function() Nudge("target", 0,  stepVal) end)
  local btnTD = MakeButton(content, "v", 112, yPos-56, 28, 22, function() Nudge("target", 0, -stepVal) end)
  btnTL.tooltipText="Left"; btnTR.tooltipText="Right"; btnTU.tooltipText="Up"; btnTD.tooltipText="Down"

  local btnTC = MakeButton(content, "Center", 146, yPos-56, 60, 22, function() Center("target") end)

  local ebTX,_ = MakeEditBox(content,"X",     220, yPos-36, 60)
  local ebTY,_ = MakeEditBox(content,"Y",     290, yPos-36, 60)
  local ebTS,_ = MakeEditBox(content,"Scale", 360, yPos-36, 60)
  local btnTSet = MakeButton(content, "Set", 430, yPos-38, 48, 22, function()
    SetPos("target", ebTX:GetText(), ebTY:GetText(), ebTS:GetText())
  end)

  -- Focus: strzałki + pola
  local fcsLabel = content:CreateFontString(nil,"ARTWORK","GameFontHighlight")
  fcsLabel:SetPoint("TOPLEFT",16,yPos-92); fcsLabel:SetText("Focus")

  local btnFL = MakeButton(content, "<",  16, yPos-112, 28, 22, function() Nudge("focus", -stepVal, 0) end)
  local btnFR = MakeButton(content, ">",  48, yPos-112, 28, 22, function() Nudge("focus",  stepVal, 0) end)
  local btnFU = MakeButton(content, "^",  80, yPos-112, 28, 22, function() Nudge("focus", 0,  stepVal) end)
  local btnFD = MakeButton(content, "v", 112, yPos-112, 28, 22, function() Nudge("focus", 0, -stepVal) end)
  btnFL.tooltipText="Left"; btnFR.tooltipText="Right"; btnFU.tooltipText="Up"; btnFD.tooltipText="Down"

  local btnFC = MakeButton(content, "Center", 146, yPos-112, 60, 22, function() Center("focus") end)

  local ebFX,_ = MakeEditBox(content,"X",     220, yPos-92, 60)
  local ebFY,_ = MakeEditBox(content,"Y",     290, yPos-92, 60)
  local ebFS,_ = MakeEditBox(content,"Scale", 360, yPos-92, 60)
  local btnFSet = MakeButton(content, "Set", 430, yPos-94, 48, 22, function()
    SetPos("focus", ebFX:GetText(), ebFY:GetText(), ebFS:GetText())
  end)

  -- === Mirror Focus względem Target ===
  local yMir = yPos - 150
  Divider(content, yMir+14)
  local mirTitle=content:CreateFontString(nil,"ARTWORK","GameFontNormal")
  mirTitle:SetPoint("TOPLEFT",16,yMir)
  mirTitle:SetText("Mirror Focus ←→ Target")

  local mirrorMode = "h" -- domyślnie horyzontalnie
  local ddMirror,_ = MakeDrop(content, "Mode", {
      {text="Horizontal (<->)", value="h"},
      {text="Vertical (^ v)",   value="v"},
      {text="Both (hv)",        value="b"},
    }, 16, yMir-8, function(val) mirrorMode = val end, 200)

  ----------------------------------------------------------------
  -- HELPERY (lokalne) – sanity check + realny odczyt z frame’ów
  ----------------------------------------------------------------
  num = function(v, def)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return def end
    if v > 5000 then v = 5000 elseif v < -5000 then v = -5000 end
    return v
  end

  local function round(v) return math.floor((tonumber(v) or 0) + 0.5) end

  readPointOf = function(holder)
    if holder and holder.GetPoint then
      local _,_,_,x,y = holder:GetPoint(1)
      return num(x or 0, 0), num(y or 0, 0)
    end
    return nil, nil
  end

  RefreshFields = function()
    local db=GetDB(); db.pos=db.pos or {}; db.pos.target=db.pos.target or {}; db.pos.focus=db.pos.focus or {}

    -- preferuj realne wartości z ramek (po pixel-perfect/snap), fallback: DB
    local tx, ty = readPointOf(_G.TargetTracker and _G.TargetTracker.holder)
    local fx, fy = readPointOf(_G.FocusTracker  and _G.FocusTracker.holder)

    tx = (tx ~= nil) and tx or num(db.pos.target.x or 0, 0)
    ty = (ty ~= nil) and ty or num(db.pos.target.y or 0, 0)
    fx = (fx ~= nil) and fx or num(db.pos.focus.x  or 0, 0)
    fy = (fy ~= nil) and fy or num(db.pos.focus.y  or 0, 0)

    -- czytelne (zaokrąglone) wartości w polach
    ebTX:SetText(tostring(round(tx)))
    ebTY:SetText(tostring(round(ty)))
    ebTS:SetText(string.format("%.2f", num(db.pos.target.scale or 1.0, 1.0)))

    ebFX:SetText(tostring(round(fx)))
    ebFY:SetText(tostring(round(fy)))
    ebFS:SetText(string.format("%.2f", num(db.pos.focus.scale or 1.0, 1.0)))
  end

  ApplyAndRefresh = function()
    if BigAurasLite_ApplyFromDBBoth then BigAurasLite_ApplyFromDBBoth() end
    RefreshFields()
  end

  SetPos = function(kind, x, y, scale)
    local db=GetDB(); db.pos=db.pos or {}; db.pos[kind]=db.pos[kind] or {}
    db.pos[kind].point, db.pos[kind].rel = "CENTER","CENTER"
    if x~=nil and x~="" then db.pos[kind].x = round(num(x, db.pos[kind].x or 0)) end
    if y~=nil and y~="" then db.pos[kind].y = round(num(y, db.pos[kind].y or 0)) end
    if scale~=nil and scale~="" then
      local s = num(scale, db.pos[kind].scale or 1.0)
      if s < 0.5 then s = 0.5 elseif s > 3.0 then s = 3.0 end
      db.pos[kind].scale = s
    end
    ApplyAndRefresh()
  end

  Nudge = function(kind, dx, dy)
    local db=GetDB(); db.pos=db.pos or {}; db.pos[kind]=db.pos[kind] or {}
    db.pos[kind].point, db.pos[kind].rel = "CENTER","CENTER"
    db.pos[kind].x = round(num((db.pos[kind].x or 0) + (dx or 0), 0))
    db.pos[kind].y = round(num((db.pos[kind].y or 0) + (dy or 0), 0))
    ApplyAndRefresh()
  end

  Center = function(kind)
    local db=GetDB(); db.pos=db.pos or {}; db.pos[kind]=db.pos[kind] or {}
    db.pos[kind].point, db.pos[kind].rel = "CENTER","CENTER"
    db.pos[kind].x, db.pos[kind].y = 0, 0
    ApplyAndRefresh()
  end

  -- Mirror po zdefiniowaniu helperów
  local function Mirror(mode)
    local db=GetDB(); db.pos=db.pos or {}; db.pos.target=db.pos.target or {}; db.pos.focus=db.pos.focus or {}
    local tx = db.pos.target.x or 0
    local ty = db.pos.target.y or 0
    local sc = db.pos.target.scale or 1.0
    local fx, fy = tx, ty
    if mode=="h" then fx = -tx; fy = ty
    elseif mode=="v" then fx =  tx; fy = -ty
    else fx = -tx; fy = -ty end
    db.pos.focus.point, db.pos.focus.rel = "CENTER","CENTER"
    db.pos.focus.x, db.pos.focus.y = round(fx), round(fy)
    db.pos.focus.scale = sc
    ApplyAndRefresh()
  end
  local btnMirror = MakeButton(content, "Mirror Focus to Target", 226, yMir-10, 200, 22, function()
    Mirror(mirrorMode or "h")
  end)

  -- initial fill
  RefreshFields()

  -- refresh panel
  frame.refresh=function()
    db=GetDB(); db.ui=db.ui or {}; db.pos=db.pos or {}
    db.pos.target=db.pos.target or {}; db.pos.focus=db.pos.focus or {}

    sSize:SetValueAndText(db.ui.contentSize or 64)
    sInset:SetValueAndText(db.ui.inset or 6)
    UIDropDownMenu_SetSelectedValue(ddStrata, db.ui.strata or "MEDIUM")
    UIDropDownMenu_SetText(ddStrata, db.ui.strata or "MEDIUM")

    sStep:SetValueAndText(stepVal or 5)

    RefreshFields()

    UIDropDownMenu_SetSelectedValue(ddMirror, mirrorMode or "h")
    local mirTxt = (mirrorMode=="v" and "Vertical (^ v)") or (mirrorMode=="b" and "Both (hv)") or "Horizontal (<->)"
    UIDropDownMenu_SetText(ddMirror, mirTxt)
  end
end



local function BuildSecondTab(frame)
  local sf, content = MakeScrollPanel(frame)
  local y=-56
  local title=content:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
  title:SetPoint("TOPLEFT",16,-16)
  title:SetText("Secondary Icon")

  local db=GetDB(); db.second=db.second or {}
  local cbSecond  =MakeCheck(content,"Enable secondary","Pokaz drugi ważny buff",16,y-24,function(v) db.second.enabled=not not v; ApplyBoth() end)
  local ddSecondAnchor,_=MakeDrop(content,"Secondary anchor",{
      {text="Below", value="below"},
      {text="Above", value="above"},
      {text="Left",  value="left"},
      {text="Right", value="right"},
    },16,y-64,function(val) db.second.anchor=val; ApplyBoth() end, 200)

  local sSecondScale =MakeSlider(content,"Secondary scale",0.5,1.2,0.05,340,y-26,function(v) db.second.scale=tonumber(string.format("%.2f",v)) or 0.75; ApplyBoth() end,function(v)return string.format("%.2f",v) end)
  local sSecondGap   =MakeSlider(content,"Secondary gap",0,64,1,340,y-86,function(v) db.second.gap=math.floor(v); ApplyBoth() end,function(v)return string.format("%d px",math.floor(v)) end)
  local sSecondOffX  =MakeSlider(content,"Secondary offset X",-64,64,1,340,y-146,function(v) db.second.offsetX=math.floor(v); ApplyBoth() end,function(v)return string.format("%d px",math.floor(v)) end)
  local sSecondOffY  =MakeSlider(content,"Secondary offset Y",-64,64,1,340,y-206,function(v) db.second.offsetY=math.floor(v); ApplyBoth() end,function(v)return string.format("%d px",math.floor(v)) end)

  frame.refresh=function()
    db=GetDB(); db.second=db.second or {}
    cbSecond:SetChecked(db.second.enabled==true)
    UIDropDownMenu_SetSelectedValue(ddSecondAnchor, db.second.anchor or "below")
    UIDropDownMenu_SetText(ddSecondAnchor, (db.second.anchor or "below"):gsub("^%l", string.upper))
    sSecondScale:SetValueAndText(db.second.scale or 0.75)
    sSecondGap:SetValueAndText(db.second.gap or 8)
    sSecondOffX:SetValueAndText(db.second.offsetX or 0)
    sSecondOffY:SetValueAndText(db.second.offsetY or 0)
  end
end

local function BuildPrecisionTab(frame)
  local sf, content = MakeScrollPanel(frame)
  local y=-56
  local title=content:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
  title:SetPoint("TOPLEFT",16,-16)
  title:SetText("Click-through & Precision")

  local db=GetDB()
  local ddCT,_ = MakeDrop(content,"Click-through mode",{
    {text="Off", value="off"},
    {text="On (no tooltip)", value="on"},
    {text="Hold ALT for tooltip", value="hold"},
  },16,y-8,function(val) db.clickThrough=db.clickThrough or {}; db.clickThrough.mode=val; if BigAurasLite_ApplyBoth then BigAurasLite_ApplyBoth() end end, 240)
  local ddCTMod,_ = MakeDrop(content,"Modifier key (for Hold)",{
    {text="ALT",  value="ALT"},
    {text="SHIFT",value="SHIFT"},
    {text="CTRL", value="CTRL"},
  },16,y-68,function(val) db.clickThrough=db.clickThrough or {}; db.clickThrough.modifier=val; if BigAurasLite_ApplyBoth then BigAurasLite_ApplyBoth() end end, 140)

  local cbGrid = MakeCheck(content,"Snap to grid","Zaokrąglaj pozycje do siatki",16,y-126,function(v) db.grid=db.grid or {}; db.grid.enabled = not not v end)
  local sGrid = MakeSlider(content,"Grid size",2,32,1,340,y-126,function(v) db.grid=db.grid or {}; db.grid.size=math.floor(v) end,function(v) return string.format("%d px",math.floor(v)) end)
  local cbPP = MakeCheck(content,"Pixel perfect","Wyrównuj pozycje/rozmiary do fizycznych pikseli",16,y-186,function(v) db.pixelPerfect = not not v end)

  frame.refresh=function()
    db=GetDB()
    UIDropDownMenu_SetSelectedValue(ddCT, (db.clickThrough and db.clickThrough.mode) or "off")
    UIDropDownMenu_SetText(ddCT, (db.clickThrough and db.clickThrough.mode or "off"):gsub("^%l", string.upper))
    UIDropDownMenu_SetSelectedValue(ddCTMod, (db.clickThrough and db.clickThrough.modifier) or "ALT")
    UIDropDownMenu_SetText(ddCTMod, (db.clickThrough and db.clickThrough.modifier) or "ALT")
    cbGrid:SetChecked(db.grid and db.grid.enabled or false)
    sGrid:SetValueAndText((db.grid and db.grid.size) or 8)
    cbPP:SetChecked(db.pixelPerfect or false)
  end
end

-- === NEW: Sound tab ===
local function BuildSoundTab(frame)
  local sf, content = MakeScrollPanel(frame)
  local y=-48
  local title=content:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
  title:SetPoint("TOPLEFT",16,-16)
  title:SetText("Sound")

  local db=GetDB(); db.sound = db.sound or {}

  local cbOnce = MakeCheck(content,"Play sound only once per aura","Gra dźwięk tylko przy nowej instancji aury",16,y-24,function(v)
    db.sound = db.sound or {}; db.sound.once = not not v
  end)

  local sEps = MakeSlider(content,"Instance detect epsilon",0.000,0.050,0.005,340,y-26,function(v)
    db.sound = db.sound or {}; db.sound.eps = tonumber(string.format("%.3f", v)) or 0.010
  end,function(v) return string.format("%.3f s", v) end)

  Divider(content, y-58); y = y - 76

  local cbUseCd = MakeCheck(content,"Also apply time cooldown","Dodatkowy limiter czasowy (per kategoria)",16,y,function(v)
    db.sound = db.sound or {}; db.sound.useCooldown = not not v
  end); y = y - 28

  local sCd = MakeSlider(content,"Cooldown (sec)",0.0,3.0,0.1,340,y+2,function(v)
    db.sound = db.sound or {}; db.sound.cooldownSec = tonumber(string.format("%.1f", v)) or 2.0
  end,function(v) return string.format("%.1f s", v) end)

  -- refresh
  frame.refresh=function()
    db=GetDB(); db.sound = db.sound or {}
    local once = (db.sound.once ~= false) -- default ON
    cbOnce:SetChecked(once)
    sEps:SetValueAndText(db.sound.eps or 0.010)

    cbUseCd:SetChecked(db.sound.useCooldown or false)
    sCd:SetValueAndText(db.sound.cooldownSec or 2.0)
  end
end

-- Testing (narrow buttons & safe positions)
local function BuildTestingTab(frame)
  local sf, content = MakeScrollPanel(frame)
  local y=-56
  local title=content:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
  title:SetPoint("TOPLEFT",16,-16)
  title:SetText("Testing & Presets")

  content._loop_t = content._loop_t or false
  content._loop_f = content._loop_f or false

  local function UpdateLabels(btnT, btnF)
    if btnT then btnT:SetText(content._loop_t and "Stop Target + Second" or "Start Target + Second") end
    if btnF then btnF:SetText(content._loop_f and "Stop Focus + Second"  or "Start Focus + Second") end
  end

  local btnT = MakeButton(content, "", 16, y, 180, 22, function(self)
    if content._loop_t then BAL("stoploop t"); content._loop_t=false else BAL("testloop t second"); content._loop_t=true end
    UpdateLabels(self, nil)
  end)
  local btnF = MakeButton(content, "", 206, y, 180, 22, function(self)
    if content._loop_f then BAL("stoploop f"); content._loop_f=false else BAL("testloop f second"); content._loop_f=true end
    UpdateLabels(nil, self)
  end)
  local btnStopAll = MakeButton(content, "Stop & Clear (both)", 396, y, 180, 22, function()
    BAL("stoptest")
    content._loop_t=false; content._loop_f=false; UpdateLabels(btnT, btnF)
  end)
  UpdateLabels(btnT, btnF)
  y = y - 36

  Divider(content, y); y=y-18

  MakeButton(content,"UI z defaults",16,y,180,22,function()
    local d=BAL_Defaults().ui local db=GetDB(); db.ui=db.ui or {}; for k,v in pairs(d) do db.ui[k]=v end ApplyBoth()
  end)
  MakeButton(content,"Second z defaults",206,y,180,22,function()
    local d=BAL_Defaults().second local db=GetDB(); db.second=db.second or {}; for k,v in pairs(d) do db.second[k]=v end ApplyBoth()
  end)
  MakeButton(content,"Reset pozycji",396,y,180,22,function()
    local d=BAL_Defaults().pos; local db=GetDB(); db.pos=db.pos or {}; db.pos.target=db.pos.target or {}; db.pos.focus=db.pos.focus or {}
    db.pos.target.point,db.pos.target.rel,db.pos.target.x,db.pos.target.y,db.pos.target.scale = d.target.point,d.target.rel,d.target.x,d.target.y,d.target.scale
    db.pos.focus.point, db.pos.focus.rel, db.pos.focus.x, db.pos.focus.y, db.pos.focus.scale  = d.focus.point, d.focus.rel, d.focus.x, d.focus.y, d.focus.scale
    if BigAurasLite_ApplyFromDBBoth then BigAurasLite_ApplyFromDBBoth() else ApplyBoth() end
  end)

  frame.refresh=function() UpdateLabels(btnT, btnF) end
end

-- Spells – everything under list; lists stretch with panel width
local function BuildSpellsTab(frame)
  local sf, content = MakeScrollPanel(frame)
  local y=-48
  local title=content:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
  title:SetPoint("TOPLEFT",16,-16)
  title:SetText("Spells (tracked)")

  local db=GetDB(); db.tracked=db.tracked or {}

  local function BuildEffectiveTracked()
    local eff = {}
    local defs = BAL_Defaults().tracked or {}
    for id,meta in pairs(defs) do eff[id] = { dur=meta.dur, type=meta.type, note=meta.note } end
    for id,meta in pairs(db.tracked or {}) do
      eff[id] = { dur=meta.dur, type=meta.type or (eff[id] and eff[id].type) or "defense", note=meta.note or "custom" }
    end
    return eff
  end

  -- mini sub-tabs
  local subTabs = {
    {key="immune",  title="IMMUNE"},
    {key="offense", title="OFFENSE"},
    {key="defense", title="DEFENSE"},
  }
  content._subActive = content._subActive or "immune"
  local prevBtn
  for i,st in ipairs(subTabs) do
    local btn=CreateFrame("Button", PANEL_NAME.."_SubTab_"..st.key, content, "OptionsFrameTabButtonTemplate")
    btn:SetText(st.title)
    if i==1 then btn:SetPoint("TOPLEFT",content,"TOPLEFT",12,y) else btn:SetPoint("LEFT", prevBtn, "RIGHT", -10, 0) end
    PanelTemplates_TabResize(btn, 0)
    btn:SetScript("OnClick", function()
      content._subActive = st.key
      for _,st2 in ipairs(subTabs) do
        local b=_G[PANEL_NAME.."_SubTab_"..st2.key]
        if b then if st2.key==content._subActive then PanelTemplates_SelectTab(b) else PanelTemplates_DeselectTab(b) end end
      end
      if content._refreshList then content._refreshList() end
      if content._spellTypeDD then
        UIDropDownMenu_SetSelectedValue(content._spellTypeDD, st.key)
        UIDropDownMenu_SetText(content._spellTypeDD, st.title)
      end
      content._spellType = st.key
    end)
    if st.key==content._subActive then PanelTemplates_SelectTab(btn) else PanelTemplates_DeselectTab(btn) end
    prevBtn=btn
  end
  y = y - 32

  -- search
  local searchLabel = content:CreateFontString(nil,"ARTWORK","GameFontNormal")
  searchLabel:SetPoint("TOPLEFT",16,y)
  searchLabel:SetText("Search")
  local searchEB = CreateFrame("EditBox", PANEL_NAME.."_SpellSearch", content, "InputBoxTemplate")
  searchEB:SetSize(240,20); searchEB:SetPoint("TOPLEFT",searchLabel,"BOTTOMLEFT",0,-4); searchEB:SetAutoFocus(false)
  MakeButton(content, "Clear", 270, y-4, 60, 20, function() searchEB:SetText(""); searchEB:ClearFocus(); if content._refreshList then content._refreshList() end end)
  y = y - 48

  -- LISTA
  local ROWS, rowHeight = 12, 20
  local listBox=CreateFrame("Frame",nil,content)
  listBox:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
  listBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -40, y)
  listBox:SetHeight(ROWS*rowHeight + 24)

  local header=listBox:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
  header:SetPoint("TOPLEFT",listBox,"TOPLEFT",0,0)
  header:SetText("|cffbbbbbbID|r     |cffbbbbbbName|r                                   |cffbbbbbbDur(s)|r")

  local scroll=CreateFrame("ScrollFrame", PANEL_NAME.."_SpellListScroll", listBox, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT",listBox,"TOPLEFT",0,-16)
  scroll:SetPoint("BOTTOMRIGHT",listBox,"BOTTOMRIGHT",-26,0)

  local rows={}
  for i=1,ROWS do
    local btn=CreateFrame("Button", nil, listBox)
    btn:SetHeight(rowHeight); btn:SetPoint("TOPLEFT", listBox, "TOPLEFT", 0, -16-(i-1)*rowHeight)
    btn:SetPoint("RIGHT", listBox, "RIGHT", -26, 0)
    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    local fs=btn:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
    fs:SetPoint("LEFT",btn,"LEFT",6,0); fs:SetJustifyH("LEFT")
    btn.text=fs; rows[i]=btn
  end

  local dataSorted = {}
  local selectedID = nil
  local function catPrio(t) return (t=="immune" and 3) or (t=="offense" and 2) or 1 end

  local function PassesFilter(entry, q, typeOnly)
    if entry.meta and entry.meta.type ~= typeOnly then return false end
    if not q or q=="" then return true end
    q = tostring(q):lower()
    local idStr = tostring(entry.id or ""):lower()
    if idStr:find(q, 1, true) then return true end
    local name = GetSpellInfo(entry.id)
    if name and name:lower():find(q, 1, true) then return true end
    return false
  end

  local function Rebuild(q, typeOnly)
    wipe(dataSorted)
    local eff = BuildEffectiveTracked()
    for id,meta in pairs(eff) do
      local entry = {id=id, meta=meta}
      if PassesFilter(entry, q, typeOnly) then table.insert(dataSorted, entry) end
    end
    table.sort(dataSorted, function(a,b)
      local ta=a.meta and a.meta.type or "defense"
      local tb=b.meta and b.meta.type or "defense"
      if catPrio(ta)~=catPrio(tb) then return catPrio(ta)>catPrio(tb) end
      return (a.id or 0) < (b.id or 0)
    end)
  end

  local function RefreshList()
    local q = searchEB:GetText() or ""
    local typeOnly = content._subActive or "immune"
    Rebuild(q, typeOnly)
    local total=#dataSorted
    FauxScrollFrame_Update(scroll, total, ROWS, rowHeight)
    local offset=FauxScrollFrame_GetOffset(scroll)
    for i=1,ROWS do
      local idx=i+offset
      local btn=rows[i]
      if idx<=total then
        local e=dataSorted[idx]
        local name=GetSpellInfo(e.id) or "Unknown"
        local dur=(e.meta and e.meta.dur) or 0
        btn.text:SetText(string.format("%6d   %-40.40s   %5.1f", e.id, name, dur))
        btn:Show()
        btn:SetScript("OnClick", function()
          selectedID = e.id
          ebID:SetText(tostring(e.id))
          ebDur:SetText(dur>0 and tostring(dur) or "")
          ebNote:SetText((e.meta and e.meta.note) or "")
          local typ=(e.meta and e.meta.type) or "defense"
          UIDropDownMenu_SetSelectedValue(ddType, typ); UIDropDownMenu_SetText(ddType, typ:gsub("^%l", string.upper))
          content._spellType = typ
        end)
      else
        btn:Hide(); btn:SetScript("OnClick", nil)
      end
    end
  end
  content._refreshList = RefreshList
  scroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, rowHeight, RefreshList) end)
  searchEB:SetScript("OnTextChanged", function() RefreshList() end)

  -- ===== EDITORS UNDER LIST =====
  local y2 = y - (ROWS*rowHeight + 36)

  local ebID,_   = MakeEditBox(content,"Spell ID", 16, y2, 120)
  local ddType,_ = MakeDrop(content, "Type", {
    {text="Immune",  value="immune"},
    {text="Offense", value="offense"},
    {text="Defense", value="defense"},
  }, 160, y2, function(val) content._spellType = val end, 140)
  content._spellTypeDD = ddType

  local ebDur,_  = MakeEditBox(content,"Duration (sec) (empty=AUTO)", 16, y2-54, 170)
  local ebNote,_ = MakeEditBox(content,"Note (optional)", 230, y2-54, 346); ebNote:SetMaxLetters(64)

  local function ReadEditors()
    local id = tonumber(ebID:GetText() or "")
    local typ = content._spellType or (content._subActive or "defense")
    local durTxt = ebDur:GetText() or ""
    local dur = tonumber(durTxt)
    if not dur or dur<=0 then dur=nil end -- empty = AUTO
    local note = ebNote:GetText() or ""
    return id, typ, dur, note
  end

  MakeButton(content,"Add / Update", 16, y2-86, 120, 22, function()
    local id,typ,dur,note = ReadEditors(); if not id or not GetSpellInfo(id) then DEFAULT_CHAT_FRAME:AddMessage("|cffff4444BAL|r: Invalid SpellID."); return end
    db.tracked[id] = { type = typ, note = (note~="" and note or "custom") }
    if dur then db.tracked[id].dur = dur end
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00BAL|r: Tracked %d (%s) set: %s%s", id, GetSpellInfo(id) or "?", typ, dur and (", "..tostring(dur).."s") or " (AUTO)"))
    RefreshList(); if BigAurasLite_ApplyBoth then BigAurasLite_ApplyBoth() end
  end)
  MakeButton(content,"Remove", 146, y2-86, 90, 22, function()
    local id = tonumber(ebID:GetText() or ""); if not id then return end
    if db.tracked[id] then db.tracked[id]=nil; DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffae00BAL|r: Removed %d.", id)) end
    ebID:SetText(""); ebDur:SetText(""); ebNote:SetText("")
    RefreshList(); if BigAurasLite_ApplyBoth then BigAurasLite_ApplyBoth() end
  end)
  MakeButton(content,"Reset to defaults", 246, y2-86, 150, 22, function()
    wipe(db.tracked)
    local d=BAL_Defaults().tracked; for k,v in pairs(d) do db.tracked[k] = { dur=v.dur, type=v.type, note=v.note } end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BAL|r: Tracked spells reset to defaults.")
    ebID:SetText(""); ebDur:SetText(""); ebNote:SetText("")
    RefreshList(); if BigAurasLite_ApplyBoth then BigAurasLite_ApplyBoth() end
  end)

  -- ===== ADD FROM TARGET (HELPFUL) =====
  local tgtY = y2 - 126
  Divider(content, tgtY+14)
  local tgtTitle=content:CreateFontString(nil,"ARTWORK","GameFontNormal")
  tgtTitle:SetPoint("TOPLEFT", 16, tgtY)
  tgtTitle:SetText("Add from Target (HELPFUL)")

  MakeButton(content, "Scan target", 160, tgtY-2, 120, 22, function(btn)
    content._tgtAuras = content._tgtAuras or {}
    wipe(content._tgtAuras)
    if not UnitExists("target") then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00BAL|r: No target.")
    else
      for i=1,40 do
        local name,_,_,_,_,duration,expirationTime,_,_,_,id = UnitAura("target", i, "HELPFUL")
        if not id then break end
        local remain=0
        local now=GetTime()
        if duration and duration>0 and expirationTime and expirationTime>now then remain=expirationTime-now end
        table.insert(content._tgtAuras, {id=id, name=name or ("Spell "..id), remain=remain})
      end
      table.sort(content._tgtAuras, function(a,b) return (a.name or "") < (b.name or "") end)
    end
    if content._refreshTgt then content._refreshTgt() end
  end)

  local TROWS, Th = 8, 18
  local tgtList = CreateFrame("Frame", nil, content)
  tgtList:SetPoint("TOPLEFT", content, "TOPLEFT", 16, tgtY-36)
  tgtList:SetPoint("TOPRIGHT", content, "TOPRIGHT", -40, tgtY-36)
  tgtList:SetHeight(TROWS*Th + 24)

  local tgtHdr=tgtList:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
  tgtHdr:SetPoint("TOPLEFT",tgtList,"TOPLEFT",0,0)
  tgtHdr:SetText("|cffbbbbbbID|r     |cffbbbbbbName|r                                   |cffbbbbbbLeft(s)|r")

  local tgtScroll = CreateFrame("ScrollFrame", PANEL_NAME.."_TgtAuraScroll", tgtList, "FauxScrollFrameTemplate")
  tgtScroll:SetPoint("TOPLEFT",tgtList,"TOPLEFT",0,-16)
  tgtScroll:SetPoint("BOTTOMRIGHT",tgtList,"BOTTOMRIGHT",-26,0)

  local trows={}
  for i=1,TROWS do
    local btn=CreateFrame("Button", nil, tgtList)
    btn:SetHeight(Th); btn:SetPoint("TOPLEFT", tgtList, "TOPLEFT", 0, -16-(i-1)*Th)
    btn:SetPoint("RIGHT", tgtList, "RIGHT", -26, 0)
    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    local fs=btn:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
    fs:SetPoint("LEFT",btn,"LEFT",6,0); fs:SetJustifyH("LEFT")
    btn.text=fs; trows[i]=btn
  end

  local tgtData = {}
  local tgtSelectedID = nil
  local function RefreshTgt()
    tgtData = content._tgtAuras or {}
    local total=#tgtData
    FauxScrollFrame_Update(tgtScroll, total, TROWS, Th)
    local offset=FauxScrollFrame_GetOffset(tgtScroll)
    for i=1,TROWS do
      local idx=i+offset
      local btn=trows[i]
      if idx<=total then
        local e=tgtData[idx]
        btn.text:SetText(string.format("%6d   %-40.40s   %6.1f", e.id or 0, (e.name or "?"), (e.remain or 0)))
        btn:Show()
        btn:SetScript("OnClick", function()
          tgtSelectedID = e.id
          local eff = BuildEffectiveTracked()
          local meta = eff[tgtSelectedID]
          local typ = (meta and meta.type) or "defense"
          ebID:SetText(tostring(tgtSelectedID)); ebDur:SetText(""); -- AUTO
          UIDropDownMenu_SetSelectedValue(ddType, typ); UIDropDownMenu_SetText(ddType, typ:gsub("^%l", string.upper))
          content._spellType = typ
          ebNote:SetText((meta and meta.note) or "")
        end)
      else
        btn:Hide(); btn:SetScript("OnClick", nil)
      end
    end
  end
  content._refreshTgt = RefreshTgt
  tgtScroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, Th, RefreshTgt) end)

  MakeButton(content,"Add selected (AUTO)", 16, tgtY-36 - (TROWS*Th + 28), 160, 22, function()
    if not tgtSelectedID then return end
    local id = tgtSelectedID
    local eff = BuildEffectiveTracked()
    local meta = eff[id]
    local typ = (meta and meta.type) or (content._spellType or "defense")
    db.tracked[id] = { type = typ, note = (meta and meta.note) or "custom" }
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00BAL|r: Added from target %d (%s) as %s (AUTO).", id, GetSpellInfo(id) or "?", typ))
    RefreshList(); if BigAurasLite_ApplyBoth then BigAurasLite_ApplyBoth() end
  end)

  -- final refresh
  content.refresh=function()
    db=GetDB(); db.tracked=db.tracked or {}
    content._spellType = content._subActive or "immune"
    UIDropDownMenu_SetSelectedValue(ddType, content._spellType)
    UIDropDownMenu_SetText(ddType, (content._spellType):gsub("^%l", string.upper))
    searchEB:SetText("")
    if ebID then ebID:SetText("") end
    if ebDur then ebDur:SetText("") end
    if ebNote then ebNote:SetText("") end
    if content._tgtAuras then wipe(content._tgtAuras) end
    RefreshList(); RefreshTgt()
  end
end

-- main panel (tabs in 2 rows)
local function CreateOptionsPanel()
  if panel then return end
  panel=CreateFrame("Frame",PANEL_NAME,UIParent); panel.name=PANEL_NAME

  local title=panel:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
  title:SetPoint("TOPLEFT",16,-16)
  title:SetText("BigAurasLite — Options")

  local firstRow = {1,2,3,4}; local secondRow= {5,6,7,8,9} -- +sound tab
  local prev
  for _,pos in ipairs(firstRow) do
    local def = TabsDef[pos]
    local btn=CreateFrame("Button", PANEL_NAME.."_Tab"..pos, panel, "OptionsFrameTabButtonTemplate")
    btn:SetText(def.title)
    if pos==firstRow[1] then btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -40) else btn:SetPoint("LEFT", prev, "RIGHT", -10, 0) end
    PanelTemplates_TabResize(btn, 0); PanelTemplates_DeselectTab(btn)
    btn:SetScript("OnClick", function() SelectTab(pos) end); TabFrames["tabbtn"..pos]=btn; prev=btn
  end
  local prev2
  for _,pos in ipairs(secondRow) do
    local def = TabsDef[pos]
    local btn=CreateFrame("Button", PANEL_NAME.."_Tab"..pos, panel, "OptionsFrameTabButtonTemplate")
    btn:SetText(def.title)
    if pos==secondRow[1] then btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -68) else btn:SetPoint("LEFT", prev2, "RIGHT", -10, 0) end
    PanelTemplates_TabResize(btn, 0); PanelTemplates_DeselectTab(btn)
    btn:SetScript("OnClick", function() SelectTab(pos) end); TabFrames["tabbtn"..pos]=btn; prev2=btn
  end

  local belowTabsY = -96
  for i,def in ipairs(TabsDef) do
    local page=CreateFrame("Frame", PANEL_NAME.."_Page_"..def.key, panel)
    page:SetPoint("TOPLEFT", 12, belowTabsY); page:SetPoint("BOTTOMRIGHT", -12, 16); page:Hide()
    TabFrames[def.key]=page
  end

  -- build
  BuildGeneralTab(TabFrames.general)
  BuildFiltersTab(TabFrames.filters)
  BuildStyleTab(TabFrames.style)
  BuildLayoutTab(TabFrames.layout)
  BuildSecondTab(TabFrames.second)
  BuildPrecisionTab(TabFrames.precision)
  BuildSoundTab(TabFrames.sound)       -- NEW
  BuildTestingTab(TabFrames.testing)
  BuildSpellsTab(TabFrames.spells)

  SelectTab(1)
  InterfaceOptions_AddCategory(panel)
end

local f=CreateFrame("Frame"); f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent",function(_,evt,name) if evt=="ADDON_LOADED" and (name=="BigAurasLite" or name==PANEL_NAME) then CreateOptionsPanel() end end)

SLASH_BIGALOPT1="/balopt"; SLASH_BIGALOPT2="/baloptions"
SlashCmdList.BIGALOPT=function() InterfaceOptionsFrame_OpenToCategory(PANEL_NAME); InterfaceOptionsFrame_OpenToCategory(PANEL_NAME) end
