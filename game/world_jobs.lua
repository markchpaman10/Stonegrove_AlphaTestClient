local J={}
function J.install(World)
 for name,duration in pairs({skinAnimal=1.2,shearSheep=1.5}) do
  local original=World[name]
  World[name]=function(self,target,player,...)
   if self.workJob then return false,'busy' end
   local args={...};if name=='shearSheep' then local ok,why=self:canShearSheep(target,player,args[1],args[2]);if not ok then return false,why end end;self.workJob={name=name=='skinAnimal' and 'Skinning' or 'Shearing',timer=0,duration=duration,x=player.x,y=player.y,finish=function() return original(self,target,player,unpack(args)) end}
   return true,'started'
  end
 end
 local update=World.update
 function World:update(dt,player,...)
  local j=self.workJob
  if j then
   if (player.x-j.x)^2+(player.y-j.y)^2>4 then self.workJob=nil
   else j.timer=j.timer+dt;if j.timer>=j.duration then self.workJob=nil;local ok,why=j.finish();if not ok then self:addPopup(player.x,player.y-24,tostring(why),'miss') end end end
  end
  return update(self,dt,player,...)
 end
end
return J
