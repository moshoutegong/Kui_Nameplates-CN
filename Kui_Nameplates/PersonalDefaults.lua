-- Personal defaults exported from the saved Ryouok configuration, 2026-10-07.
-- No character/account mappings are included. Each profile remains independent.
local profile = {
  ["fonts"] = {
    ["options"] = {
      ["fontscale"] = 1.252040863037109,
    },
  },
  ["general"] = {
    ["bartexture"] = "Flat",
    ["hheight"] = 14,
    ["highlight_target"] = true,
    ["raidicon_side"] = 1,
  },
  ["healthanchorpoint"] = "BOTTOMLEFT",
  ["healthoffsetx"] = 1,
  ["healthoffsety"] = 9,
  ["hp"] = {
    ["text"] = {
      ["hp_friend_low"] = 1,
      ["hp_friend_max"] = 1,
      ["hp_hostile_low"] = 1,
      ["hp_hostile_max"] = 1,
    },
  },
  ["levelanchorpoint"] = "RIGHT",
  ["leveloffsetx"] = 20,
  ["leveloffsety"] = 0.5,
  ["nameanchorpoint"] = "TOP",
  ["nameoffsety"] = 2,
  ["text"] = {
    ["healthanchorpoint"] = "BOTTOMLEFT",
    ["healthoffsetx"] = 1,
    ["healthoffsety"] = 9,
    ["level"] = true,
    ["levelanchorpoint"] = "RIGHT",
    ["leveloffsetx"] = 20,
    ["leveloffsety"] = 0.5,
    ["nameoffsety"] = 2,
  },
}
local namespaces = {
  ["Auras"] = {
    ["behav"] = {
      ["useWhitelist"] = false,
    },
    ["display"] = {
      ["pulsate"] = false,
    },
    ["icons"] = {
      ["position"] = "below",
    },
    ["showtrivial"] = true,
  },
  ["Castbar"] = {
    ["display"] = {
      ["cbheight"] = 8,
    },
  },
  ["QuestObjectives"] = {
    ["offset_y"] = 9,
    ["scale"] = 0.55,
  },
}
local function MergeKnown(destination, source)
    for key, value in pairs(source) do
        if destination[key] ~= nil then
            if type(value)=="table" and type(destination[key])=="table" then
                MergeKnown(destination[key], value)
            elseif type(value)==type(destination[key]) then
                destination[key]=value
            end
        end
    end
end
function KuiNameplatesPersonalDefaults_Apply(defaults)
    MergeKnown(defaults.profile, profile)
end
function KuiNameplatesPersonalDefaults_ApplyNamespace(name, defaults)
    if defaults and defaults.profile and namespaces[name] then
        MergeKnown(defaults.profile, namespaces[name])
    end
end
