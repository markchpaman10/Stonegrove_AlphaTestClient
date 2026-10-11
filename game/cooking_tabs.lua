-- View-only filters: preserve authoritative recipe indices and active batches.
local T={names={'Fish','Meat','Meals'}}
local fish={['Raw Tuna']=true,['Raw Shark']=true,['Raw Swordfish']=true,['Raw Manta Ray']=true,Tuna=true,Shark=true,['Small Fish']=true,['Large Fish']=true,Eel=true,Shrimp=true,Swordfish=true,['Manta Ray']=true,['Raw Fish Fillet']=true,['Crab Meat']=true,['Lobster Meat']=true,['Raw Lobster Tail']=true}
function T.is(station)return station=='stove'or station=='campfire'end
function T.category(r)
 if r.name=='Surf and Turf'or r.output=='Surf and Turf'or #(r.needs or{})>1 then return 'Meals'end
 if fish[((r.needs or{})[1]or{})[1]]then return 'Fish'end
 return 'Meat'
end
function T.selected(u,station)return(u.cookingTabs or{})[station]or'Fish'end
function T.view(u,station)
 local recipes=u.crafting:getRecipes(station);if not T.is(station)then return recipes end
 local out,indices={},{};local selected=T.selected(u,station)
 for i,r in ipairs(recipes)do if T.category(r)==selected then out[#out+1]=r;indices[#indices+1]=i end end
 return out,indices
end
function T.tabAt(u,station,mx,my)
 if not T.is(station)then return end
 local x,y,w=u:rect(station);local width=(w-32)/3
 for i,name in ipairs(T.names)do local bx=x+16+(i-1)*width;if mx>=bx and mx<bx+width-4 and my>=y+34 and my<y+60 then return name end end
end
function T.select(u,station,name)
 u.cookingTabs=u.cookingTabs or{};u.cookingTabs[station]=name;u.craftScroll[station]=0
end
function T.draw(u,station)
 if not T.is(station)then return end
 local x,y,w=u:rect(station);local width=(w-32)/3;local g=love.graphics
 for i,name in ipairs(T.names)do local bx=x+16+(i-1)*width;local active=T.selected(u,station)==name
  g.setColor(active and .28 or .10,active and .23 or .10,active and .14 or .08,.96);g.rectangle('fill',bx,y+34,width-4,26,4,4)
  g.setColor(.72,.62,.40);g.rectangle('line',bx,y+34,width-4,26,4,4);g.setColor(1,1,1);g.printf(name,bx,y+41,width-4,'center')
 end
end
function T.rowY(station)return T.is(station)and 74 or 42 end
return T
