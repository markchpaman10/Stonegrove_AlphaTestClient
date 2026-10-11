-- One source for food healing and its displayed values.
local Food={healing={['Cooked Chicken']=4,['Brown Mushroom']=2,['Red Berries']=1,['Purple Berries']=1}}
local grades={'D','C','B','A'}
for name,values in pairs({['Cooked Chicken']={4,6,8,10},['Cooked Shrimp']={4,5,6,8},['Cooked Swordfish']={90,110,130,150},['Cooked Small Fish']={2,3,4,5},['Cooked Large Fish']={6,8,10,12},['Cooked Eel']={9,12,15,18},['Cooked Manta Ray']={30,40,50,60},['Cooked Crab Meat']={12,16,20,24},['Cooked Lobster Meat']={70,85,100,115},['Jerky']={3,5,7,9},['Cooked Small Meat']={4,6,8,10},['Cooked Fish Fillet']={6,8,10,12},['Cooked Large Meat']={8,11,14,17},['Cooked Giga Rat Meat']={30,40,50,60},['Cooked Cave Snake Meat']={65,80,95,110}}) do
 for i,grade in ipairs(grades) do Food.healing[name..' '..grade]=values[i] end
end
for _,name in ipairs({'Shrimp','Swordfish','Small Fish','Large Fish','Eel','Manta Ray','Crab Meat','Lobster Meat','Chicken','Jerky','Small Meat','Fish Fillet','Large Meat','Giga Rat Meat','Cave Snake Meat'}) do Food.healing['Burnt '..name]=1 end
for _,grade in ipairs(grades) do Food.healing['Cooked Jerky '..grade]=Food.healing['Jerky '..grade] end
function Food.apply(sprites)
 for name,heal in pairs(Food.healing) do
  local info=sprites.itemInfo[name]
  if info then
   info.heal=heal
   local detail,count=(info.detail or ''):gsub('Restores %d+ health','Restores '..heal..' health')
   if count==0 then detail=detail..' Restores '..heal..' health.' end
   info.detail=detail
  end
 end
end
for n,d in pairs(require('game.high_tier_fish').data)do if d.heals then for i,g in ipairs({'D','C','B','A'})do Food.healing['Cooked '..n..' '..g]=d.heals[i]end;Food.healing['Burnt '..n]=1 end end
return Food
