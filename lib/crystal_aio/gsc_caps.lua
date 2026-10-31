-- Gym badges are the save's authority; League/Red wins have no badge.
local M = {}
local johto = {
  FALKNER={"ZEPHYR",1}, BUGSY={"HIVE",2}, WHITNEY={"PLAIN",3}, MORTY={"FOG",4},
  JASMINE={"MINERAL",5}, CHUCK={"STORM",6}, PRYCE={"GLACIER",7}, CLAIR={"RISING",8},
}
local kanto = {
  BROCK={"BOULDER",1}, MISTY={"CASCADE",2}, ["LT SURGE"]={"THUNDER",3},
  ERIKA={"RAINBOW",4}, JANINE={"SOUL",5}, SABRINA={"MARSH",6},
  BLAINE={"VOLCANO",7}, BLUE={"EARTH",8},
}
local function owns(store, badge)
  local v = store[badge[1]]
  if v == nil then v = store[badge[2]] end
  return v == true or (type(v) == "number" and v > 0)
end
function M.completed(save, recorded)
  local done = {}
  for k,v in pairs(recorded or {}) do done[k] = v end
  local player = save and save.player or {}
  for _,group in ipairs({{johto,player.badges}, {kanto,player.kantoBadges}}) do
    if type(group[2]) == "table" then
      for leader,badge in pairs(group[1]) do done[leader] = owns(group[2],badge) end
    end
  end
  local hof=save and save.hallOfFame
  if type(hof)=="table" and ((tonumber(hof.count) or 0)>0 or hof.entered==true) then
    for _,name in ipairs({"WILL","KOGA","BRUNO","KAREN","LANCE"}) do done[name]=true end
  end
  return done
end
function M.next(stages, save, recorded, scope)
  local done = M.completed(save,recorded)
  local floor = 0
  -- Optional gyms must never lower a cap after a stronger gym was cleared.
  for _,stage in ipairs(stages) do
    if stage.phase == "GYM" and done[stage.name] then floor = math.max(floor,stage.cap) end
  end
  for _,stage in ipairs(stages) do
    local allowed = stage.phase == "GYM" or (stage.phase == "E4" and scope >= 2)
      or (stage.phase == "CHAMP" and scope >= 3) or (stage.phase == "POST" and scope >= 4)
    if not done[stage.name] then
      if allowed then return math.max(floor,stage.cap),stage.name end
      return 100,"MAX"
    end
  end
end
return M
