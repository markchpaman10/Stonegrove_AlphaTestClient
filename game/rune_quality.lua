local R={order={'A','B','C','D'},names={'Charred Wood','Fish Bones','Stone Gravel','Carved Feather','Carved Onyx','Green Slime Tube','Cave Snake Fang'}}
local Q=require('game.quality')
function R.grade(obj)local g=Q.grade(obj);return Q.factors[g]and g or'C'end
function R.capacity(b)return ({D=50,C=60,B=70,A=80})[Q.grade(b)]or 50 end
function R.spellFactor(b)return ({D=1,C=1.05,B=1.10,A=1.15})[Q.grade(b)]or 1 end
function R.ensure(b)
 if not b then return end;b.materials=b.materials or{};b.materialGrades=b.materialGrades or{}
 for _,n in ipairs(R.names)do
  local total=math.max(0,math.floor(tonumber(b.materials[n])or 0));local g=b.materialGrades[n]or{};b.materialGrades[n]=g
  local sum=0;for _,grade in ipairs(R.order)do local qty=math.max(0,math.min(total-sum,math.floor(tonumber(g[grade])or 0)));g[grade]=qty;sum=sum+qty end
  g.C=g.C+total-sum;b.materials[n]=total
 end;return b
end
function R.deposit(b,it,qty)
 R.ensure(b);local n=it.name;local g=b.materialGrades[n];if not g or not it.blessed then return 0 end
 local move=math.max(0,math.min(qty or it.qty or 1,R.capacity(b)-b.materials[n]));local grade=R.grade(it);g[grade]=g[grade]+move;b.materials[n]=b.materials[n]+move;return move
end
function R.select(ui,name)
 local b=R.ensure(ui:runeBag());if b then for _,g in ipairs(R.order)do if(b.materialGrades[name]or{})[g]and b.materialGrades[name][g]>0 then return g,b end end end
 local best,index,slot;for bi,bag in pairs(ui.inv.bagSlots)do for si,it in pairs(bag.slots)do if it.name==name and it.blessed and(it.qty or 1)>0 then local g=R.grade(it);if not best or Q.factors[g]>Q.factors[best]then best,index,slot=g,bi,si end end end end
 return best,nil,index,slot
end
function R.consume(ui,name)
 local grade,b,bi,si=R.select(ui,name);if not grade then return false end
 if b then b.materialGrades[name][grade]=b.materialGrades[name][grade]-1;b.materials[name]=b.materials[name]-1
 else local bag=ui.inv.bagSlots[bi];local it=bag.slots[si];it.qty=(it.qty or 1)-1;if it.qty<=0 then bag.slots[si]=nil end end
 return true,grade
end
function R.withdraw(b,n,inv)
 R.ensure(b);if not n or not b.materialGrades[n]or b.materials[n]<=0 then return false end
 local trial=require('game.rune_inventory').clone(inv)
 for _,g in ipairs(R.order)do local qty=b.materialGrades[n][g];if qty>0 and not trial:addItemObject({name=n,qty=qty,blessed=true,qualityGrade=g})then return false end end
 inv.bagSlots=trial.bagSlots;b.materials[n]=0;b.materialGrades[n]={};return true
end
function R.detail(b,n)
 R.ensure(b);local out={};for _,g in ipairs(R.order)do local qty=b.materialGrades[n][g];if qty>0 then out[#out+1]=g..': '..qty end end
 return table.concat(out,' | ')..'\nRune Bag first; highest grade first. D 80%, C 100%, B 120%, A 140% spell strength.'
end
return R
