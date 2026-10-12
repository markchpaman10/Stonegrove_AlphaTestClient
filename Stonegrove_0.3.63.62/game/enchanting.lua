-- One definition feeds crafting/enchant tooltips and the finished gem's effect.
local E={gems={Ruby={base=5,cap=10,maxDust=10},Sapphire={base=10,cap=20,maxDust=20},Emerald={base=15,cap=30,maxDust=30},Onyx={base=5,cap=10,maxDust=10}}}
E.skills={['Melee Skill Page']='Melee Combat',['Ranged Skill Page']='Ranged',['Magic Skill Page']='Magic'}
E.spells={}
for page,s in pairs(require('game.magic_system').spells) do E.spells[page]={spell=s.name,name=s.heal and 'Healing-enchanted' or page:gsub(' Spell Page','')..'-enchanted',healing=s.heal==true} end
function E.enchant(ui,qty)
 qty=tonumber(qty);if not qty or qty~=qty or qty<1 or qty~=math.floor(qty) then return false,'invalid_dust' end
 local g,p=ui.enchantGem,ui.enchantPage;if not g or not p then return false,'no_selection' end
 local gb,pb=ui.inv:getBag(g.bag),ui.inv:getBag(p.bag);local gem,page=gb and gb.slots[g.slot],pb and pb.slots[p.slot]
 if not gem or not page or gem.name~=g.name or page.name~=p.name or (g.item and gem~=g.item) or (p.item and page~=p.item) then ui.enchantGem=nil;ui.enchantPage=nil;return false,'stale_selection' end
 local color=gem.name:match('^Cut (%a+)$');local def=E.gems[color];local spell,skill=E.spells[page.name],E.skills[page.name]
 if not def then return false,'not_cut_gem' end;if not spell and not skill then return false,'unsupported_page' end
 if gem.enchantValue then return false,'already_enchanted' end
 qty=math.min(qty,def.maxDust);local dust=color..' Dust';if ui.inv:countItem(dust)<qty then return false,'not_enough_dust' end
 local value=math.floor(math.min(def.cap,def.base+qty*.1)*10+.5)/10
 if not ui.inv:removeItems(dust,qty) then return false,'dust_remove_failed' end
 if (page.qty or 1)>1 then page.qty=page.qty-1 else pb.slots[p.slot]=nil end
 gem.enchantKind=spell and 'spell' or 'skill';gem.enchantSpell=spell and spell.spell or nil;gem.enchantSkill=skill;gem.enchantValue=value;gem.enchantDust=qty
 gem.enchantName=(spell and spell.name..' '..color or skill..' enchanted '..color)
 ui.skills:addXP('Enchanting',12+qty);ui:log('GEM_ENCHANTED',{gem=gem.name,page=page.name,dust=qty,value=value,kind=gem.enchantKind})
 ui.enchantGem=nil;ui.enchantPage=nil;return true,value
end
return E
