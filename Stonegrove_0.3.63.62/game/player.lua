local Player={}; Player.__index=Player
local function directionFor(dx,dy,current)
 if math.abs(dx)>math.abs(dy) then return dx>=0 and "right" or "left"
 elseif math.abs(dy)>0.01 then return dy>=0 and "down" or "up" end
 return current
end
function Player.new()
 return setmetatable({name="Adventurer",race="Human",x=1024,y=823,speed=78,headDir="down",bodyDir="down",bodyTurnTime=0,hp=5,maxHp=5,attackCooldown=0,equipped=nil,moving=false,animTime=0,frame=1,activity=nil,activityTimer=0,toolSwing=0,poisonedTimer=0,poisonTick=0,poisonImmuneTimer=0,stamina=30,maxStamina=30,sprinting=false},Player)
end
function Player:syncVitals(skills)
 self.maxHp=require("game.races").maxHealth(self.race,skills:get("Health").level);if require("game.bonfire_buff").active(self)then self.maxHp=math.max(self.maxHp+1,math.floor(self.maxHp*1.2+.5))end
 -- Retain the playable starter pool; each Agility level adds five points.
 self.maxStamina=require("game.races").maxStamina(self.race,skills:get("Agility").level)
 local function clamp(v,maximum) v=tonumber(v);if not v or v~=v then v=maximum end;return math.max(0,math.min(maximum,v)) end
 self.hp=clamp(self.hp,self.maxHp);self.stamina=clamp(self.stamina,self.maxStamina)
end
function Player:staminaWarning(world,logger,source)
 local t=love.timer.getTime()
 if t<(self.nextStaminaWarning or 0)then return false end
 self.nextStaminaWarning=t+5
 world:addPopup(self.x,self.y-24,'LOW STAMINA — recovering','miss')
 if logger then logger:log('COMBAT_ATTACK_BLOCKED',{reason='no_stamina',source=source})end
 return true
end
function Player:spendStamina(amount,skills,logger,source)
 amount=math.max(0,amount or 0);if self.stamina<amount then return false end
 self.stamina=math.max(0,self.stamina-amount)
 if skills and amount>0 then local old,new,total=skills:addXP("Agility",amount*.5);if logger and new>old then logger:log("SKILL_LEVEL_UP",{skill="Agility",from=old,to=new,totalXp=total}) end end
 return true
end
function Player:update(dt,dx,dy,wx,wy)
 local len=math.sqrt(dx*dx+dy*dy);self.moving=len>0
 if len>0 then dx,dy=dx/len,dy/len;local moveSpeed=self.speed*(self.sprinting and 1.65 or 1)*((self.slimeCoated or 0)>0 and .5 or 1);self.x=self.x+dx*moveSpeed*dt;self.y=self.y+dy*moveSpeed*dt;self.animTime=self.animTime+dt;self.frame=(math.floor(self.animTime/.14)%4)+1 else self.frame=1 end
 local ax,ay=wx-self.x,wy-self.y
 self.headDir=directionFor(ax,ay,self.headDir)
 if self.bodyDir==self.headDir then self.bodyTurnTime=0 else self.bodyTurnTime=self.bodyTurnTime+dt;if self.bodyTurnTime>=.10 then self.bodyDir=self.headDir;self.bodyTurnTime=0 end end
 self.attackCooldown=math.max(0,self.attackCooldown-dt);self.poisonImmuneTimer=math.max(0,(self.poisonImmuneTimer or 0)-dt)
 self.activityTimer=math.max(0,self.activityTimer-dt);self.toolSwing=math.max(0,self.toolSwing-dt)
 if self.activityTimer<=0 then self.activity=nil end
end
function Player:setActivity(name,duration) self.activity=name;self.activityTimer=duration or .6;self.toolSwing=duration or .6 end
function Player:pulseTool(duration) self.toolSwing=duration or .22 end
function Player:attack(wx,wy)
 if self.attackCooldown>0 then return nil end;self.attackCooldown=.38
 local dx,dy=wx-self.x,wy-self.y;local d=math.sqrt(dx*dx+dy*dy);if d==0 then return nil end;require("game.audio").play("swing",self.x,self.y)
 return {x=self.x,y=self.y,tx=self.x+dx/d*24,ty=self.y+dy/d*24,time=.12}
end
return Player
