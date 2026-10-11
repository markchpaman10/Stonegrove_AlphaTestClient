-- Single editable source for recipes, footprints and the complete 1--99 progression.
local C={warning='Logging out or disconnecting destroys your camp and permanently loses its Tent. Stored items are recovered to your character recovery queue.'}
C.tents={
 ['Cover Tent']={image=6,level=1,storage=2,width=96,height=80,xp=20,needs={{'Angled Timber',1},{'Horizontal Timber',1},{'Vertical Timber',1}}},
 ['Leather Drape Tent']={image=7,level=5,storage=5,width=128,height=96,xp=35,needs={{'Leather',6},{'Rawhide String',6},{'Stump Pole',2}},alternative={{'Large Leather',2},{'Rawhide String',6},{'Stump Pole',2}}},
 ['Lean-to']={image=8,level=10,storage=7,width=160,height=112,xp=50,needs={{'Angled Timber',1},{'Horizontal Timber',1},{'Vertical Timber',2},{'Bush Leaves',4}}}}
C.items={'Angled Timber','Horizontal Timber','Vertical Timber','Bush Leaves','Stump Pole','Cover Tent','Leather Drape Tent','Lean-to'}
C.structures={
 {id='fire',name='Camp Fire',level=2,xp=30,station='campfire',needs={{'Pine Logs',3},{'Stone Gravel',4}}},
 {id='cook',name='Cooking Station',level=20,xp=70,station='stove',needs={{'Pine Wood Parts',4},{'Copper Bar',2}}},
 {id='wood',name='Woodworking Bench',level=25,xp=85,station='woodcraft',needs={{'Pine Logs',4},{'Pine Wood Parts',4}}},
 {id='chest',name='Storage Chest',level=30,xp=110,storage=4,needs={{'Pine Wood Parts',6},{'Copper Bar',2}}},
 {id='tailor',name='Tailoring Table',level=35,xp=125,station='tailoring',needs={{'Pine Wood Parts',6},{'Linen Cloth',4}}},
 {id='leather',name='Leatherworking Bench',level=45,xp=160,station='leathercraft',needs={{'Oak Wood Parts',4},{'Leather',4},{'Rawhide String',2}}},
 {id='smith',name='Smithing Anvil',level=50,xp=185,station='anvil',needs={{'Iron Bar',6},{'Stone Gravel',10}}},
 {id='fletch',name='Fletching Bench',level=55,xp=200,station='woodcraft',needs={{'Oak Wood Parts',6},{'Bow String',3}}},
 {id='store',name='Improved Storage',level=60,xp=230,storage=8,needs={{'Oak Wood Parts',8},{'Iron Bar',4}}},
 {id='alchemy',name='Alchemy Table',level=65,xp=260,station='alchemy',needs={{'Oak Wood Parts',8},{'Empty Flask',4},{'Iron Bar',2}}},
 {id='advanced',name='Advanced Crafting Table',level=75,xp=320,station='inscription',needs={{'Oak Wood Parts',10},{'Iron Bar',6},{'Linen Cloth',6}}},
 {id='production',name='Production Forge',level=80,xp=360,station='smelter',needs={{'Iron Bar',10},{'Stone Gravel',20}}},
 {id='enchant',name='Expedition Enchanting Altar',level=90,xp=440,station='enchantAltar',needs={{'Iron Bar',12},{'Cut Ruby',2},{'Cut Sapphire',2}}},
 {id='vault',name='Expedition Storage Vault',level=95,xp=490,storage=16,needs={{'Iron Bar',16},{'Oak Wood Parts',16}}},
 {id='bank',name='Bank Access Station',level=99,xp=600,station='bank',needs={{'Iron Bar',20},{'Oak Wood Parts',20},{'Cut Emerald',3}}}}
C.unlocks={{level=1,text='Cover Tent; 2 storage slots; camp deployment'}, {level=5,text='Leather Drape Tent; 5 storage slots'}, {level=10,text='Lean-to; 7 storage slots'}}
for _,n in ipairs({15,40,70,85})do C.unlocks[#C.unlocks+1]={level=n,text='Additional building slot'}end
for _,s in ipairs(C.structures)do C.unlocks[#C.unlocks+1]={level=s.level,text=s.name}end
table.sort(C.unlocks,function(a,b)return a.level<b.level end)
function C.slots(level,tent)
 local n=1;for _,v in ipairs({15,40,70,85})do if level>=v then n=n+1 end end
 return math.min(n,tent=='Cover Tent'and 2 or tent=='Leather Drape Tent'and 4 or 5)
end
function C.sellable(name)return name=='Shrimp Pot'or name=='Crab Pot'or name=='Lobster Pot'or name=='Angled Timber'or name=='Horizontal Timber'or name=='Vertical Timber'or name=='Stump Pole'or name=='Bush Leaves'end
function C.protected(name)if name=='Shrimp Pot'or name=='Crab Pot'or name=='Lobster Pot'then return true end;for _,n in ipairs(C.items)do if n==name then return true end end;return false end
function C.structure(id)for _,s in ipairs(C.structures)do if s.id==id then return s end end end
function C.available(inv,needs)local t={};for _,v in ipairs(needs or{})do t[#t+1]=v[2]..' '..v[1]..' ('..inv:countItem(v[1])..' available)'end;return table.concat(t,' + ')end
function C.cost(needs)local t={};for _,v in ipairs(needs or{})do t[#t+1]=v[2]..' '..v[1]end;return table.concat(t,' + ')end
function C.recipes()
 local out={};for _,name in ipairs({'Cover Tent','Leather Drape Tent','Lean-to'})do local t=C.tents[name];out[#out+1]={name=name,output=name,qty=1,skill='Fieldcraft',level=t.level,xp=t.xp,needs=t.needs,fieldcraft=true};if t.alternative then out[#out+1]={name=name..' (Large Leather)',output=name,qty=1,skill='Fieldcraft',level=t.level,xp=t.xp,needs=t.alternative,fieldcraft=true}end end;return out
end
function C.load(s)
 for i,name in ipairs(C.items)do local img=love.graphics.newImage('assets/fieldcraft_'..i..'.png');img:setFilter('nearest','nearest');s.itemImages[name]=img;s.itemInfo[name]={title=name,type=C.tents[name]and'Tent'or'Fieldcraft Material',detail=C.tents[name]and('Fieldcraft level '..C.tents[name].level..'; '..C.tents[name].storage..' storage slots. Right-click: Deploy Camp. '..C.warning)or'Used to craft Fieldcraft tents.'}end
 for _,name in ipairs({'Angled Timber','Horizontal Timber','Vertical Timber','Stump Pole'})do s.itemInfo[name].detail='Woodworking level 1. Knife required. '..(name=='Stump Pole'and 4 or 2)..' Pine Logs or Oak Logs; '..(name=='Stump Pole'and 20 or 10)..' base Woodworking XP.'end
 s.itemInfo['Bush Leaves'].detail='Use a Copper Knife or Copper Dagger on 1 Bush Greens. Produces 1 Bush Leaves; 4 base Fieldcraft XP.'
end
return C
