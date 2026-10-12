local Z={}
Z.defs={
 [1]={name='Greenfields',minLevel=1,maxLevel=10},
}
function Z.at(map,x,y)local z,i=require('game.level_zones').at(map,x,y);return i and i+1 or 1 end
function Z.info(map,x,y)local z,i=require('game.level_zones').at(map,x,y);local lo,hi=require('game.level_zones').range(map);return {name=z and(z.name or('Level Zone '..i))or'Map wilderness',minLevel=lo,maxLevel=hi,targetLevel=z and require('game.level_zones').target(map,z)or nil}end
function Z.level(map,x,y,rng)
 rng=rng or math.random
 local lv,i=require('game.level_zones').level(map,x,y,rng);return lv,i and i+1 or 1
end
function Z.villageSites(map)
 return {
  {name='Stonegrove',zone=1,x=map.width*.52,y=map.height*.50},
 }
end
function Z.resourceKind(zone,roll)
 if roll<.72 then return 'tree' end
 if roll<.88 then return 'hemp' end
 return 'copper'
end
return Z
