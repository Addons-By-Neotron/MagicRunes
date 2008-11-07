

local mod = MagicRunes
mod.presets = {
   ["TinyBars"] = {
      ["data"] = {
	 ["thickness"] = 5.08,
	 ["animateIcons"] = false,
	 ["showIcon"] = false,
	 ["spacing"] = 0.7100000000000009,
	 ["orientation"] = 1,
	 ["length"] = 113.14,
	 ["showRemaining"] = false,
	 ["iconScale"] = 1,
	 ["showTimer"] = false,
	 ["showLabel"] = false,
      },
      ["name"] = "Tiny horizontal bars",
   },
   ["IconBar"] = {
      ["data"] = {
	 ["thickness"] = 3.61,
	 ["animateIcons"] = true,
	 ["showIcon"] = true,
	 ["spacing"] = 11.22,
	 ["orientation"] = 1,
	 ["length"] = 156.89,
	 ["showRemaining"] = true,
	 ["iconScale"] = 6.33,
	 ["showTimer"] = false,
	 ["showLabel"] = false,
      },
      ["name"] = "Horizontal animated icons",
   },
   ["VertLabelBars"] = {
      ["data"] = {
	 ["thickness"] = 17.25,
	 ["animateIcons"] = false,
	 ["showIcon"] = false,
	 ["spacing"] = 0,
	 ["orientation"] = 2,
	 ["length"] = 113.14,
	 ["showRemaining"] = true,
	 ["showTimer"] = true,
	 ["showLabel"] = true,
	 ["iconScale"] = 4.1,
      },
      ["name"] = "Vertical labeled bars",
   },
   ["TinyVertBars"] = {
      ["data"] = {
	 ["thickness"] = 5.08,
	 ["animateIcons"] = false,
	 ["showIcon"] = false,
	 ["spacing"] = 0.7100000000000009,
	 ["orientation"] = 2,
	 ["length"] = 113.14,
	 ["showRemaining"] = true,
	 ["iconScale"] = 1,
	 ["showTimer"] = false,
	 ["showLabel"] = false,
      },
      ["name"] = "Tiny vertical bars",
   },
   ["StaticLabeledBars"] = {
      ["data"] = {
	 ["thickness"] = 16.85,
	 ["animateIcons"] = false,
	 ["showIcon"] = true,
	 ["spacing"] = 0,
	 ["orientation"] = 1,
	 ["length"] = 180.64,
	 ["showRemaining"] = false,
	 ["iconScale"] = 1,
	 ["showTimer"] = true,
	 ["showLabel"] = true,
      },
      ["name"] = "Horizontal labeled bars",
   },
   ["VertIconBars"] = {
      ["data"] = {
	 ["thickness"] = 5.08,
	 ["animateIcons"] = true,
	 ["showIcon"] = true,
	 ["spacing"] = 7.079999999999998,
	 ["orientation"] = 2,
	 ["length"] = 113.14,
	 ["showRemaining"] = true,
	 ["iconScale"] = 4.1,
	 ["showTimer"] = false,
	 ["showLabel"] = false,
      },
      ["name"] = "Vertical animated icons",
   },
}

local presetValues = {}
for name,data in pairs(MagicRunes.presets) do
   presetValues[name] = data.name
end

function MagicRunes:GetPresetList() return presetValues end
   
