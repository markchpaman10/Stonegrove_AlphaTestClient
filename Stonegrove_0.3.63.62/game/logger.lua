local Logger = {}
Logger.__index = Logger
Logger.VERSION="Stonegrove 0.3.63.62 ONLINE/OFFLINE"

local QUIET_EVENTS = {
  KEY_PRESSED=true, KEY_RELEASED=true, TEXT_INPUT=true,
  MOUSE_PRESSED=true, MOUSE_RELEASED=true, MOUSE_WHEEL=true,
  MOVEMENT_STATE=true, PLAYER_MOVED=true,
  RESOURCE_HIT=true, ENEMY_ROAM=true
}
local function safe(v)
  if v == nil then return "nil" end
  return tostring(v):gsub("\r", "\\r"):gsub("\n", "\\n")
end
function Logger.new(fileName)
  local self=setmetatable({},Logger);self.fileName=fileName or "gameplay_log.txt";self.path=love.filesystem.getSaveDirectory().."/"..self.fileName;self.enabled=true
  self:log("SESSION_START",{version=Logger.VERSION,game="Stonegrove",saveDirectory=love.filesystem.getSaveDirectory()})
  return self
end
function Logger:log(eventName,data)
  -- Route cues before logging filters: disabling disk logging never mutes gameplay.
  require("game.audio").event(eventName,data)
  if not eventName:match("^EVENT_") then require("game.events").notify("signal",eventName,data) end
  if not self.enabled or QUIET_EVENTS[eventName] then return false end
  local stamp=os.date("%Y-%m-%d %H:%M:%S");local parts={"["..stamp.."]",eventName}
  if data then local keys={};for k in pairs(data) do keys[#keys+1]=k end;table.sort(keys);for _,k in ipairs(keys) do parts[#parts+1]=safe(k).."="..safe(data[k]) end end
  local ok=love.filesystem.append(self.fileName,table.concat(parts," | ").."\n");return ok and true or false
end
function Logger:close(reason) if self.enabled then self:log("SESSION_END",{reason=reason or "quit"});self.enabled=false end end
return Logger
