local mod = RegisterMod('D12 Rerolls Dice Rooms', 1)
local json = require('json')
local game = Game()

mod.rngShiftIdx = 35

mod.state = {}
mod.state.diceFaces = { 0, 0, 0, 0, 0, 0 } -- pips

function mod:onGameStart()
  if mod:HasData() then
    local _, state = pcall(json.decode, mod:LoadData())
    
    if type(state) == 'table' then
      if type(state.diceFaces) == 'table' then
        for i = 1, 6 do
          if math.type(state.diceFaces[i]) == 'integer' then
            mod.state.diceFaces[i] = state.diceFaces[i]
          end
        end
      end
    end
  end
end

function mod:onGameExit()
  mod:save()
end

function mod:save()
  mod:SaveData(json.encode(mod.state))
end

function mod:onNewRoom()
  local level = game:GetLevel()
  local room = level:GetCurrentRoom()
  local roomDesc = level:GetCurrentRoomDesc()
  
  if room:GetType() == RoomType.ROOM_DICE and room:IsFirstVisit() and roomDesc.Flags & RoomDescriptor.FLAG_SACRIFICE_DONE ~= RoomDescriptor.FLAG_SACRIFICE_DONE then
    local diceFloors = Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.DICE_FLOOR, -1, false, false)
    
    if #diceFloors == 1 then
      local rng = RNG()
      rng:SetSeed(room:GetSpawnSeed(), mod.rngShiftIdx)
      mod:setDiceFloor(diceFloors[1], rng, false)
    end
  end
end

-- filtered to COLLECTIBLE_D12
function mod:onUseItem(collectible, rng, player, useFlags, slot, varData)
  if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
    return
  end
  
  local level = game:GetLevel()
  local room = level:GetCurrentRoom()
  local roomDesc = level:GetCurrentRoomDesc()
  
  if room:GetType() == RoomType.ROOM_DICE and roomDesc.Flags & RoomDescriptor.FLAG_SACRIFICE_DONE ~= RoomDescriptor.FLAG_SACRIFICE_DONE then
    local diceFloors = Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.DICE_FLOOR, -1, false, false)
    
    if #diceFloors == 1 then
      mod:setDiceFloor(diceFloors[1], rng, true)
    end
  end
end

function mod:setDiceFloor(diceFloor, rng, reroll)
  if diceFloor.SubType >= 0 and diceFloor.SubType <= 5 then
    local diceFace = mod:getRandomDiceFace(rng, reroll and diceFloor.SubType + 1) -- don't reroll to the same number
    
    if diceFace then
      diceFloor.SubType = diceFace - 1
      diceFloor:GetSprite():Play(tostring(diceFace), true)
      
      if reroll then
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, diceFloor.Position, Vector.Zero, nil)
      end
    end
  end
end

function mod:getRandomDiceFace(rng, ignore)
  local weightedDiceFaces = {}
  local totalWeight = 0
  local totalWeightWoIgnore = 0
  
  for i, v in ipairs(mod.state.diceFaces) do
    if i ~= ignore then
      table.insert(weightedDiceFaces, { name = i, weight = v })
      totalWeight = totalWeight + v
    end
    totalWeightWoIgnore = totalWeightWoIgnore + v
  end
  
  if totalWeight > 0 then
    local rand = rng:RandomInt(totalWeight) + 1
    for _, v in ipairs(weightedDiceFaces) do
      rand = rand - v.weight
      if rand <= 0 then
        return v.name
      end
    end
  elseif totalWeightWoIgnore == 0 and ignore then
    local diceFaces = { 1, 2, 3, 4, 5, 6 }
    table.remove(diceFaces, ignore)
    return diceFaces[rng:RandomInt(#diceFaces) + 1]
  end
  
  return nil
end

function mod:setupEid()
  EID:addDescriptionModifier(mod.Name, function(descObj)
    return descObj.ObjType == EntityType.ENTITY_PICKUP and descObj.ObjVariant == PickupVariant.PICKUP_COLLECTIBLE and descObj.ObjSubType == CollectibleType.COLLECTIBLE_D12
  end, function(descObj)
    EID:appendToDescription(descObj, '#{{DiceRoom}} Rerolls the dice floor in dice rooms')
    return descObj
  end)
end

-- start ModConfigMenu --
function mod:setupModConfigMenu()
  local category = 'D12 Dice Rooms'
  for _, v in ipairs({ 'Settings' }) do
    ModConfigMenu.RemoveSubcategory(category, v)
  end
  ModConfigMenu.AddSetting(
    category,
    'Settings',
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return false
      end,
      Display = function()
        return 'Reset'
      end,
      OnChange = function(b)
        for i = 1, 6 do
          mod.state.diceFaces[i] = 0
        end
        mod:save()
      end,
      Info = { 'Reset the values below to their defaults' }
    }
  )
  ModConfigMenu.AddSetting(
    category,
    'Settings',
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return false
      end,
      Display = function()
        return 'Randomize'
      end,
      OnChange = function(b)
        local rand = Random()
        local rng = RNG()
        rng:SetSeed(rand <= 0 and 1 or rand, mod.rngShiftIdx)
        for i = 1, 6 do
          mod.state.diceFaces[i] = rng:RandomInt(11)
        end
        mod:save()
      end,
      Info = { 'Randomize the values below' }
    }
  )
  ModConfigMenu.AddSpace(category, 'Settings')
  for i = 1, 6 do
    ModConfigMenu.AddSetting(
      category,
      'Settings',
      {
        Type = ModConfigMenu.OptionType.SCROLL,
        CurrentSetting = function()
          return mod.state.diceFaces[i]
        end,
        Display = function()
          return i .. ' : $scroll' .. mod.state.diceFaces[i]
        end,
        OnChange = function(n)
          mod.state.diceFaces[i] = n
          mod:save()
        end,
        Info = { 'Choose relative weights', 'for random dice faces' }
      }
    )
  end
end
-- end ModConfigMenu --

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.onUseItem, CollectibleType.COLLECTIBLE_D12)

if EID then
  mod:setupEid()
end
if ModConfigMenu then
  mod:setupModConfigMenu()
end