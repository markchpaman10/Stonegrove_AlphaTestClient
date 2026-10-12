local L={}
function L.roll(kind,random)
 random=random or math.random
 local out={skin={},death={}}
 local function add(list,name,qty)if qty>0 then list[#list+1]={name,qty}end end
 if kind=='rat' then
  add(out.skin,random(1,100)<=75 and 'Raw Hide' or 'Torn Hide',1);add(out.skin,'Small Meat',random(3,6))
 elseif kind=='caveSnake' then
  add(out.skin,'Raw Cave Snake Hide',random(1,100)<=75 and random(1,2) or 0);add(out.skin,'Cave Snake Meat',random(2,5));add(out.death,'Cave Snake Fang',random(0,3));add(out.death,'Stamina Potion ('..random(1,3)..'/3)',1)
 elseif kind=='gigaRat' then
  add(out.skin,'Extra Large Raw Hide',random(1,2));add(out.skin,'Giga Rat Meat',random(3,6));add(out.death,'Giga Rat Blood',random(0,2));add(out.death,'Stamina Potion ('..random(1,3)..'/3)',1)
 elseif kind=='slimeBoss' then
  for _,name in ipairs({'Potent Slime Jar','Slime-coated Bones','Pickled Large Meat','Pickled Small Meat'})do add(out.death,name,random(1,100)<=75 and random(1,3) or 0)end
  add(out.death,'Stamina Potion ('..random(1,3)..'/3)',1)
 end
 return out
end
function L.ensure(e)e.randomLoot=e.randomLoot or L.roll(e.kind);return e.randomLoot end
function L.drop(w,e)
 if e.lootPaid then return end;e.lootPaid=true
 local drops=L.ensure(e).death;local total=0;for _,d in ipairs(drops)do total=total+d[2]end
 local i=0;for _,d in ipairs(drops)do for n=1,d[2]do i=i+1;w:dropScattered(d[1],e.x,e.y,i,total)end end
end
return L
