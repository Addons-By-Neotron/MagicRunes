--[[
**********************************************************************
Magic Runes RuneBars - Death Knight rune cooldown displaye
**********************************************************************
This file is part of Magic Runes, a World of Warcraft Addon

Magic Runes is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Magic Runes is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with Magic Runes.  If not, see <http://www.gnu.org/licenses/>.

**********************************************************************
]]
if not MagicRunes then return end -- not a DK


local MODULE_NAME = "RuneBars"
local mod = MagicRunes
local module = mod:NewModule(MODULE_NAME, "LibSimpleBar-1.0", "LibMagicUtil-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("MagicRunes", false)
local LBF = LibStub("LibButtonFacade", true)
local media = LibStub("LibSharedMedia-3.0")
local pdb, db

local debug
--[===[@debug@
debug = true
--@end-debug@]===]
if debug then
   MRB = module
end


local defaults = {
   -- Background frame
   backdropColors = {
      backgroundColor = { 0, 0, 0, 0.5},
      borderColor = { 0.88, 0.88, 0.88, 0.8 },
   },
   background = "Solid",
   border = "None",
   edgeSize = 16,
   inset = 4,
   padding = 2,

   spacing = 0, 
   scale = 1.0, 
   width = 200,
   height = 20,

   fontsize = 12,
   font = "Friz Quadrata TT",

   enabled = false
}

function module:OnInitialize()
   module:SetupDefaultOptions()
   module:CreateFrame()
   module.bars = {}
   for id = 1,6 do
      module:CreateBar()
   end
   module:SetSize()
   module:SortBars()
end

function module:SkinChanged(skinId, gloss, backdrop, group, button, colors)
   if group == "Rune Bars" then
      db.skinId = skinId
      db.gloss = gloss
      db.backdrop = backdrop
      db.colors = colors
   end

end

function module:OnEnable()
   if LBF then
      local lbfGroup = LBF:Group("MagicRunes", "Rune Bars")

      lbfGroup.SkinID = db.skinId or "Zoomed"
      lbfGroup.Backdrop = db.backdrop
      lbfGroup.Gloss = db.gloss
      lbfGroup.Colors = db.colors or {}

      LBF:RegisterSkinCallback("MagicRunes", module.SkinChanged, self)
      for _, frame in pairs(module.bars) do
	 lbfGroup:AddButton(frame.iconbutton)
      end
   end
   module.options.args.backgroundFrame = module:GetConfigTemplate("background")
   module.options.args.barsize         = module:GetConfigTemplate("barsize")
   module.options.args.backgroundFrame.hidden = "IsDisabled"
   module.options.args.barsize.hidden = "IsDisabled"
   mod:OptReg("Rune Bars", module.options, L["Rune Bars"])
   module:ApplyProfile()
end

function module:OnDisable()
end

do
   local nextUpdateDelay = 0
   function module:OnUpdate(time, runeData)
      if not db.enabled then return end
      nextUpdateDelay = nextUpdateDelay - time
      local active = false
      if time == 0 or nextUpdateDelay <= 0 then
	 nextUpdateDelay = 0.05 
	 
	 for id, data in pairs(runeData) do
	    local f = module.bars[id]
	    f.bar:SetAlpha(data.alpha)
	    if not data.ready and data.start and data.duration then
	       f.cooldown:SetCooldown(data.start, data.duration)
	       active = true
	       f.notReady = true
	    elseif data.ready and f.notReady then
	       f.notReady = false
	       if pdb.readyFlash then
		  mod:AddReadyFlash(f)
	       end
	    end
	    f.bar:SetValue(data.value, 10)
	    -- Handle death runes changes
	    if f.type ~= data.type then
	       f.type = data.type
	       f.icon:SetTexture(mod:GetRuneIcon(f.type))
	       module:SetBarColor(f)
	    end	 	    
	 end
      end
   end
end

function module:OnDragStart()
   if pdb.locked then return end
   module.frame:StartMoving()
end

function module:OnDragStop()
   module:SavePosition()      
   module.frame:StopMovingOrSizing()
end

function module:SetHandlePoints()
   module.handle:ClearAllPoints()
   if pdb.growup then
      module.handle:SetPoint("TOPLEFT", module.frame, "BOTTOMLEFT")
      module.handle:SetPoint("TOPRIGHT", module.frame, "BOTTOMRIGHT")
   else
      module.handle:SetPoint("BOTTOMLEFT", module.frame, "TOPLEFT")
      module.handle:SetPoint("BOTTOMRIGHT", module.frame, "TOPRIGHT")
   end
    -- We change point from bottom to top and vice versa when changing
   -- growth direction
   module:SavePosition()
   module:LoadPosition()
end

function module:CreateFrame()
   module.frame = CreateFrame("Frame", nil, UIParent)
   module.frame:SetMovable(true)

   local handle = CreateFrame("Frame", nil, UIParent)
   module.handle = handle
   handle:RegisterForDrag("LeftButton")
   handle:EnableMouse(not pdb.locked)
   handle:SetScript("OnDragStart", module.OnDragStart)
   handle:SetScript("OnDragStop", module.OnDragStop)

   module:SetHandlePoints()

   handle.label = handle:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
   handle.label:SetAllPoints()
   handle.label:SetText("Rune Bars")
   handle:SetBackdrop( {
			 bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			 edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			 inset = 4,
			 edgeSize = 8,
			 tile = true,
			 insets = {left = 2, right = 2, top = 2, bottom = 2}
		      })
   
   local c = db.backdropColors.backgroundColor
   handle:SetBackdropColor(c[1], c[2], c[3], c[4] > 0.2 and c[4] or 0.7)

   c = db.backdropColors.borderColor
   handle:SetBackdropBorderColor(c[1], c[2], c[3], c[4] > 0.2 and c[4] or 0.7)
   module:SetHandleFont()
end

function module:CreateBar()
   local frame = CreateFrame("Frame", nil, module.frame)
   frame.bar = module:NewSimpleBar(frame, 0, 100, db.width, db.height)
   frame.bar:SetPoint("RIGHT", frame, "RIGHT", 0)

   frame:SetHeight(db.height)
   frame:SetWidth(db.width + db.height + 4)

   -- Create the rune icon
   local id = #module.bars+1
   local fn = "MagicRunesBarIcon"..id
   local iconbutton = CreateFrame("Button", fn , frame, "ActionButtonTemplate")
   iconbutton:EnableMouse(false)
   frame.cooldown = _G[fn.."Cooldown"]
   frame.iconborder = _G[fn.."Border"]
   frame.icon = _G[fn.."Icon"]
   frame.iconnt = _G[fn.."NormalTexture"]


   frame.iconnt:ClearAllPoints()
   local name, icon, type, color = mod:GetRuneInfo(id)
   frame.icon:SetTexture(icon)
   frame.type = type
   frame.runeId = id

   frame.iconbutton = iconbutton
   frame.iconnt:Hide()

   module:SetBarColor(frame, color)
   
   iconbutton:SetPoint("RIGHT", frame.bar, "LEFT", -4)
   iconbutton:SetPoint("LEFT", frame, "LEFT")


   frame.overlayTexture =  frame.bar:CreateTexture(nil, "OVERLAY")
   frame.overlayTexture:SetTexture("Interface/Buttons/UI-Listbox-Highlight2")
   frame.overlayTexture:SetBlendMode("ADD")
   frame.overlayTexture:SetVertexColor(1,1,1,0.6)
   frame.overlayTexture:SetAllPoints()
   frame.overlayTexture:SetAlpha(0)
   
   module.bars[#module.bars+1] = frame
   module:SetTexture(frame)
   return frame
end

function module:SetBarColor(frame, color)
   local color = color or select(4, mod:GetRuneInfo(frame.runeId))
   if color then
      frame.bar:SetColor(unpack(color))
   end
end


function module:SortBars()
   local w, h = 0,0
   local anchor
   --   tsort(mod.bars, function(f1, f2) local a, b = (f1.bar.value/f1.bar.maxValue),  (f2.bar.value/f2.bar.maxValue) if a == b then return f1.guid > f2.guid else return a > b end end)
   local start = 0
   for id, frame in pairs(module.bars) do
      local fw, fh = frame:GetWidth(), frame:GetHeight()
      frame:ClearAllPoints()

      if fw > w then w = fw end
      h = h + fh + db.spacing
      
      if pdb.growup then
	 if anchor then
	    frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, db.spacing)
	    frame:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, db.spacing)
	 else
	    frame:SetPoint("BOTTOMLEFT", module.frame, "BOTTOMLEFT", db.padding, db.padding)
	    frame:SetPoint("BOTTOMRIGHT", module.frame, "BOTTOMRIGHT", -db.padding, db.padding)
	 end
      else
	 if anchor then
	    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -db.spacing)
	    frame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -db.spacing)
	 else
	    frame:SetPoint("TOPLEFT", module.frame, "TOPLEFT", db.padding, -db.padding)
	    frame:SetPoint("TOPRIGHT", module.frame, "TOPRIGHT", -db.padding, -db.padding)
	 end
      end
      anchor = frame
      frame:Show()
   end

   local p2 = db.padding*2
   w = w+p2
   db.lastWidth = w
   module.frame:SetWidth(w)
   module.frame:SetHeight(h+p2)
end


function module:SetTexture(frame)
   local t = media:Fetch("statusbar", db.texture)
   if frame then
      frame.bar:SetTexture(t)
   else
      for _, frame in pairs(module.bars) do
	 module:SetTexture(frame)
      end
   end
end

do
   local function SetLabelFont(label, newFont, newSize, newFlags)
      local font, size, flags = label:GetFont()
      label:SetFont(newFont or font, newSize or size, newFlags or flags)
   end
   
   function module:SetHandleFont()
      local h = module.handle
      local font = media:Fetch("font", db.font)
      SetLabelFont(h.label, font, db.fontsize)
      h:SetHeight(h.label:GetHeight()+10)
   end
end

function module:ToggleLocked(locked)
   if locked then
      module.handle:Hide()
   else
      module.handle:Show()
   end
   module.handle:EnableMouse(not locked)
end


function module:ApplyProfile()
   if not module.frame then return end
   module:SetupDefaultOptions()
   module:SetHandleFont()
   module:SetHandlePoints()
   module:FixBackdrop()
   module:EnableToggled()
end

function module:SavePosition()
   local s = module.frame:GetEffectiveScale()
   local top = module.frame:GetTop()
   if not top then return end -- hmm
   if db.flipy then
      db.posy = module.frame:GetBottom() * s
      db.anchor = "BOTTOM"
   else
      db.posy =  top * s - UIParent:GetHeight()*UIParent:GetEffectiveScale() 
      db.anchor = "TOP"
   end
   if db.flipx then
      db.anchor = db.anchor .. "RIGHT"
      db.posx = module.frame:GetRight() * s - UIParent:GetWidth()*UIParent:GetEffectiveScale() 
   else
      db.anchor = db.anchor .. "LEFT"
      db.posx = module.frame:GetLeft() * s
   end
end

function module:IsDisabled() return not db.enabled end

function module:LoadPosition(bin)
   local posx = db.posx 
   local posy = db.posy
   local anchor = db.anchor
   module.frame:ClearAllPoints()
   if not anchor then anchor = "TOPLEFT" end

   local s = module.frame:GetEffectiveScale()

   if posx and posy then
      module.frame:SetPoint(anchor, posx/s, posy/s)
   else
      module.frame:SetPoint(anchor, UIParent, "CENTER")
   end
end

function module:SetupDefaultOptions()
   db = mod.db.profile.runebars or {}
   for key, val in pairs(defaults) do
      if db[key] == nil then
	 db[key] = val
      end
   end
   mod.db.profile.runebars = db
   pdb = mod.db.profile
   module.db = db
end

function module:OnOptionChanged(var, val)
   if var == "maxbars"  or var == "spacing" or var == "padding" then
      module:SortBars()
   elseif var == "height" or var == "width" then
      module:SetSize()
   elseif var == "scale" then
      module.handle:SetScale(val)
      module.frame:SetScale(val)
      module:LoadPosition()
   elseif var == "enabled" then
      module:EnableToggled()
   end
end

function module:EnableToggled()
   if db.enabled then
      module.frame:Show()
      module:ToggleLocked(pdb.locked)
   else
      module.frame:Hide()
      module.handle:Hide()
   end
end

function module:SetSize()
   for _, frame in ipairs(module.bars) do
      frame.bar:SetLength(db.width)
      frame.bar:SetThickness(db.height)
      frame:SetWidth(db.width+db.height+4)
      frame:SetHeight(db.height)

      frame.iconbutton:SetScale(db.height/frame.iconbutton:GetWidth())
      
   end
   module:SortBars()
end

module.options = {
   type = "group",
   name = L["Rune Bars"],
   handler = module,
   get = "_GetOption",
   set = "_SetOption",
   childGroups = "tab",
   args = {
      enabled = {
	 type = "toggle",
	 name = L["Enable Rune Bars"], 
	 order = 1,
      },
      help = {
	 type = "group",
	 name = L["Documentation"],
	 args = {
	    intro = {
	       type = "group",
	       name = L["Introduction"],
	       order = 1,
	       args = {
		  header1 = {
		     type = "header",
		     name = L["Rune Bars Introduction"],
		     order = 10
		  },
		  desc1 = {
		     type = "description",
		     name =
			L["The Rune Bar module is a replacement for the built-in original rune bars. It is currently not complete but is entirely usable."].." "..
			L["Many options in the module core is used for this addon, such as alpha levels, alpha flash, ready flash and rune icon set."].." "..
			L["Color flash does not work with these bars, nor are there any labels yet."].."\n\n"..
			L["NOTE: RUNE BARS IS STILL WORK IN PROGRESS. Many features are still missing!"],
		     order = 15
		  },
	       },
	    },
	    buttonfacade = {
	       type = "group",
	       name = L["Button Facade"],
	       order = 30,
	       args = {
		  header = {
		     type = "header",
		     name = L["Button Facade"],
		     order = 10,
		  },
		  desc = {
		     type = "description",
		     name =
			L["The icons are fully integrated with the ButtonFacade addon. This addon lets you skin the buttons for a more personalized display.\n\n"]..
			L["To configure the looks, open the ButtonFacade configuration UI using the /buttonfacade command. Select Addons => Magic Runes => Rune Bars.\n\n"]..
			L["You can find ButtonFacade and many different skins on http://wow.curse.com/"],
		     order = 20,
		  },		  
	       }
	    }, 
	    background = {
	       type = "group",
	       name = L["Background Frame"],
	       order = 20,
	       args = {
		  header = {
		     type = "header",
		     name = L["Background Frame"],
		     order = 10,
		  },
		  desc = {
		     type = "description",
		     name =
			L["The background frames allows you to set an optional backdrop behind the bars. You can configure the border and background texture and color.\n\n"]..
			L["The width of the border is controlled by the edge size parameter. To add some extra padding between the border and icons you can set the padding.\n\n"]..
			L["To be able to change the border and background you need the SharedMedia and SharedMedia-Blizzard addons installed. You can find these at http://www.curse.com/\n\n"],
		     order = 20,
		  },		  
	       }
	    },	    
	 }
      }
   }
}
