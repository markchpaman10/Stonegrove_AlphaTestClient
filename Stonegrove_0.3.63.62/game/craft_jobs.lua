-- Timed crafting jobs. A recipe click now means "make all": craft one cycle at a
-- time until the selected recipe can no longer be made, the station closes, the
-- player moves, stamina runs out, or output space prevents another craft.
local M={}
function M.install(UI)
 local function makeCraftJob(self,station,index)
  local r=self.crafting:getRecipes(station)[index]
  if not r then return nil end
  return {station=station,index=index,name=r.name,timer=0,duration=(r.duration or .5)*math.max(1,r.qty or 1),x=self.player.x,y=self.player.y,batch=true}
 end

 function UI:startCraft(station,index)
  if self.craftJob or self.magicCast or self.world.workJob then return false,"busy" end
  local r=self.crafting:getRecipes(station)[index];if not r then return false end
  local ok,why=self.crafting:canCraft(r,self.inv,self.equipment.weapon,self.skills,self.world,self.player)
  if not ok then self.world:addPopup(self.player.x,self.player.y-26,why);return false,why end
  self.craftJob=makeCraftJob(self,station,index)
  self:log("CRAFT_BATCH_STARTED",{station=station,recipe=r.name})
  return true
 end

 local update=UI.updateMagic
 function UI:updateMagic(dt)
  update(self,dt)
  self.player:syncVitals(self.skills)
  local j=self.craftJob
  if j then
   if (j.validate and not j.validate()) or (self.player.x-j.x)^2+(self.player.y-j.y)^2>4 or (j.station and not self.open[j.station]) then
    self.craftJob=nil;self.craftLimit=nil
   else
    j.timer=j.timer+dt
    if j.timer>=j.duration then
     self.craftJob=nil
     if j.finish then
      j.finish()
     else
      local r=self.crafting:getRecipes(j.station)[j.index]
      local can,why=self.crafting:canCraft(r,self.inv,self.equipment.weapon,self.skills,self.world,self.player)
      if can and self.player:spendStamina(2,self.skills,self.logger,"crafting") then
       local ok,item=self.crafting:craft(j.station,j.index,self.inv,self.skills,self.logger,self.equipment.weapon,self.world,self.player)
       if ok then
        self.world:craftJuice(j.station,self.player,item);self:craftBatchDone(j.station,j.index)
        -- Re-check after every completed item. This keeps XP, burn rolls,
        -- ingredient use, output generation and timing per craft rather than
        -- converting an entire stack in a single frame.
        local again=self.crafting:canCraft(r,self.inv,self.equipment.weapon,self.skills,self.world,self.player)
        if again and self.open[j.station]and(not self.craftLimit or self.craftLimit.remaining>0)then self.craftJob=makeCraftJob(self,j.station,j.index)
        else self:log("CRAFT_BATCH_FINISHED",{station=j.station,recipe=r.name}) end
       else
        self.world:addPopup(self.player.x,self.player.y-26,tostring(item))
       end
      else
       self.world:addPopup(self.player.x,self.player.y-26,tostring(why or "Need stamina"))
      end
     end
    end
   end
  end
  self.xpNoticeTimer=(self.xpNoticeTimer or 0)-dt
  if self.xpNoticeTimer<=0 then
   for name,amount in pairs(self.skills.pendingGains or {}) do
    local found
    for _,notice in ipairs(self.world.notifications) do if notice.skill==name then found=notice;break end end
    if found then found.amount=found.amount+amount;found.text=string.format("+%.1f %s XP",found.amount,name)
    else self.world.notifications[#self.world.notifications+1]={text=string.format("+%.1f %s XP",amount,name),t=3,skill=name,amount=amount} end
   end
   self.skills.pendingGains={};self.xpNoticeTimer=1
  end
 end

 local draw=UI.draw
 function UI:draw(w,h)
  draw(self,w,h)
  local j=self.craftJob or self.world.workJob
  if not j then local vat=self.world.tanningVat;local hs=self.world.hideStretcher
   if vat and vat.jobs[1] and (vat.x-self.player.x)^2+(vat.y-self.player.y)^2<60^2 then local job=vat.jobs[1];job.duration=job.duration or job.timer;j={name="Soaking hide",timer=job.duration-job.timer,duration=job.duration}
   elseif hs and hs.state=="stretching" and (hs.x-self.player.x)^2+(hs.y-self.player.y)^2<60^2 then hs.duration=math.max(hs.duration or 0,hs.timer);j={name="Drying "..(hs.input or "hide"),timer=hs.duration-hs.timer,duration=hs.duration} end
  end
  if j then
   local x,y=w/2-160,h-150
   love.graphics.setColor(.04,.04,.03,.96);love.graphics.rectangle("fill",x,y,320,38,4,4)
   love.graphics.setColor(.7,.55,.25);love.graphics.rectangle("fill",x+4,y+25,312*math.min(1,j.timer/j.duration),9)
   love.graphics.setColor(1,1,1);love.graphics.printf(j.name.." - "..string.format("%.1fs",math.max(0,j.duration-j.timer)),x+5,y+5,310,"center")
  end
 end
end
return M
