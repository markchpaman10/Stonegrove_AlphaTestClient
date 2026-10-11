local V={}
V.keys={'bankChest','shopkeeper','mercRecruiter','bankClerk','smelter','anvil','tanningVat','hideStretcher','spinningWheel','loom','metalLoom','alchemy','stove','magicAltar','religionAltar','socketTable','enchantAltar','inscription','tailoring'}
function V.activate(world,v)
 if not v then return false end
 world.activeVillage=v
 for _,key in ipairs(V.keys) do if v[key] then world[key]=v[key] end end
 return true
end
function V.nearestData(world,x,y)
 local best,dist
 for _,v in ipairs(world.villages or {}) do local d=(x-v.cx)^2+(y-v.cy)^2;if not dist or d<dist then best,dist=v,d end end
 return best
end
function V.nearest(world,x,y)
 if world.isCave then return end
 if world.authoredObjects then return require("game.authored_world").nearest(world,x,y) end
 local best,dist
 for _,v in ipairs(world.villages or {}) do local d=(x-v.cx)^2+(y-v.cy)^2;if not dist or d<dist then best,dist=v,d end end
 if best then V.activate(world,best) end
 return best
end
function V.build(world)
 local sites=require('game.zones').villageSites(world.map)
 local firstSite=sites[1];local cx,cy=firstSite.x,firstSite.y
 local first={name=firstSite.name,cx=cx,cy=cy,zone=1}
 for _,key in ipairs(V.keys) do first[key]=world[key] end
 world.villages={first}
 local baseHouses={};for _,h in ipairs(world.houses) do baseHouses[#baseHouses+1]=h end
 local basePaths={};for _,p in ipairs(world.paths) do basePaths[#basePaths+1]=p end
 for i=2,#sites do
  local site=sites[i];local dx,dy=site.x-cx,site.y-cy;local v={name=site.name,cx=site.x,cy=site.y,zone=site.zone}
  for _,key in ipairs(V.keys) do local src=first[key];local dest={x=src.x+dx,y=src.y+dy}
   if key=='tanningVat' then dest.jobs={} elseif key=='hideStretcher' then dest.state='empty';dest.timer=0 end
   v[key]=dest
  end
  for _,h in ipairs(baseHouses) do world.houses[#world.houses+1]={x=h.x+dx,y=h.y+dy,station=h.station} end
  for _,p in ipairs(basePaths) do world.paths[#world.paths+1]={x=p.x+dx,y=p.y+dy,w=p.w,h=p.h} end
  world.villages[#world.villages+1]=v
 end
 require('game.houses').generate(world.houses,world.houseSeed)
 V.activate(world,first)
end

return V
