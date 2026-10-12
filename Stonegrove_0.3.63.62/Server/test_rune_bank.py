from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local I=require('game.inventory');local M=require('game.items');local R=require('game.rune_quality');local P=require('game.profile');local n=0;local function check(v,m)assert(v,m or tostring(n));n=n+1 end
for _,name in ipairs(R.names)do for _,grade in ipairs({'D','C','B','A'})do for _,blessed in ipairs({false,true})do
 local inv=I.new();inv.bank={};inv.bagSlots[1].size=30;local b=inv.bagSlots[1];local obj={name=name,qty=7,qualityGrade=grade,blessed=blessed};b.slots[1]=M.copy(obj);b.slots[2]=M.copy(obj)
 check(inv:depositSlot(1,1));check(inv:depositSlot(1,2));check(inv:bankUsed()==1 and inv.bank[1].qty==14,'Same metadata merges')
 check(inv:withdrawBankSlotAmount(1,1));b=inv.bagSlots[1];check(inv.bank[1].qty==13 and b.slots[1].qty==1 and M.sameMetadata(obj,b.slots[1]),'Withdraw preserves remainder and metadata')
 check(inv:withdrawBankSlotAmount(1,3));check(inv.bank[1].qty==10,'Multi withdrawal remainder')
 local packed=P.unpack(P.pack({bank=inv.bank,bags=inv.bagSlots}));check(packed.bank[1].qty==10 and packed.bank[1].qualityGrade==grade and packed.bank[1].blessed==blessed,'Save round trip')
 check(inv:withdrawBankSlotAmount(1,100));check(not inv.bank[1]);local total=0;for _,it in pairs(inv.bagSlots[1].slots)do check(M.sameMetadata(obj,it));total=total+(it.qty or 1)end;check(total==14,'No loss')
end end end
local inv=I.new();inv.bankSize=1;inv.bank={};local b=inv.bagSlots[1];b.slots[1]={name='Charred Wood',qty=2,qualityGrade='A',blessed=true};b.slots[2]={name='Charred Wood',qty=3,qualityGrade='B',blessed=true};local before=require('game.json').encode(P.pack(inv));check(not inv:depositAll('Charred Wood'));check(before==require('game.json').encode(P.pack(inv)),'Full bank deposit all atomic')
inv.bankSize=25;check(inv:depositAll('Charred Wood'));b=inv.bagSlots[1];check(inv:bankUsed()==2,'Different grades remain separate');inv.bank[3]={name='Charred Wood',qty=8,qualityGrade='A',blessed=false};b.slots[1]={name='Charred Wood',qty=1,qualityGrade='A',blessed=true};check(inv:depositSlot(1,1));check(inv.bank[1].qty==3 and inv.bank[3].qty==8,'Blessing remains separate')
for i=1,b.size do b.slots[i]={name='Copper Axe',qty=1}end;before=require('game.json').encode(P.pack(inv));check(not inv:withdrawBankSlotAmount(1,2));check(before==require('game.json').encode(P.pack(inv)),'Failed withdrawal atomic')
b.slots={};inv.bank[4]={name='Rune Bag',qty=1,materials={['Fish Bones']=5},materialGrades={['Fish Bones']={A=5}}};check(inv:withdrawBankSlot(4));b=inv.bagSlots[1];check(b.slots[1].materials['Fish Bones']==5,'Container contents retained')
local U={new=function()end,drawTooltip=function(self,it,x,y,w,h,info)return info end,drawItemSprite=function()end,usePotion=function()end,doContextOption=function()end};require('game.quality').installUI(U)
local ui=setmetatable({inv=inv,skills=require('game.skills').new(),sprites={itemInfo={}}},{__index=U})
for name in pairs(require('game.bag_system').defs)do for _,grade in ipairs({'D','C','B','A'})do local info=ui:drawTooltip({name=name,qualityGrade=grade},0,0,100,100,{type='Shop stock x1',detail='Buy: 65s   Sell: 32s'});check(info.detail:find('Buy: 65s',1,true)and info.detail:find('Sell: 32s',1,true)and info.detail:find('Total available slots:',1,true),'Bag shop price and capacity')end end
return 'PASS '..n..' bank quantity/grade/blessing conservation, atomic failures, container and bag price tooltip checks'
'''))
finally:s.close()
