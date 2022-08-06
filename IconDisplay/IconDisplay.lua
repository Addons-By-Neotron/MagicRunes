--[[
**********************************************************************
MagicRunes Icon Display - Death Knight rune cooldown display, icon style
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

This file is used for an optiona advanced icon-only display mode
]]

if not MagicRunes then return end -- not a DK

local MODULE_NAME = "IconDisplay"
local mod = MagicRunes
local module = mod:NewModule(MODULE_NAME, "LibMagicUtil-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("MagicRunes", false)
local LBF = LibStub("Masque", true)
local media = LibStub("LibSharedMedia-3.0")

local pairs = pairs
local _G = _G
local select = select
local UIParent = UIParent
local ipairs = ipairs
local ceil = math.ceil
local unpack = unpack
local sin = math.sin
local cos = math.cos
local degreeToRadian = math.pi / 180

local mod = MagicRunes
local icons = {}
local playerInCombat = InCombatLockdown()


-- Different layout options
module.STYLE_STRAIGHT    = 1
module.STYLE_CIRCLE      = 2
module.STYLE_ELLIPSE     = 3


-- Also includes defaults
local defaults = {
   runeSet = "Blizzard Improved", 
   vertSpacing = 1,
   horizSpacing = 1,
   scale = 1.0,
   layout = 1,
   oocAlpha = 1, 
   runeOrder = 1,
   width = 6,
   edgeSize = 16,
   inset = 4,
   padding = 2, 
   backdropColors = {
      backgroundColor = { 0, 0, 0, 0.5},
      borderColor = { 0.88, 0.88, 0.88, 0.8 },
   },
   background = "Solid",
   border = "None",
   style = module.STYLE_STRAIGHT,
   tile = false,
   tileSize = 32,
   -- Circle
   radius = 100,
   -- Ellipsis layout
   majorRadius = 100,
   minorRadius = 80,
   spread = 216,
   startAngle = 180,
   -- advanced circle positions
   blood1Angle = 0,
   blood2Angle = 60,
   unholy1Angle = 120,
   unholy2Angle = 180,
   frost1Angle = 240,
   frost2Angle = 300,

}

local runeOrder = {
   { 1, 2, 3, 4, 5, 6}, -- BBUUFF
   { 1, 3, 5, 2, 4, 6}, -- BUFBUF
   { 1, 2, 5, 6, 3, 4}, -- BBFFUU
   { 1, 2, 5, 3, 6, 4}, -- BBFUFU
   { 5, 3, 6, 4, 1, 2}, -- FUFUBB
   { 1, 5, 3, 4, 6, 2}, -- BFUUFB
   { 1, 3, 5, 6, 4, 2}, -- BUFFUB
}


-- Called every on update cycle
local nextUpdateDelay = 0
local runesAreActive = false

function module:OnUpdate(time, runeData)
   nextUpdateDelay = nextUpdateDelay - time
   local active = false
   if time == 0 or nextUpdateDelay <= 0 then
      nextUpdateDelay = 0.05 
      for id, data in pairs(runeData) do
	 local f = icons[id]
	 f:SetAlpha(data.alpha)
	 if not data.ready and data.start and data.duration then
	    f.cooldown:SetCooldown(data.start, data.duration)
	    active = true
	 end
	 
	 -- Handle death runes changes
	 if f.type ~= data.type then
	    f.type = data.type
	    f.icon:SetTexture(mod:GetRuneIcon(f.type, module.db.runeSet))
	 end	 
      end
      if active ~= runesAreActive and module.db.oocAlpha ~= 1 then
	 runesAreActive = active
	 module:SetFrameColor()
      end
   end
end

function module:SkinChanged(skinId, gloss, backdrop, group, button, colors)
   if group == "Icon Display" then
      module.db.skinId = skinId
      module.db.gloss = gloss
      module.db.backdrop = backdrop
      module.db.colors = colors
   end
end

function module:OnInitialize()
   module:SetupDefaultOptions()
   module.frame = CreateFrame("Frame", "MagicRunesIconFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
   module.frame:SetScale(module.db.scale)
   module.frame:SetMovable(true)
   module.frame:SetFrameLevel(0)
   module.frame:SetScript("OnDragStart",
		       function(self) self:StartMoving() end)
   module.frame:SetScript("OnDragStop",
		       function(self)
			  module:SavePosition()
			  self:StopMovingOrSizing()
		       end)
   
   for id = 1, 6 do
      local fn = "MagicRunesIcon"..id
      
      -- Rune frame
      local f = CreateFrame("Button", fn , module.frame, "ActionButtonTemplate")
      module.frameSize = f:GetWidth()
      f:EnableMouse(false)
      f.cooldown = _G[fn.."Cooldown"]
      f.icon = _G[fn.."Icon"]
      local icon, type = select(2, mod:GetRuneInfo(id, module.db.runeSet))
      f.icon:SetTexture(icon)
      f.type = type
      f.runeId = id
      icons[id] = f
   end
end

function module:OnEnable()
   -- Skin setup
   if LBF then
      local lbfGroup = LBF:Group("MagicRunes", "Icon Display")
      lbfGroup.SkinID = module.db.skinId or "Zoomed"
      lbfGroup.Backdrop = module.db.backdrop
      lbfGroup.Gloss = module.db.gloss
      lbfGroup.Colors = module.db.colors or {}
      LBF:Register("MagicRunes", module.SkinChanged, self)
      for i = 1, 6 do 
	 lbfGroup:AddButton(icons[i])
      end
   end
   module:SetupOptions()
   module:ApplyProfile()
end

function module:ApplyProfile()
   module:SetupDefaultOptions()
   module:ToggleLocked(mod.db.profile.locked)
   module:AnchorIcons()
   module:LoadPosition()
   module:SetFrameColor()

   if module.db.enabled then module.frame:Show() else module.frame:Hide() end
   for id = 1,6 do
      icons[id].icon:SetTexture(mod:GetRuneIcon(icons[id].type, module.db.runeSet))
   end
end

function module:SavePosition()
   local s = module.frame:GetEffectiveScale()
   local top = module.frame:GetTop()
   if not top then return end -- hmm
   if module.db.flipy then
      module.db.posy = module.frame:GetBottom() * s
      module.db.anchor = "BOTTOM"
   else
      module.db.posy =  top * s - UIParent:GetHeight()*UIParent:GetEffectiveScale() 
      module.db.anchor = "TOP"
   end
   if module.db.flipx then
      module.db.anchor = module.db.anchor .. "RIGHT"
      module.db.posx = module.frame:GetRight() * s - UIParent:GetWidth()*UIParent:GetEffectiveScale() 
   else
      module.db.anchor = module.db.anchor .. "LEFT"
      module.db.posx = module.frame:GetLeft() * s
   end
end

function module:LoadPosition(bin)
   local posx = module.db.posx 
   local posy = module.db.posy
   local anchor = module.db.anchor
   module.frame:ClearAllPoints()
   if not anchor then anchor = "TOPLEFT" end

   local s = module.frame:GetEffectiveScale()

   if posx and posy then
      module.frame:SetPoint(anchor, posx/s, posy/s)
   else
      module.frame:SetPoint(anchor, UIParent, "CENTER")
   end
end

function module:AnchorIcons()
   for id = 1,6 do icons[id]:ClearAllPoints() end

   if module.db.style == module.STYLE_STRAIGHT then
      module:AnchorIconsStraight()
   elseif module.db.style == module.STYLE_CIRCLE or module.db.style == module.STYLE_ELLIPSE then
      if module.db.advanced then
	 module:AnchorIconsEllipiseAdvanced()
      else
	 module:AnchorIconsEllipiseBasic()
      end
   end
   module:FixBackdrop()
end

do
   -- Maps rune id to angle parameter
   local idToAngle = {
      "blood1Angle",
      "blood2Angle",
      "unholy1Angle",
      "unholy2Angle",
      "frost1Angle",
      "frost2Angle"
   }
   function module:AnchorIconsEllipiseAdvanced()
      local mx, my
      local iconPositions = {}
      local minx, miny, maxx, maxy = 0, 0, 0, 0
      local inset = icons[1]:GetWidth()/2 + module.db.padding
      if module.db.style == module.STYLE_ELLIPSE then
	 mx = module.db.majorRadius
	 my = module.db.minorRadius
      else
	 mx, my = module.db.radius, module.db.radius
      end
      if module.db.border ~= "None" then
	 inset = inset + module.db.edgeSize / 4
      end
      for id  = 1, 6 do
	 local angle = module.db[idToAngle[id]]*degreeToRadian
	 local x = mx * cos(angle)
	 local y = my * sin(angle)
	 if x < minx then minx = x end
	 if x > maxx then maxx = x end
	 if y < miny then miny = y end
	 if y > maxy then maxy = y end
	 iconPositions[#iconPositions+1] = { id = id, x = x, y = y } 
      end
      for _,data in ipairs(iconPositions) do
	 icons[data.id]:SetPoint("CENTER", module.frame, "TOPLEFT", inset + data.x - minx, -(inset + data.y - miny))
      end
      module.frame:SetWidth(maxx - minx + inset*2)
      module.frame:SetHeight(maxy - miny + inset*2)
   end
   
   function module:AnchorIconsEllipiseBasic()
      local iconPositions = {}
      local angle = module.db.startAngle* degreeToRadian
      local step = module.db.spread / 6 * degreeToRadian
      local mx, my
      if module.db.reverseOrder then
	 step = -step
      end
      if module.db.style == module.STYLE_ELLIPSE then
	 mx = module.db.majorRadius
	 my = module.db.minorRadius
      else
	 mx, my = module.db.radius, module.db.radius
      end
      local minx, miny, maxx, maxy = 0, 0, 0, 0
      local inset = icons[1]:GetWidth()/2 + module.db.padding
      if module.db.border ~= "None" then
	 inset = inset + module.db.edgeSize / 4
      end
      
      for _,id in ipairs(runeOrder[module.db.runeOrder]) do
	 local x = mx * cos(angle)
	 local y = my * sin(angle)
	 if x < minx then minx = x end
	 if x > maxx then maxx = x end
	 if y < miny then miny = y end
	 if y > maxy then maxy = y end
	 iconPositions[#iconPositions+1] = { id = id, x = x, y = y }
	 angle = angle + step
      end
      for _,data in ipairs(iconPositions) do
	 icons[data.id]:SetPoint("CENTER", module.frame, "TOPLEFT", inset + data.x - minx, -(inset + data.y - miny))
      end
      module.frame:SetWidth(maxx - minx + inset*2)
      module.frame:SetHeight(maxy - miny + inset*2)
   end
end


function module:AnchorIconsStraight()
   local anchor, xmulti, ymulti, otheranchor
   local count = 1
   
   local inset = module.db.padding
   if module.db.border ~= "None" then
      inset = inset + module.db.edgeSize / 4
   end
   
   if module.db.flipy then
      anchor = "BOTTOM"
      ymulti = 1
   else
      anchor = "TOP"
      ymulti = -1
   end
   
   if module.db.flipx then
      anchor = anchor .. "RIGHT"
      xmulti = -1 
   else
      anchor = anchor .. "LEFT"
      xmulti = 1
   end
   
   local hpadding = (module.frameSize + (module.db.horizSpacing or 0))
   local vpadding = (module.frameSize + (module.db.vertSpacing or 0))
   
   local height = inset
   local xoffset = inset
   
   for _,id in ipairs(runeOrder[module.db.runeOrder]) do
      if count > module.db.width then
	 xoffset = inset
	 count = 1
	 height = height + vpadding
      end
      
      icons[id]:SetPoint(anchor, module.frame, anchor, xmulti*xoffset, ymulti*height)
      
      count = count + 1
      xoffset = xoffset + hpadding
   end
   module.frame:SetHeight(inset*2 + ceil(6/module.db.width)*vpadding-module.db.vertSpacing)
   module.frame:SetWidth(inset*2 + module.db.width*hpadding - module.db.horizSpacing)
end

function module:ToggleLocked(locked)
   if not module.frame then return end
   if locked then
      module.frame:RegisterForDrag()
      module.frame:EnableMouse(false)
   else
      module.frame:RegisterForDrag("LeftButton")
      module.frame:EnableMouse(true)
   end      
end


function module:NotStyleStraight()
   return module.db.style ~= module.STYLE_STRAIGHT
end

function module:NotStyleCircle()
   return module.db.style ~= module.STYLE_CIRCLE
end

function module:NotStyleCircleOrEllipse()
   return module.db.style ~= module.STYLE_CIRCLE and module.db.style ~= module.STYLE_ELLIPSE
end

function module:NotStyleCircleOrEllipseBasic()
   return module.db.advanced or module.db.style ~= module.STYLE_CIRCLE and module.db.style ~= module.STYLE_ELLIPSE 
end

function module:NotStyleCircleOrEllipseAdvanced()
   return not module.db.advanced or module.db.style ~= module.STYLE_CIRCLE and module.db.style ~= module.STYLE_ELLIPSE 
end

function module:NotStyleAdvanced()
   return module.db.advanced and module.db.style ~= module.STYLE_STRAIGHT
end

function module:NotStyleEllipse()
   return module.db.style ~= module.STYLE_ELLIPSE
end

-- setup the options
function module:SetupOptions()
   module.options.args.backgroundFrame = module:GetConfigTemplate("background")
   module.options.args.backgroundFrame.hidden = "IsDisabled"
   module.options.args.backgroundFrame.order = 30
   module.options.args.backgroundFrame.args.oocAlpha = {
      type = "range",
      name = L["Out of combat alpha"],
      desc = L["The alpha level of the frame background when out of combat and no runes are active."],
      width = "full",
      min = 0, max = 1, step = 0.01,
      order = 75,
   }, 
   mod:OptReg("Icon Display", module.options, L["Icon Display"], nil, true)
end

function module:OnOptionChanged(var, val)
   -- Do any actions required due to change in parameters
   if var == "oocAlpha"  then
      module:SetFrameColor()
   elseif var == "scale" then
      module.frame:SetScale(val)
   elseif var == "runeSet" then
      for id = 1,6 do
	 icons[id].icon:SetTexture(mod:GetRuneIcon(icons[id].type, module.db.runeSet))
      end
   elseif var == "enabled" then
      if val then module.frame:Show() else module.frame:Hide() end
   else
      module:AnchorIcons()
   end
end

function module:OnCombatChange(inCombat)
   playerInCombat = inCombat
   module:SetFrameColor()
end

function module:SetFrameColor()
   local mod = (playerInCombat or runesAreActive) and 1 or module.db.oocAlpha

   local bg = module.db.backdropColors.backgroundColor
   module.frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4]*mod)

   bg = module.db.backdropColors.borderColor
   module.frame:SetBackdropBorderColor(bg[1], bg[2], bg[3], bg[4]*mod)
end

function module:SetColorOpt(arg, r, g, b, a)
   local color = arg[#arg]
   module.db.backdropColors[color][1] = r
   module.db.backdropColors[color][2] = g
   module.db.backdropColors[color][3] = b
   module.db.backdropColors[color][4] = a
   module:FixBackdrop()
end

function module:GetColorOpt(arg)
   local color = arg[#arg]
   return unpack(module.db.backdropColors[color])
end

function module:IsDisabled() return not module.db.enabled end

function module:SetupDefaultOptions()
   module.db = mod.db.profile.icondisplay or {}
   for key, val in pairs(defaults) do
      if module.db[key] == nil then
	 module.db[key] = val
      end
   end
   mod.db.profile.icondisplay = module.db
end


-- Configuration stuff

module.options = {
   type = "group",
   name = L["Magic Runes"].." - "..L["Icon Display"],
   handler = module,
   get = "_GetOption",
   set = "_SetOption",
   childGroups = "tab",
   args = {
      enabled = {
	 type = "toggle",
	 name = L["Enable Icon Display"], 
	 order = 1,
      },
      style = {
	 type = "select",
	 name = L["Layout Style"],
	 values = {
	    [module.STYLE_STRAIGHT] = L["Normal"],
	    [module.STYLE_CIRCLE] = L["Circle"],
	    [module.STYLE_ELLIPSE] = L["Ellipse"],
	 },
	 order = 2, 
	 hidden = "IsDisabled",
      },
      layout = {
	 type = "group",
	 name = L["Layout"],
	 hidden = "IsDisabled",
	 order = 20,
	 args = {
	    vertSpacing = {
	       type = "range",
	       name = L["Vertical Spacing"],
	       width = "full",
	       min = -10, max = 60, step = 0.01,
	       order = 4,
	       hidden = "NotStyleStraight",
	    }, 
	    horizSpacing = {
	       type = "range",
	       name = L["Horizontal Spacing"],
	       width = "full",
	       min = -10, max = 60, step = 0.01,
	       order = 4,
	       hidden = "NotStyleStraight",
	    }, 
	    scale = {
	       type = "range",
	       name = L["Icon Scale"],
	       width = "full",
	       min = 0.01, max = 5, step = 0.01,
	       order = 5
	    },
	    radius = {
	       type = "range",
	       name = L["Radius"],
	       width="full",
	       desc = L["The radius of the circle."],
	       min = 0, max = 500, step = 1,
	       order = 2,
	       hidden = "NotStyleCircle",
	    },
	    majorRadius = {
	       type = "range",
	       name = L["Horizontal Radius"],
	       width="full",
	       desc = L["The radius of the major axis of the ellipse."],
	       min = 0, max = 500, step = 1,
	       order = 2,
	       hidden = "NotStyleEllipse",
	    },
	    minorRadius = {
	       type = "range",
	       name = L["Vertical Radius"],
	       width="full",
	       desc = L["The radius of the minor axis of the ellipse."],
	       min = 0, max = 500, step = 1,
	       order = 2,
	       hidden = "NotStyleEllipse",
	    },
	    spread = {
	       type = "range",
	       name = L["Icon Spread"],
	       width="full",
	       desc = L["The number of degrees to spread the icons over - 180 degrees is a half circle, 360 degrees is a full circle."],
	       min = 0, max = 360, step = 0.1,
	       order = 3,
	       hidden = "NotStyleCircleOrEllipseBasic",
	    },
	    startAngle = {
	       type = "range",
	       name = L["Start Angle"],
	       width="full",
	       desc = L["The angle to start putting the icons on."],
	       min = 0, max = 360, step = 0.1,
	       order = 3,
	       hidden = "NotStyleCircleOrEllipseBasic",
	    },
	    blood1Angle = {
	       type = "range",
	       name = L["Blood #1 Angle"],
	       width="full",
	       desc = L["The angle of Blood Rune #1."],
	       min = 0, max = 360, step = 0.1,
	       order = 6,
	       hidden = "NotStyleCircleOrEllipseAdvanced",
	    },
	    blood2Angle = {
	       type = "range",
	       name = L["Blood #2 Angle"],
	       width="full",
	       desc = L["The angle of Blood Rune #2."],
	       min = 0, max = 360, step = 0.1,
	       order = 6,
	       hidden = "NotStyleCircleOrEllipseAdvanced",
	    },
	    frost1Angle = {
	       type = "range",
	       name = L["Frost #1 Angle"],
	       width="full",
	       desc = L["The angle of Frost Rune #1."],
	       min = 0, max = 360, step = 0.1,
	       order = 7,
	       hidden = "NotStyleCircleOrEllipseAdvanced",
	    },
	    frost2Angle = {
	       type = "range",
	       name = L["Frost #2 Angle"],
	       width="full",
	       desc = L["The angle of Frost Rune #2."],
	       min = 0, max = 360, step = 0.1,
	       order = 7,
	       hidden = "NotStyleCircleOrEllipseAdvanced",
	    },
	    unholy1Angle = {
	       type = "range",
	       name = L["Unholy #1 Angle"],
	       width="full",
	       desc = L["The angle of Unholy Rune #1."],
	       min = 0, max = 360, step = 0.1,
	       order = 8,
	       hidden ="NotStyleCircleOrEllipseAdvanced",
	    },
	    unholy2Angle = {
	       type = "range",
	       name = L["Unholy #2 Angle"],
	       width="full",
	       desc = L["The angle of Unholy Rune #2."],
	       min = 0, max = 360, step = 0.1,
	       order = 8,
	       hidden = "NotStyleCircleOrEllipseAdvanced",
	    },
	    width = {
	       type = "range",
	       name = L["Width"],
	       width="full",
	       desc = L["Number of icons per row."],
	       min = 1, max = 6, step = 1,
	       order = 4,
	       hidden = "NotStyleStraight",
	    },
	    runeOrder = {
	       type = "select",
	       name = L["Rune Order"],
	       values = {
		  "BBUUFF",
		  "BUFBUF",
		  "BBFFUU",
		  "BBFUFU",
		  "FUFUBB",
		  "BFUUFB",
		  "BUFFUB", 
	       },
	       hidden = "NotStyleAdvanced",
	       order = 30
	    },
	    runeSet = {
	       type = "select",
	       name = L["Rune Icon Set"],
	       values = mod:GetRuneSetList(),
	       order = 35
	    },
	    flipx = {
	       type = "toggle",
	       name = L["Flip horizontal growth direction"],
	       width = "full",
	       desc = L["If toggled, the icons will expand to the left instead of to the right."],
	       order = 40, 
	       hidden = "NotStyleStraight",
	    },
	    flipy = {
	       type = "toggle",
	       width = "full",
	       name = L["Flip vertical growth direction"],
	       desc = L["If toggled, the icons will expand upwards instead of downwards."],
	       order = 40, 
	       hidden = "NotStyleStraight",
	    },
	    reverseOrder = {
	       type = "toggle",
	       width = "full",
	       name = L["Reverse icon placement order"],
	       desc = L["Reverses the direction of icon placement on the circle or ellipse"],
	       order = 40, 
	       hidden = "NotStyleCircleOrEllipseBasic",
	    },
	    advanced = {
	       type = "toggle",
	       width = "full",
	       name = L["Individual icon placement"],
	       desc = L["If checked you can specify the exact location of each rune on the circle or ellipse. If unchecked you specify the start angle, spread and order of the icons instead."],
	       order = 40, 
	       hidden = "NotStyleCircleOrEllipse",
	    },
	 }
      },
      help = {
	 type = "group",
	 name = L["Documentation"],
	 childGroups = "tree",
	 order = 40,
	 args = {
	    layout = {
	       type = "group",
	       name = L["Layout"],
	       order = 1,
	       args = {
		  header1 = {
		     type = "header",
		     name = L["Layout Options"],
		     order = 10
		  },
		  desc1 = {
		     type = "description",
		     name =
			L["The Icon Display has three different layout options: Normal, Circle and Ellipse. "]..
			L["Each option comes with its own set of parameters that controls the layout. "]..
			L["Some parameters are shared between layouts, while others are not. "],
		     order = 15
		  },
		  header15 = {
		     type = "header",
		     name = L["Shared Parameters"],
		     order = 18
		  },
		  desc15 = {
		     type = "description",
		     name =
			L["Regardless of layout, you can always pick the rune icon set to use and the icon scale."],
		     order = 19
		  },
		  header2 = {
		     type = "group",
		     name = L["Normal Layout"],
		     order = 20,
		     args = {
			header = {
			   type = "header",
			   name = L["Normal Layout"],
			   order = 20,
			},
			desc2 = {
			   type = "description",
			   name = L["The normal layout lets you put the icons in straight vertical or/or horizontal rows and colums. "]..
			      L["You control the growth direction with the horizontal and vertical growth direction toggles.\n\n"]..
			      L["Using the width parameter you can select how many icons to put in a row. A width of 1 means you'll have a single vertical column while a width of 6 means you'll have a single horizontal row.\n\n"]..
			      L["The space between columns is controlled by the horizontal spacing parameter. Use the vertical spacing parameter to control the space between rows.\n\n"]..
			      L["You can change the order of the runes using the rune order parameter.\n\n"],
			   order = 25,
			},
			desc2img = {
			   type = "description",
			   name = "",			   
			   order = 26,
			   image = "Interface\\AddOns\\MagicRunes\\Img\\normal_128x91.tga",
			   imageWidth = 128,
			   imageHeight = 91,
			},
		     },
		  },
		  header3 = {
		     type = "group",
		     name = L["Circle Layout"],
		     order = 30,
		     args = {
			header3 = {
			   type = "header",
			   name = L["Circle Layout"],
			   order = 30,
			},
			desc3 = {
			   type = "description",
			   name = L["The circle layout will place the icons around an invisible circle. This is done using a radius, starting angle and icon spread parameters.\n\n"]..
			      L["The spread decides how far apart the icons are while the start angle determines where the first icon should be placed. You can reverse the placement direction as well.\n\n"]..
			      L["As with the normal layout, you can specify the order of the runes using the rune order parameter.\n\n"]..
			      L["You can also choose to place icons individually. This allows you to specify the exact angle to use for each rune icon. When this option is used, the start angle, icon spread, placement direction and rune order parameters aren't used.\n\n"],
			   order = 35,
			},
			desc3img = {
			   type = "description",
			   name = "",
			   order = 36,
			   image = "Interface\\AddOns\\MagicRunes\\Img\\circle_136x124.tga",
			   imageWidth = 136,
			   imageHeight = 124,
			},
		     }
		  },
		  header4 = {
		     type = "group",
		     name = L["Ellipse Layout"],
		     order = 40,
		     args = {
			header4 = {
			   type = "header",
			   name = L["Ellipse Layout"],
			   order = 40,
			},
			desc4 = {
			   type = "description",
			   name = L["The ellipse is identical to circle layout except it allows you to specify both horizontal and vertical radius. These two parameters are used to determine the size and shape of the ellipse.\n\n"],
			   order = 45,
			},
			desc4img = {
			   type = "description",
			   name = "",
			   order = 46,
			   image = "Interface\\AddOns\\MagicRunes\\Img\\ellipse_235x122.tga",
			   imageWidth = 235,
			   imageHeight = 122,
			},
		     }
		  }
	       }
	    },
	    decorations = {
	       type = "group",
	       name = L["Decorations"],
	       order = 10,
	       args = {
		  header = {
		     type = "header",
		     name = L["Decorations"],
		     order = 1, 
		  },
		  desc = {
		     type = "description",
		     name = L["The icon display uses the addon global settings for decorations. The following decorations and effects works for icons: \n\n"]..
			L[" - Flash Mode, Alpha Flash (color flash doesn't work)\n"]..
			L[" - All alpha level parameters.\n\n"]..
			L["All the other decorations and effects don't make sense for icons and thus don't work."],
		     order = 10,
		  },
		  
		  CC = {
		     type = "group",
		     name = L["Cooldown Count"],
		     order = 20, 
		     args = {
			headerCC = {
			   type = "header",
			   name = L["Cooldown Count"],
			   order = 20, 
			},
			descCC = {
			   type = "description",
			   name = L["Currently there's no built-in option to display cooldown count text on the icons. You can however install an addon such as OmniCC to get this feature.\n\n"]..
			      L["In the future you'll be able to use either an external cooldown count addon or builtin text."], 
			   order = 30,
			},
		     }
		  },
		  masque = {
		     type = "group",
		     name = L["Masque"],
		     order = 30,
		     args = {
			header = {
			   type = "header",
			   name = L["Masque"],
			   order = 10,
			},
			desc = {
			   type = "description",
			   name =
  			     L["The icons are fully integrated with the Masque addon. This addon lets you skin the buttons for a more personalized display.\n\n"]..
			      L["To configure the looks, open the Masque configuration UI using the /masque command. Select Addons => Magic Runes => Rune Bars.\n\n"]..
			      L["You can find Masque and many different skins on http://wow.curse.com/"],
			   order = 20,
			},		  
		     }
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
			L["The background frames allows you to set an optional backdrop behind the icons. You can configure the border and background texture and color.\n\n"]..
			L["The width of the border is controlled by the edge size parameter. To add some extra padding between the border and icons you can set the padding.\n\n"]..
			L["To be able to change the border and background you need the SharedMedia and SharedMedia-Blizzard addons installed. You can find these at http://wow.curse.com/\n\n"],
		     order = 20,
		  },		  
	       }
	    },
	 }
      }
   }
}

