local orig_print = print
if Mods.mrudat_TestingMods then
  print = orig_print
else
  print = empty_func
end

local CurrentModId = rawget(_G, 'CurrentModId') or rawget(_G, 'CurrentModId_X')
local CurrentModDef = rawget(_G, 'CurrentModDef') or rawget(_G, 'CurrentModDef_X')
if not CurrentModId then

  -- copied shamelessly from Expanded Cheat Menu
  local Mods, rawset = Mods, rawset
  for id, mod in pairs(Mods) do
    rawset(mod.env, "CurrentModId_X", id)
    rawset(mod.env, "CurrentModDef_X", mod)
  end

  CurrentModId = CurrentModId_X
  CurrentModDef = CurrentModDef_X
end

orig_print("loading", CurrentModId, "-", CurrentModDef.title)

local stat_scale = const.Scale.Stat

GlobalVar("g_FoodVarietyComfortBonus_StarchComfortBonus", stat_scale/2)
GlobalVar("g_FoodVarietyComfortBonus_VegetableComfortBonus", stat_scale)
GlobalVar("g_FoodVarietyComfortBonus_MeatComfortBonus", stat_scale)
GlobalVar("g_FoodVarietyComfortBonus_SpiceComfortBonus", 2 * stat_scale)

GlobalVar("g_FoodVarietyComfortBonus_LastHarvest", {
  spice = {},
  starch = {},
  vegetable = {},
  meat = {},
})

-- where two different crops produce the same food.
GlobalVar("g_FoodVarietyComfortBonus_EquivalentFoods", {
  ['Giant Corn'] = 'Corn',
  ['Giant Leaf Crops'] = 'Leaf Crops',
  ['Giant Potatoes'] = 'Potatoes',
  ['Giant Rice'] = 'Rice',
  ['Giant Wheat Grass'] = 'Wheat Grass',
  ['Giant Wheat'] = 'Wheat',
  ['Mystery9_GanymedeRice'] = 'Rice', -- I think?

  -- Armstrong DLC
  ['Potato'] = 'Potatoes',
  ['Rapeseed'] = 'Cover Crops',
  ['Spinach'] = 'Leaf Crops',
})

-- bland starchy foods that make up bulk energy intake
GlobalVar("g_FoodVarietyComfortBonus_Starch", {
  ['Soybeans'] = true, -- only for certain sponsors?
  ['Corn'] = true, -- only for certain sponsors? eg. Maize was a staple in the US, but not the EU.
  ['Potatoes'] = true,
  ['Rice'] = true,
  ['Wheat'] = true
})

-- herbs/spices to make food tastier
GlobalVar("g_FoodVarietyComfortBonus_Spices", {
  ['Herbs'] = true,
  ['Cover Crops'] = true, -- Canola, vegatable oils, margarine
})

-- can be grown as herbs/spices to make bland food tastier
GlobalVar("g_FoodVarietyComfortBonus_PotentialSpices", {
  ['Microgreens'] = true, -- tasty varieties when not as primary energy source.
  ['Soybeans'] = true, -- Soy sauce, but only when not also primary starch source
})

-- Multiple varieties are grown at once
GlobalVar("g_FoodVarietyComfortBonus_ExtraVariety", {
  'Vegetables',
  'Microgreens',
  'Fruit Trees',
  'Leaf Crops',
})

local variety_bonus_lookup = {
  1000,
  2204,
  2908,
  3408,
  3796,
  4113,
  4380,
  4612,
  4817,
  5000
}
local variety_bonus_lookup_count = #variety_bonus_lookup

local function variety_bonus(count, base_bonus)
  print("variety_bonus", count, base_bonus)
  if count == 0 then return 0 end
  if count > variety_bonus_lookup_count then count = variety_bonus_lookup_count end
  print(variety_bonus_lookup[count])
  return MulDivRound(base_bonus, variety_bonus_lookup[count], 1000)
end

function OnMsg.NewDay(day)
  local LastHarvest = g_FoodVarietyComfortBonus_LastHarvest
  local EquivalentFoods = g_FoodVarietyComfortBonus_EquivalentFoods
  local Starch = g_FoodVarietyComfortBonus_Starch
  local PotentialSpices = g_FoodVarietyComfortBonus_PotentialSpices
  local Spices = g_FoodVarietyComfortBonus_Spices
  local ExtraVariety = g_FoodVarietyComfortBonus_ExtraVariety

  -- expire food that hasn't been harvested in the last 30 days, as anything left has been turned into MREs to keep for that long
  local expiry_date = day - 30
  local counts = {}
  for type, foods in pairs(LastHarvest) do
    for food_id, harvest_day in pairs(foods) do
      if harvest_day < expiry_date then
        print(type, food_id, "expired", harvest_day, expiry_date)
        foods[food_id] = nil
      else
        counts[type] = (counts[type] or 0) + 1
      end
    end
  end

  print(LastHarvest)
  print(counts)

  local meat = LastHarvest.meat
  local spice = LastHarvest.spice
  local starch = LastHarvest.starch
  local vegetable = LastHarvest.vegetable

  local meat_count = counts.meat or 0
  local spice_count = counts.spice or 0
  local starch_count = counts.starch or 0
  local vegetable_count = counts.vegetable or 0

  -- add PotentialSpices to the list of spices for the next harvest if we're growing starchy foods.
  if starch_count then
    for _, spice in ipairs(PotentialSpices) do
      if not starch[spice] or starch_count > 2 then
        Spices[spice] = true
      end
    end
  else
    for _, spice in ipairs(PotentialSpices) do
      Spices[spice] = nil
    end
  end

  -- these foods are grown in multiple varieties
  for _,food_id in ipairs(ExtraVariety) do
    if vegetable[food_id] then
      vegetable_count = vegetable_count + 1
    end
  end

  print(starch_count, vegetable_count, spice_count, meat_count)

  local vegan_comfort_bonus = variety_bonus(starch_count, g_FoodVarietyComfortBonus_StarchComfortBonus) + variety_bonus(vegetable_count, g_FoodVarietyComfortBonus_VegetableComfortBonus) + variety_bonus(spice_count, g_FoodVarietyComfortBonus_SpiceComfortBonus)

  local comfort_bonus = vegan_comfort_bonus + variety_bonus(meat_count, g_FoodVarietyComfortBonus_MeatComfortBonus)

  if meat['Pig'] then
    -- because Bacon
    comfort_bonus = comfort_bonus + g_FoodVarietyComfortBonus_MeatComfortBonus
  end

  print("Food Variety Comfort Bonus", comfort_bonus/1000.0, "(non-vegan)", vegan_comfort_bonus/1000.0, "(vegan)")

  local modifier = false
  local modifier_id = "FoodVarietyComfortBonus"
  local amount = MulDivRound(comfort_bonus,1,100)

  if comfort_bonus > 0 then
    -- TODO comfort for vegans vs meat eaters?
    modifier = Modifier:new{
      prop = "performance",
      amount = amount,
      percent = 0,
      id = modifier_id,
      display_text = T{"<green>Food variety +<amount></green>", amount = amount}
    }
  end

  UICity:SetLabelModifier("needFood", modifier_id, modifier)
  UICity:SetLabelModifier("interestDining", modifier_id, modifier)
end

function OnMsg.FoodVarietyComfortBonus_VegetableFoodProduced(plant_id)
  print("Produced vegetable:", plant_id)
  plant_id = g_FoodVarietyComfortBonus_EquivalentFoods[plant_id] or plant_id
  print("Produced vegetable:", plant_id)
  local LastHarvest = g_FoodVarietyComfortBonus_LastHarvest
  if g_FoodVarietyComfortBonus_Spices[plant_id] then
    LastHarvest.spice[plant_id] = UICity.day
  elseif g_FoodVarietyComfortBonus_Starch[plant_id] then
    LastHarvest.starch[plant_id] = UICity.day
  else
    LastHarvest.vegetable[plant_id] = UICity.day
  end
end

function OnMsg.FoodVarietyComfortBonus_AnimalFoodProduced(animal_id)
  print("Produced animal:", animal_id)
  g_FoodVarietyComfortBonus_LastHarvest.meat[animal_id] = UICity.day
end

function OnMsg.ClassesPostprocess()
  print("Msg.ClassesPostprocess")
  for _, food in pairs(CropPresets) do
    local food_id = food.id
    local resource_type = food.ResourceType
    if resource_type and resource_type ~= 'Food' then goto not_food end
    local orig_OnProduce = food.OnProduce or empty_func
    food.OnProduce = function(...)
      print(food_id, ".OnProduce(...)")
      orig_OnProduce(...)
      Msg("FoodVarietyComfortBonus_VegetableFoodProduced", food_id)
    end
    ::not_food::
  end

  if VegetationTaskRequester and VegetationTaskRequester.DroneLoadResource then
    local orig_VegetationTaskRequester_DroneLoadResource = VegetationTaskRequester.DroneLoadResource
    function VegetationTaskRequester:DroneLoadResource(drone, request, resource, amount, skip_presentation)
      orig_VegetationTaskRequester_DroneLoadResource(self, drone, request, resource, amount, skip_presentation)
      local preset = self.preset
      if preset.group == "Vegetable" and resource == 'Food' then
        print(preset)
        Msg("FoodVarietyComfortBonus_VegetableFoodProduced", preset.id)
      end
    end
  end

  if Pasture and Pasture.ProduceFood then
    local orig_Pasture_ProduceFood = Pasture.ProduceFood
    function Pasture:ProduceFood(animal)
      orig_Pasture_ProduceFood(animal)
      Msg("FoodVarietyComfortBonus_AnimalFoodProduced", animal.id)
    end
  end
end

orig_print("loaded", CurrentModId, "-", CurrentModDef.title)
