local S={}
local NPCCosmetics=require("game.npc_cosmetics")
local function q(x,y,w,h,img) local iw,ih=img:getDimensions();return love.graphics.newQuad(x,y,w,h,iw,ih) end
local function directional(img,offset)
 local t={up={},right={},down={}};for row,name in ipairs({"up","right","down"}) do for col=1,4 do t[name][col]=q((col-1)*16+(offset or 0),(row-1)*16,16,16,img) end end;return t
end
local function objectColor(path)
 local ok,data=pcall(love.image.newImageData,path);if not ok or not data then return {.75,.75,.75} end
 local r,g,b,n=0,0,0,0;local w,h=data:getDimensions()
 for y=0,h-1 do for x=0,w-1 do local pr,pg,pb,pa=data:getPixel(x,y);local bright=math.max(pr,pg,pb)
  if pa>.25 and bright>.16 then r=r+pr;g=g+pg;b=b+pb;n=n+1 end
 end end
 if n==0 then return {.75,.75,.75} end;return {r/n,g/n,b/n}
end
function S.load()
 local s={}
 s.npcCosmetics=NPCCosmetics.load()
 s.medievalImage=love.graphics.newImage("assets/medieval.png");s.medievalImage:setFilter("nearest","nearest")
 s.raceEars={}
 for race,path in pairs({Human='assets/human_ears.png',Elf='assets/elf_ears.png'}) do
  local image=love.graphics.newImage(path);image:setFilter('nearest','nearest')
  s.raceEars[race]={image=image,frames=directional(image,race=="Elf" and 1 or 0)}
 end
 s.goblins=require("game.goblins").load(s.medievalImage)
 s.houses=require("game.houses").load()
 s.houseRoofs={love.graphics.newImage("assets/house_roof_1.png"),love.graphics.newImage("assets/house_roof_2.png")};s.houseRooms={love.graphics.newImage("assets/house_room_1.png"),love.graphics.newImage("assets/house_room_2.png")};s.houseSecondStory=love.graphics.newImage("assets/house_second_story.png");s.gravelPathImage=love.graphics.newImage("assets/gravel_path.png");s.gravelFillImage=love.graphics.newImage("assets/gravel_fill.png");s.gravelFillImage:setWrap("repeat","repeat");s.magicAltarImage=love.graphics.newImage("assets/magic_altar.png");s.religionAltarImage=love.graphics.newImage("assets/religion_altar.png");s.religionBlessImage=love.graphics.newImage("assets/religion_blessing.png");s.religionBlessImage:setFilter("nearest","nearest");s.religionBlessQuads={};for i=0,4 do s.religionBlessQuads[i+1]=q(i*16,0,16,16,s.religionBlessImage) end;s.socketTableImage=love.graphics.newImage("assets/socket_table.png");s.enchantAltarImage=love.graphics.newImage("assets/enchant_altar.png");s.inscriptionTableImage=love.graphics.newImage("assets/station_inscriptionTable.png");s.tailorTableImage=love.graphics.newImage("assets/station_tailorTable.png");s.commandingIconImage=love.graphics.newImage("assets/skill_commanding.png");s.commanderHeadImage=love.graphics.newImage("assets/commander_head.png");s.commanderArmorImage=love.graphics.newImage("assets/commander_armor.png");s.commanderRecruitArmorQuad=q(0,32,16,16,s.commanderArmorImage);s.commanderRecruitHeadQuad=q(0,36,16,18,s.commanderHeadImage);s.magicBoltsImage=love.graphics.newImage("assets/magic_bolts.png");s.magicEffectsImage=love.graphics.newImage("assets/magic_effects.png"); s.grassImages={love.graphics.newImage("assets/grass_1.png"),love.graphics.newImage("assets/grass_2.png"),love.graphics.newImage("assets/grass_3.png"),love.graphics.newImage("assets/grass_4.png")};s.slimeImage=love.graphics.newImage("assets/monster_slime.png");s.slimeProjectileImage=love.graphics.newImage("assets/projectile_slime.png");s.slimePuddleImage=love.graphics.newImage("assets/puddle_slime.png");s.ratImage=love.graphics.newImage("assets/monster_rat.png");s.wolfImage=love.graphics.newImage("assets/monster_wolf.png");s.headImage=love.graphics.newImage("assets/charHead.png");s.bodyImage=love.graphics.newImage("assets/charBody.png");s.player={head=directional(s.headImage),body=directional(s.bodyImage)};s.capeImage=love.graphics.newImage("assets/paperdoll_cape.png");s.capeImage:setFilter("nearest","nearest");s.cape=directional(s.capeImage)
 s.treeImage=love.graphics.newImage("assets/basicTree.png");s.tree={full=q(0,0,16,32,s.treeImage),depleted=love.graphics.newImage("assets/stumpPine.png")};s.snowPineImage=love.graphics.newImage("assets/treePineSnow.png");s.snowPineStumpImage=love.graphics.newImage("assets/stumpPineSnow.png")
 s.poplarStumpImage=love.graphics.newImage("assets/stumpPoplar.png");s.poplarStumpImage:setFilter("nearest","nearest")
 s.poplarTreeImage=love.graphics.newImage("assets/treePoplar.png");s.snowPoplarImage=love.graphics.newImage("assets/treePoplarSnow.png");s.poplarTreeImage:setFilter("nearest","nearest");s.snowPoplarImage:setFilter("nearest","nearest")
 s.oakTreeImage=love.graphics.newImage("assets/treeOak.png");s.oakStumpImage=love.graphics.newImage("assets/stumpOak.png");s.snowOakImage=love.graphics.newImage("assets/treeOakSnow.png");s.snowOakStumpImage=love.graphics.newImage("assets/stumpOakSnow.png")
 s.copperImage=love.graphics.newImage("assets/oreCopper_new.png");s.copper={full=q(0,0,16,16,s.copperImage),mined=q(16,0,16,16,s.copperImage),depleted=q(32,0,16,16,s.copperImage)}
 s.gemRockImages={ruby=love.graphics.newImage("assets/gemRock_ruby.png"),sapphire=love.graphics.newImage("assets/gemRock_emerald.png"),emerald=love.graphics.newImage("assets/gemRock_sapphire.png")}
 s.tinImage=love.graphics.newImage("assets/oreTin.png");s.tin={full=q(0,0,16,16,s.tinImage),depleted=q(16,0,16,16,s.tinImage)}
 s.barBronzeImage=love.graphics.newImage("assets/barBronze.png")
 s.alchemyMortarImage=love.graphics.newImage("assets/station_alchemyMortar.png");s.hammerImage=love.graphics.newImage("assets/toolHammer_copper.png");s.tongsImage=love.graphics.newImage("assets/toolTongs_copper.png");s.spinningWheelImage=love.graphics.newImage("assets/station_spinningWheel.png");s.hempImage=love.graphics.newImage("assets/resource_hemp.png");s.flaxImage=love.graphics.newImage("assets/resource_flax.png");s.sheepImage=love.graphics.newImage("assets/animal_sheep.png");s.sheepWoolQuad=q(0,0,32,16,s.sheepImage);s.sheepShornQuad=q(32,0,32,16,s.sheepImage);s.fishingPoleImage=love.graphics.newImage("assets/toolFishingPole.png");s.fishingPoleQuads={rest=q(0,0,16,16,s.fishingPoleImage),cast=q(16,0,16,16,s.fishingPoleImage),hook=q(32,0,16,16,s.fishingPoleImage)}
 s.stoveImage=love.graphics.newImage("assets/station_stove.png");s.tanningVatImage=love.graphics.newImage("assets/station_tanningVat.png");s.stretcherEmptyImage=love.graphics.newImage("assets/station_hideStretcher_empty.png");s.stretcherSoakedImage=love.graphics.newImage("assets/station_hideStretcher_soaked.png");s.stretcherDoneImage=love.graphics.newImage("assets/station_hideStretcher_done.png")
 s.chickenImage=love.graphics.newImage("assets/animalChickens.png");s.chickenQuads={hen=q(0,0,16,16,s.chickenImage),rooster=q(16,0,16,16,s.chickenImage)}
 s.cowImage=love.graphics.newImage("assets/animalCow.png");s.cowQuads={stand=q(0,0,32,16,s.cowImage),eat=q(32,0,32,16,s.cowImage)}
 s.chickenMeatImage=love.graphics.newImage("assets/meatChicken.png")
 s.coinCopperImage=love.graphics.newImage("assets/coinCopper.png");s.coinSilverImage=love.graphics.newImage("assets/coinSilver.png");s.coinGoldImage=love.graphics.newImage("assets/coinGold.png")
 s.coinQuads={
  ["Copper Coins"]={single=q(0,0,16,16,s.coinCopperImage),pile=q(16,0,16,16,s.coinCopperImage)},
  ["Silver Coins"]={single=q(0,0,16,16,s.coinSilverImage),pile=q(16,0,16,16,s.coinSilverImage)},
  ["Gold Coins"]={single=q(0,0,16,16,s.coinGoldImage),pile=q(16,0,16,16,s.coinGoldImage)}
 }
 -- Armor sheets: body rows 0-2, helmet rows 3-5; directions up/right/down.
 s.armorCopperImage=love.graphics.newImage("assets/armor_copper.png");s.armorCopper={helm={up={},right={},down={}},body={up={},right={},down={}}};for row,name in ipairs({"up","right","down"}) do for col=1,4 do s.armorCopper.body[name][col]=q((col-1)*16,(row-1)*16,16,16,s.armorCopperImage);s.armorCopper.helm[name][col]=q((col-1)*16,(row+2)*16,16,16,s.armorCopperImage) end end
 s.armorWizardImage=love.graphics.newImage("assets/armor_wizard.png");s.armorWizard={helm={up={},right={},down={}},body={up={},right={},down={}}};for row,name in ipairs({"up","right","down"}) do for col=1,4 do s.armorWizard.body[name][col]=q((col-1)*16,(row-1)*16,16,16,s.armorWizardImage);s.armorWizard.helm[name][col]=q((col-1)*16,(row+2)*16,16,16,s.armorWizardImage) end end
 s.armorLeatherImage=love.graphics.newImage("assets/armor_leather.png");s.armorLeather={helm={up={},right={},down={}},body={up={},right={},down={}}};for row,name in ipairs({"up","right","down"}) do for col=1,4 do s.armorLeather.body[name][col]=q((col-1)*16,(row-1)*16,16,16,s.armorLeatherImage);s.armorLeather.helm[name][col]=q((col-1)*16,(row+2)*16,16,16,s.armorLeatherImage) end end
 s.torchStandingLitImage=love.graphics.newImage("assets/torch_standing_lit.png")
 s.torchStandingUnlitImage=love.graphics.newImage("assets/torch_standing_unlit.png")
 s.runeMaterialsImage=love.graphics.newImage("assets/rune_materials.png");s.runeMaterialsImage:setFilter("nearest","nearest")
 s.runeMaterialQuads={charred=q(0,0,16,16,s.runeMaterialsImage),bones=q(16,0,16,16,s.runeMaterialsImage),gravel=q(32,0,16,16,s.runeMaterialsImage),feather=q(48,0,16,16,s.runeMaterialsImage),onyx=q(64,0,16,16,s.runeMaterialsImage),slime=q(80,0,16,16,s.runeMaterialsImage),bag=q(96,0,16,16,s.runeMaterialsImage)}
 s.itemImages={
  ["Cape"]=love.graphics.newImage("assets/item_cape.png"),
  ["Charred Wood"]=s.runeMaterialsImage,["Fish Bones"]=s.runeMaterialsImage,["Stone Gravel"]=s.runeMaterialsImage,["Carved Feather"]=s.runeMaterialsImage,["Carved Onyx"]=s.runeMaterialsImage,["Green Slime Tube"]=s.runeMaterialsImage,["Rune Bag"]=s.runeMaterialsImage,["Rough Onyx"]=love.graphics.newImage("assets/gemRough_onyx.png"),
  ["Inscription Pen and Ink"]=love.graphics.newImage("assets/toolInscriptionPenInk.png"),
  ["Spellbook"]=love.graphics.newImage("assets/itemSpellbook.png"),
  ["Water Spell Page"]=love.graphics.newImage("assets/page_water.png"),
  ["Earth Spell Page"]=love.graphics.newImage("assets/page_earth.png"),
  ["Fire Spell Page"]=love.graphics.newImage("assets/page_fire.png"),
  ["Air Spell Page"]=love.graphics.newImage("assets/page_air.png"),
  ["Void Spell Page"]=love.graphics.newImage("assets/page_void.png"),
  ["Empty Spell Page"]=love.graphics.newImage("assets/page_empty.png"),
  ["Healing Spell Page"]=love.graphics.newImage("assets/page_healing.png"),
  ["Melee Skill Page"]=love.graphics.newImage("assets/page_skill_melee.png"),
  ["Ranged Skill Page"]=love.graphics.newImage("assets/page_skill_ranged.png"),
  ["Magic Skill Page"]=love.graphics.newImage("assets/page_skill_magic.png"),
  ["Egg"]=love.graphics.newImage("assets/itemEgg.png"),
  ["Feather"]=love.graphics.newImage("assets/itemFeather.png"),
  ["Raw Chicken"]=s.chickenMeatImage,
  ["Cooked Chicken"]=s.chickenMeatImage,
  ["Burnt Chicken"]=s.chickenMeatImage,
  ["Jerky A"]=love.graphics.newImage("assets/jerky_cooked.png"),
  ["Jerky B"]=love.graphics.newImage("assets/jerky_cooked.png"),
  ["Jerky C"]=love.graphics.newImage("assets/jerky_cooked.png"),
  ["Jerky D"]=love.graphics.newImage("assets/jerky_cooked.png"),
  ["Burnt Jerky"]=love.graphics.newImage("assets/meatSmall_burnt.png"),
  ["Copper Shield"]=love.graphics.newImage("assets/itemCopperShield.png"),
  ["Rawhide String"]=love.graphics.newImage("assets/itemRawhideString.png"),
  ["Fishing Pole"]=love.graphics.newImage("assets/toolFishingPole.png"),
  ["Large Fish"]=love.graphics.newImage("assets/fishLarge.png"),
  ["Small Fish"]=love.graphics.newImage("assets/fishSmall.png"),
  ["Eel"]=love.graphics.newImage("assets/fishEel.png"),
  ["Raw Fish Fillet"]=love.graphics.newImage("assets/fishFillet_raw.png"),
  ["Cooked Fish Fillet A"]=love.graphics.newImage("assets/fishFillet_cooked.png"),
  ["Cooked Fish Fillet B"]=love.graphics.newImage("assets/fishFillet_cooked.png"),
  ["Cooked Fish Fillet C"]=love.graphics.newImage("assets/fishFillet_cooked.png"),
  ["Cooked Fish Fillet D"]=love.graphics.newImage("assets/fishFillet_cooked.png"),
  ["Burnt Fish Fillet"]=love.graphics.newImage("assets/fishFillet_burnt.png"),
  ["Large Meat"]=love.graphics.newImage("assets/meatLarge_raw.png"),
  ["Cooked Large Meat A"]=love.graphics.newImage("assets/meatLarge_cooked.png"),
  ["Cooked Large Meat B"]=love.graphics.newImage("assets/meatLarge_cooked.png"),
  ["Cooked Large Meat C"]=love.graphics.newImage("assets/meatLarge_cooked.png"),
  ["Cooked Large Meat D"]=love.graphics.newImage("assets/meatLarge_cooked.png"),
  ["Burnt Large Meat"]=love.graphics.newImage("assets/meatLarge_burnt.png"),
  ["Small Meat"]=love.graphics.newImage("assets/meatSmall_raw.png"),
  ["Cooked Small Meat A"]=love.graphics.newImage("assets/meatSmall_cooked.png"),
  ["Cooked Small Meat B"]=love.graphics.newImage("assets/meatSmall_cooked.png"),
  ["Cooked Small Meat C"]=love.graphics.newImage("assets/meatSmall_cooked.png"),
  ["Cooked Small Meat D"]=love.graphics.newImage("assets/meatSmall_cooked.png"),
  ["Burnt Small Meat"]=love.graphics.newImage("assets/meatSmall_burnt.png"),
  ["Needle"]=love.graphics.newImage("assets/toolNeedle.png"),
  ["Wizard Hat"]=love.graphics.newImage("assets/itemWizardHat.png"),
  ["Wizard Robes"]=love.graphics.newImage("assets/itemWizardRobes.png"),
  ["Dyed Blue Cloth Strip"]=love.graphics.newImage("assets/itemLinenCloth_blue.png"),
  ["Blue Dye"]=love.graphics.newImage("assets/itemBlueDye.png"),
  ["Cloth Strip"]=love.graphics.newImage("assets/itemClothStrip.png"),
  ["Shears"]=love.graphics.newImage("assets/toolShears.png"),
  ["Wool"]=love.graphics.newImage("assets/itemWool.png"),
  ["Wool Thread"]=love.graphics.newImage("assets/itemWoolThread.png"),
  ["Flax"]=love.graphics.newImage("assets/resource_flax.png"),
  ["Linen Cloth"]=love.graphics.newImage("assets/itemLinenCloth.png"),
  ["Linen Bag"]=love.graphics.newImage("assets/linen_bag.png"),
  ["Torch"]=love.graphics.newImage("assets/torch_unlit.png"),
  ["Lit Torch"]=love.graphics.newImage("assets/torch_lit.png"),
  ["Staff"]=love.graphics.newImage("assets/weaponStaff.png"),
  ["Empty Flask"]=love.graphics.newImage("assets/itemFlask_empty.png"),
  ["Empty Tube"]=love.graphics.newImage("assets/itemTube_empty.png"),
  ["Large Blue Mushroom"]=love.graphics.newImage("assets/itemMushroom_blueLarge.png"),
  ["Brown Mushroom"]=love.graphics.newImage("assets/itemMushroom_brown.png"),
  ["Bush Root"]=love.graphics.newImage("assets/itemBushRoot.png"),
  ["Bush Greens"]=love.graphics.newImage("assets/itemBushGreens.png"),
  ["Purple Berries"]=love.graphics.newImage("assets/itemBerry_purple.png"),
  ["Red Berries"]=love.graphics.newImage("assets/itemBerry_red.png"),
  ["Health Flask"]=love.graphics.newImage("assets/potionHealth_flask.png"),
  ["Health Tube"]=love.graphics.newImage("assets/potionHealth_tube.png"),
  ["Antipoison Flask"]=love.graphics.newImage("assets/potionAntipoison_flask.png"),
  ["Antipoison Tube"]=love.graphics.newImage("assets/potionAntipoison_tube.png"),
  ["Stamina Potion (3/3)"]=love.graphics.newImage("assets/potionStamina.png"),
  ["Stamina Potion (2/3)"]=love.graphics.newImage("assets/potionStamina.png"),
  ["Stamina Potion (1/3)"]=love.graphics.newImage("assets/potionStamina.png"),
  ["Copper Helm"]=love.graphics.newImage("assets/itemArmor_copper.png"),
  ["Copper Armor"]=love.graphics.newImage("assets/itemHelm_copper.png"),
  ["Leather Armor"]=love.graphics.newImage("assets/itemArmor_leather.png"),
  ["Leather Helm"]=love.graphics.newImage("assets/itemHelm_leather.png"),
  ["Copper Longsword"]=love.graphics.newImage("assets/weaponSword_copperLongSword.png"),
  ["Copper Dagger"]=love.graphics.newImage("assets/weaponDagger_copper.png"),
  ["Copper Knife"]=love.graphics.newImage("assets/weaponDagger_copper.png"),
  ["Flint and Steel"]=love.graphics.newImage("assets/toolFlintSteel.png"),
  ["Copper Axe"]=love.graphics.newImage("assets/toolAxe_copper.png"),
  ["Copper Pickaxe"]=love.graphics.newImage("assets/toolPick_copper.png"),
  ["Copper Hammer"]=s.hammerImage,
  ["Chisel"]=love.graphics.newImage("assets/toolChisel.png"),
  ["Ruby-bearing Rock"]=love.graphics.newImage("assets/gemRock_ruby.png"),["Sapphire-bearing Rock"]=love.graphics.newImage("assets/gemRock_emerald.png"),["Emerald-bearing Rock"]=love.graphics.newImage("assets/gemRock_sapphire.png"),
  ["Rough Ruby"]=love.graphics.newImage("assets/gemRough_ruby.png"),["Rough Sapphire"]=love.graphics.newImage("assets/gemRough_emerald.png"),["Rough Emerald"]=love.graphics.newImage("assets/gemRough_sapphire.png"),
  ["Cut Ruby"]=love.graphics.newImage("assets/gemCut_ruby.png"),["Cut Sapphire"]=love.graphics.newImage("assets/gemCut_emerald.png"),["Cut Emerald"]=love.graphics.newImage("assets/gemCut_sapphire.png"),
  ["Ruby Dust"]=love.graphics.newImage("assets/gemDust_ruby.png"),["Sapphire Dust"]=love.graphics.newImage("assets/gemDust_sapphire.png"),["Emerald Dust"]=love.graphics.newImage("assets/gemDust_emerald.png"),
  ["Copper Tongs"]=s.tongsImage,
  ["Copper ore"]=love.graphics.newImage("assets/itemOreCopper.png"),
  ["Small Copper Chunk"]=love.graphics.newImage("assets/itemCopperChunk_small.png"),
  ["Large Copper Chunk"]=love.graphics.newImage("assets/itemCopperChunk_large.png"),
  ["Pine Logs"]=love.graphics.newImage("assets/itemLog_pine.png"),
  ["Poplar Logs"]=love.graphics.newImage("assets/itemLog_poplar.png"),
  ["Oak Logs"]=love.graphics.newImage("assets/itemLog_oak.png"),
  ["Large Raw Leather"]=love.graphics.newImage("assets/itemLargeRawLeather.png"),
  ["Large Soaked Leather"]=love.graphics.newImage("assets/itemLargeSoakedLeather.png"),
  ["Large Leather"]=love.graphics.newImage("assets/itemLargeLeather.png"),
  ["Logs"]=love.graphics.newImage("assets/itemLog_basic.png"),
  ["Copper Bar"]=love.graphics.newImage("assets/itemBar_copper.png"),
  ["Basic Wood Parts"]=love.graphics.newImage("assets/itemParts_basicWood.png"),
  ["Green Slime Jar"]=love.graphics.newImage("assets/itemMonTreasure_greenSlimeJar.png"),
  ["Raw Hide"]=love.graphics.newImage("assets/itemHide_raw.png"),
  ["Torn Hide"]=love.graphics.newImage("assets/itemHide_torn.png"),
  ["Soaked Hide"]=love.graphics.newImage("assets/itemHide_soaked.png"),
  ["Leather"]=love.graphics.newImage("assets/itemLeather.png"),
  ["Bones"]=love.graphics.newImage("assets/itemBones.png"),
  ["Hemp Fibers"]=love.graphics.newImage("assets/itemHempFibers.png"),
  ["Bow String"]=love.graphics.newImage("assets/itemBowString.png"),
  ["Arrow Shafts"]=love.graphics.newImage("assets/itemArrowShaft.png"),
  ["Copper Arrowheads"]=love.graphics.newImage("assets/itemArrowhead_copper.png"),
  ["Copper Arrows"]=love.graphics.newImage("assets/itemArrow_copper.png"),
  ["Quiver"]=love.graphics.newImage("assets/itemQuiver.png"),
  ["Unstrung Bow"]=love.graphics.newImage("assets/itemBow_unstrung.png"),
  ["Bow"]=love.graphics.newImage("assets/weaponBow.png"),
  ["Pine Wood Parts"]=love.graphics.newImage("assets/itemParts_basicWood.png"),
  ["Oak Wood Parts"]=love.graphics.newImage("assets/itemParts_basicWood.png"),
  ["Pine Staff"]=love.graphics.newImage("assets/weaponPineStaff.png"),
  ["Oak Staff"]=love.graphics.newImage("assets/weaponStaff.png"),
  ["Pine Arrow Shafts"]=love.graphics.newImage("assets/itemArrowShaft.png"),
  ["Oak Arrow Shafts"]=love.graphics.newImage("assets/itemArrowShaft.png"),
  ["Pine Unstrung Bow"]=love.graphics.newImage("assets/itemBow_unstrung.png"),
  ["Oak Unstrung Bow"]=love.graphics.newImage("assets/itemBow_unstrung.png"),
  ["Pine Bow"]=love.graphics.newImage("assets/weaponBow.png"),
  ["Oak Bow"]=love.graphics.newImage("assets/weaponBow.png"),
  ["Bronze bar"]=s.barBronzeImage,
  ["Large Leather Bag"]=love.graphics.newImage("assets/leather_bagLarge_closed.png"),
  ["Small Leather Bag"]=love.graphics.newImage("assets/leather_bagSmall_small.png"),
  ["Small Leather Bag D"]=love.graphics.newImage("assets/leather_bagSmall_small.png"),["Small Leather Bag C"]=love.graphics.newImage("assets/leather_bagSmall_small.png"),["Small Leather Bag B"]=love.graphics.newImage("assets/leather_bagSmall_small.png"),["Small Leather Bag A"]=love.graphics.newImage("assets/leather_bagSmall_small.png"),
  ["Large Leather Bag D"]=love.graphics.newImage("assets/leather_bagLarge_closed.png"),["Large Leather Bag C"]=love.graphics.newImage("assets/leather_bagLarge_closed.png"),["Large Leather Bag B"]=love.graphics.newImage("assets/leather_bagLarge_closed.png"),["Large Leather Bag A"]=love.graphics.newImage("assets/leather_bagLarge_closed.png"),
  ["Copper Coins"]=s.coinCopperImage,
  ["Silver Coins"]=s.coinSilverImage,
  ["Gold Coins"]=s.coinGoldImage
 }
 -- Explicit frames for inventory images that are sprite sheets.
 s.itemImages["Tin ore"]=s.tinImage
 s.itemQuads={["Tin ore"]=s.tin.full}
 s.itemQuads=s.itemQuads or {};s.itemQuads["Charred Wood"]=s.runeMaterialQuads.charred;s.itemQuads["Fish Bones"]=s.runeMaterialQuads.bones;s.itemQuads["Stone Gravel"]=s.runeMaterialQuads.gravel;s.itemQuads["Carved Feather"]=s.runeMaterialQuads.feather;s.itemQuads["Carved Onyx"]=s.runeMaterialQuads.onyx;s.itemQuads["Green Slime Tube"]=s.runeMaterialQuads.slime;s.itemQuads["Rune Bag"]=s.runeMaterialQuads.bag
 for _,grade in ipairs({"A","B","C","D"}) do
  s.itemImages["Cooked Jerky "..grade]=s.itemImages["Jerky "..grade]
 end
 s.itemQuads["Burnt Jerky"]=q(4,1,9,9,s.itemImages["Burnt Jerky"])
 s.itemQuads["Raw Chicken"]=q(0,0,16,16,s.chickenMeatImage);s.itemQuads["Cooked Chicken"]=q(16,0,16,16,s.chickenMeatImage);s.itemQuads["Burnt Chicken"]=q(32,0,16,16,s.chickenMeatImage)
 s.quiverQuads={empty=love.graphics.newQuad(0,0,16,16,32,16),copper=love.graphics.newQuad(16,0,16,16,32,16)}
 s.itemQuads["Stamina Potion (3/3)"]=q(0,0,16,16,s.itemImages["Stamina Potion (3/3)"])
 s.itemQuads["Stamina Potion (2/3)"]=q(16,0,16,16,s.itemImages["Stamina Potion (2/3)"])
 s.itemQuads["Stamina Potion (1/3)"]=q(32,0,16,16,s.itemImages["Stamina Potion (1/3)"])
 s.itemInfo={
  ["Cape"]={title="Cape",type="Cape",detail="A cape. This item is defined but is not currently obtainable."},
  ["Charred Wood"]={title="Charred Wood",type="Rune Material",detail="Each log burned by a campfire or bonfire leaves five pieces."},
  ["Fish Bones"]={title="Fish Bones",type="Rune Material",detail="Filleting one fish with a normal knife leaves exactly 3 Fish Bones on the ground."},
  ["Stone Gravel"]={title="Stone Gravel",type="Rune Material",detail="Mining produces exactly 4 pieces on safe ground away from the ore node."},
  ["Carved Feather"]={title="Carved Feather",type="Rune Material",detail="Use a Copper Knife or Copper Dagger on a Feather. Carving grants 4 base Religion XP."},
  ["Rough Onyx"]={title="Rough Onyx",type="Rough Jewel",detail="Rare raw onyx. Use a Chisel and Copper Hammer to cut it into Cut Onyx."},
  ["Carved Onyx"]={title="Carved Onyx",type="Rune Material",detail="One Cut Onyx is carved into exactly 3 Carved Onyx. Bless these for Void magic and Inscription."},
  ["Green Slime Tube"]={title="Green Slime Tube",type="Rune Material",detail="Use an Empty Tube on a Green Slime Jar. Each jar fills exactly 5 tubes."},
  ["Rune Bag"]={title="Rune Bag",type="Ammo",detail="Stores up to 50 of each blessed rune material, preserving its quality. Rune Bag first, highest grade first. D/C/B/A spell strength: 80/100/120/140%."},
  ["Leather Helm"]={title="Leather Helm",type="Head Armor",detail="A stitched leather helmet."},
  ["Spellbook"]={title="Spellbook",type="Offhand",detail="Equip this offhand to display the spells currently installed in your Spellbook."},
  ["Inscription Pen and Ink"]={title="Inscription Pen and Ink",type="Tool",detail="Required at the Inscription Table to write spell and skill pages."},
  ["Water Spell Page"]={title="Water Spell Page",type="Spell Page",detail="A physical Water spell page created with Inscription from blessed Fish Bones. Blessed material quality controls spell strength: D 80%, C 100%, B 120%, A 140%. Blessed material quality controls spell strength: D 80%, C 100%, B 120%, A 140%."},
  ["Earth Spell Page"]={title="Earth Spell Page",type="Spell Page",detail="A physical Earth spell page created with Inscription from blessed Stone Gravel. Blessed material quality controls spell strength: D 80%, C 100%, B 120%, A 140%. Blessed material quality controls spell strength: D 80%, C 100%, B 120%, A 140%."},
  ["Fire Spell Page"]={title="Fire Spell Page",type="Spell Page",detail="A physical Fire spell page created with Inscription from blessed Charred Wood. Blessed material quality controls spell strength: D 80%, C 100%, B 120%, A 140%. Blessed material quality controls spell strength: D 80%, C 100%, B 120%, A 140%."},
  ["Air Spell Page"]={title="Air Spell Page",type="Spell Page",detail="A physical Air spell page created with Inscription from blessed Carved Feathers. Blessed material quality controls spell strength: D 80%, C 100%, B 120%, A 140%. Blessed material quality controls spell strength: D 80%, C 100%, B 120%, A 140%."},
  ["Void Spell Page"]={title="Void Spell Page",type="Spell Page",detail="A physical Void spell page created with Inscription from blessed Carved Onyx. Blessed material quality controls spell strength: D 80%, C 100%, B 120%, A 140%. Blessed material quality controls spell strength: D 80%, C 100%, B 120%, A 140%."},
  ["Empty Spell Page"]={title="Empty Spell Page",type="Spell Page",detail="A blank magical page for future inscription."},
  ["Healing Spell Page"]={title="Healing Spell Page",type="Spell Page",detail="A physical Healing spell page created with Inscription from blessed Green Slime Tubes. Blessed material quality controls spell strength: D 80%, C 100%, B 120%, A 140%. Blessed material quality controls spell strength: D 80%, C 100%, B 120%, A 140%."},
  ["Melee Skill Page"]={title="Melee Skill Page",type="Skill Page",detail="Enchant a cut gem at the Enchanting Altar to increase effective Melee Combat while the gem is socketed."},
  ["Ranged Skill Page"]={title="Ranged Skill Page",type="Skill Page",detail="Enchant a cut gem at the Enchanting Altar to increase effective Ranged while the gem is socketed."},
  ["Magic Skill Page"]={title="Magic Skill Page",type="Skill Page",detail="Enchant a cut gem at the Enchanting Altar to increase effective Magic while the gem is socketed."},
  ["Stamina Potion (3/3)"]={title="Stamina Potion",type="Potion",detail="3 uses remaining. Each drink restores 30 stamina and boosts stamina regeneration for 10 seconds."},
  ["Stamina Potion (2/3)"]={title="Stamina Potion",type="Potion",detail="2 uses remaining. Each drink restores 30 stamina and boosts stamina regeneration for 10 seconds."},
  ["Stamina Potion (1/3)"]={title="Stamina Potion",type="Potion",detail="1 use remaining. Drinking restores 30 stamina and boosts stamina regeneration for 10 seconds."},
  ["Egg"]={title="Egg",type="Food Material",detail="Fresh egg found around chickens."},
  ["Feather"]={title="Feather",type="Crafting Material",detail="Chicken feather for later recipes. Stacks to 100."},
  ["Raw Chicken"]={title="Raw Chicken",type="Raw Food",detail="Level 1 Cooking food from chickens."},
  ["Cooked Chicken"]={title="Cooked Chicken",type="Food",detail="Simple cooked chicken. Restores 20 health.",heal=3},
  ["Burnt Chicken"]={title="Burnt Chicken",type="Burnt Food",detail="Burnt chicken. Restores 1 health.",heal=1},
  ["Jerky A"]={title="Jerky [A]",type="Food",detail="Grade A jerky. Restores 40 health."},
  ["Jerky B"]={title="Jerky [B]",type="Food",detail="Grade B jerky. Restores 6 health."},
  ["Jerky C"]={title="Jerky [C]",type="Food",detail="Grade C jerky. Restores 4 health."},
  ["Jerky D"]={title="Jerky [D]",type="Food",detail="Grade D jerky. Restores 2 health."},
  ["Burnt Jerky"]={title="Burnt Jerky",type="Burnt Food",detail="Ruined jerky. Restores 1 health and sells for exactly 1 copper."},
  ["Copper Shield"]={title="Copper Shield",type="Offhand",detail="Tier 1 copper shield reinforced with leather and wood.",defence=4},
  ["Rawhide String"]={title="Rawhide String",type="Crafting Material",detail="Rawhide cord used for leatherworking."},
  ["Fishing Pole"]={title="Fishing Pole",type="Tool",detail="Used to fish from the north and south beaches.",damage=1,attackSpeed=1.6,accuracy=0},
  ["Large Fish"]={title="Large Fish",type="Raw Fish",detail="Use a Copper Dagger on it for 3 Raw Fish Fillets."},
  ["Small Fish"]={title="Small Fish",type="Raw Fish",detail="Use a Copper Dagger on it for 1 Raw Fish Fillet."},
  ["Eel"]={title="Eel",type="Raw Fish",detail="Use a Copper Dagger on it. Fillet yield improves with Cooking level."},
  ["Raw Fish Fillet"]={title="Raw Fish Fillet",type="Raw Food",detail="Cook this at a stove."},
  ["Cooked Fish Fillet A"]={title="Cooked Fish Fillet [A]",type="Food",detail="Grade A. Restores 10 health."},
  ["Cooked Fish Fillet B"]={title="Cooked Fish Fillet [B]",type="Food",detail="Grade B. Restores 40 health."},
  ["Cooked Fish Fillet C"]={title="Cooked Fish Fillet [C]",type="Food",detail="Grade C. Restores 6 health."},
  ["Cooked Fish Fillet D"]={title="Cooked Fish Fillet [D]",type="Food",detail="Grade D. Restores 4 health."},
  ["Burnt Fish Fillet"]={title="Burnt Fish Fillet",type="Burnt Food",detail="Burnt. Restores 1 health and sells for exactly 1 copper."},
  ["Large Meat"]={title="Large Meat",type="Raw Food",detail="Large raw meat obtained while skinning wolves."},
  ["Cooked Large Meat A"]={title="Cooked Large Meat [A]",type="Food",detail="Grade A. Restores 16 health."},
  ["Cooked Large Meat B"]={title="Cooked Large Meat [B]",type="Food",detail="Grade B. Restores 13 health."},
  ["Cooked Large Meat C"]={title="Cooked Large Meat [C]",type="Food",detail="Grade C. Restores 10 health."},
  ["Cooked Large Meat D"]={title="Cooked Large Meat [D]",type="Food",detail="Grade D. Restores 7 health."},
  ["Burnt Large Meat"]={title="Burnt Large Meat",type="Burnt Food",detail="Burnt. Restores 1 health and sells for exactly 1 copper."},
  ["Small Meat"]={title="Small Meat",type="Raw Food",detail="Small raw meat obtained while skinning rats."},
  ["Cooked Small Meat A"]={title="Cooked Small Meat [A]",type="Food",detail="Grade A. Restores 40 health."},
  ["Cooked Small Meat B"]={title="Cooked Small Meat [B]",type="Food",detail="Grade B. Restores 6 health."},
  ["Cooked Small Meat C"]={title="Cooked Small Meat [C]",type="Food",detail="Grade C. Restores 4 health."},
  ["Cooked Small Meat D"]={title="Cooked Small Meat [D]",type="Food",detail="Grade D. Restores 2 health."},
  ["Burnt Small Meat"]={title="Burnt Small Meat",type="Burnt Food",detail="Burnt. Restores 1 health and sells for exactly 1 copper."},
  ["Needle"]={title="Needle",type="Tool",detail="Used to sew robes and clothing."},
  ["Wizard Hat"]={title="Wizard Hat",type="Head Armor",detail="A simple cloth hat for a magic wielder.",defence=1},
  ["Wizard Robes"]={title="Wizard Robes",type="Body Armor",detail="Simple blue robes for a magic wielder.",defence=2},
  ["Dyed Blue Cloth Strip"]={title="Dyed Blue Cloth Strip",type="Crafting Material",detail="Blue cloth used for wizard clothing."},
  ["Blue Dye"]={title="Blue Dye",type="Dye",detail="Made by a Tailor at the Tailor Table. Use on a Cloth Strip to dye it blue."},
  ["Cloth Strip"]={title="Cloth Strip",type="Tailoring Material",detail="Spun from wool. Producing cloth trains Tailoring."},
  ["Shears"]={title="Shears",type="Tool",detail="Used to cut wool from sheep.",damage=1,attackSpeed=1.5,accuracy=0},
  ["Wool"]={title="Wool",type="Crafting Material",detail="Raw wool ready to be spun into thread."},
  ["Wool Thread"]={title="Wool Thread",type="Crafting Material",detail="Thread spun from wool."},
  ["Flax"]={title="Flax",type="Crafting Material",detail="Southern flax. Spin it into bow string."},
  ["Linen Cloth"]={title="Linen Cloth",type="Tailoring Material",detail="Cloth woven from wool thread for linen goods."},
  ["Linen Bag"]={title="Linen Bag",type="Bag",detail="A roomy linen bag with 14 base inventory slots."},
  ["Staff"]={title="Staff",type="Weapon",detail="A basic wooden staff. Magic combat will be added later.",damage=1,attackSpeed=1.2,accuracy=1},
  ["Empty Flask"]={title="Empty Flask",type="Alchemy Container",detail="A large empty potion flask."},
  ["Empty Tube"]={title="Empty Tube",type="Alchemy Container",detail="A small empty potion tube."},
  ["Large Blue Mushroom"]={title="Large Blue Mushroom",type="Alchemy Ingredient",detail="A large blue mushroom used in stronger potions."},
  ["Brown Mushroom"]={title="Brown Mushroom",type="Alchemy Ingredient",detail="A common mushroom used in alchemy."},
  ["Bush Root"]={title="Bush Root",type="Alchemy Ingredient",detail="A medicinal root."},
  ["Bush Greens"]={title="Bush Greens",type="Alchemy Ingredient",detail="Fresh greens gathered from wild bushes."},
  ["Purple Berries"]={title="Purple Berries",type="Alchemy Ingredient",detail="Purple berries used in antipoison mixtures."},
  ["Red Berries"]={title="Red Berries",type="Alchemy Ingredient",detail="Red berries used in healing mixtures."},
  ["Health Flask"]={title="Health Flask",type="Potion",detail="Restores 40 health."},
  ["Health Tube"]={title="Health Tube",type="Potion",detail="Restores 20 health."},
  ["Antipoison Flask"]={title="Antipoison Flask",type="Potion",detail="Cures poison and prevents poison for 3 seconds."},
  ["Antipoison Tube"]={title="Antipoison Tube",type="Potion",detail="Cures poison."},
  ["Copper Helm"]={title="Copper Helm",type="Head Armor",detail="Tier 1 copper head armor.",defence=2},
  ["Copper Armor"]={title="Copper Armor",type="Body Armor",detail="Tier 1 copper body armor.",defence=5},
  ["Leather Armor"]={title="Leather Armor",type="Body Armor",detail="Basic stitched leather body armor. Requires Leatherworking 5 to craft.",defence=3},
  ["Copper Longsword"]={title="Copper Longsword",type="Weapon",detail="A basic copper longsword.",damage=4,attackSpeed=.65,accuracy=8},
  ["Copper Dagger"]={title="Copper Dagger",type="Weapon",detail="A copper dagger.",damage=3,attackSpeed=.42,accuracy=10},
  ["Copper Knife"]={title="Copper Knife",type="Tool",detail="A simple utility knife. Performs the same skill and crafting tasks as a Copper Dagger, but has no combat stats."},
  ["Flint and Steel"]={title="Flint and Steel",type="Tool",detail="Lights campfires and an equipped Torch."},
  ["Torch"]={title="Torch",type="Offhand",detail="Equip in OFFHAND, then use Flint and Steel to light it."},
  ["Lit Torch"]={title="Lit Torch",type="Offhand",detail="A burning offhand torch. Unequipping it extinguishes it."},
  ["Copper Axe"]={title="Copper Axe",type="Tool",detail="Used for woodcutting.",damage=2,attackSpeed=1.05,accuracy=3},
  ["Copper Pickaxe"]={title="Copper Pickaxe",type="Tool",detail="Used for mining.",damage=2,attackSpeed=1.15,accuracy=2},
  ["Copper Hammer"]={title="Copper Hammer",type="Tool",detail="Used for forging at an anvil and with a Chisel for jewel cutting.",damage=1,attackSpeed=1.25,accuracy=1},
  ["Chisel"]={title="Chisel",type="Tool",detail="Use with a Copper Hammer to crack jewel-bearing rocks, then cut rough jewels. Cutting requires Jewel Crafting 10 Ruby, 20 Sapphire, 30 Emerald."},
  ["Ruby-bearing Rock"]={title="Ruby-bearing Rock",type="Jewel Stone",detail="A rare find while mining ordinary copper. Use a Chisel while carrying a Copper Hammer to extract a Rough Ruby."},
  ["Sapphire-bearing Rock"]={title="Sapphire-bearing Rock",type="Jewel Stone",detail="A very rare find while mining ordinary copper. Use a Chisel while carrying a Copper Hammer to extract a Rough Sapphire."},
  ["Emerald-bearing Rock"]={title="Emerald-bearing Rock",type="Jewel Stone",detail="An exceptionally rare find while mining ordinary copper. Use a Chisel while carrying a Copper Hammer to extract a Rough Emerald."},
  ["Rough Ruby"]={title="Rough Ruby",type="Jewel",detail="Extracted from a ruby-bearing rock. Cut with a Chisel + Copper Hammer at Jewel Crafting 10."},
  ["Rough Sapphire"]={title="Rough Sapphire",type="Jewel",detail="Extracted from a sapphire-bearing rock. Cut with a Chisel + Copper Hammer at Jewel Crafting 20."},
  ["Rough Emerald"]={title="Rough Emerald",type="Jewel",detail="Extracted from an emerald-bearing rock. Cut with a Chisel + Copper Hammer at Jewel Crafting 30."},
  ["Cut Ruby"]={title="Cut Ruby",type="Cut Jewel",detail="A finished ruby. Gems have no effect until enchanted; Jewel Crafting only extracts, cuts, and sockets them."},
  ["Cut Sapphire"]={title="Cut Sapphire",type="Cut Jewel",detail="A finished sapphire. Gems have no effect until enchanted; Jewel Crafting only extracts, cuts, and sockets them."},
  ["Cut Emerald"]={title="Cut Emerald",type="Cut Jewel",detail="A finished emerald. Gems have no effect until enchanted; Jewel Crafting only extracts, cuts, and sockets them."},
  ["Ruby Dust"]={title="Ruby Dust",type="Gem Dust",detail="Remains of a ruby destroyed during jewel work."},
  ["Sapphire Dust"]={title="Sapphire Dust",type="Gem Dust",detail="Remains of a sapphire destroyed during jewel work."},
  ["Emerald Dust"]={title="Emerald Dust",type="Gem Dust",detail="Remains of an emerald destroyed during jewel work."},
  ["Copper Tongs"]={title="Copper Tongs",type="Tool",detail="Used for smelting.",damage=1,attackSpeed=1.35,accuracy=0},
  ["Small Copper Chunk"]={title="Small Copper Chunk",type="Ore",detail="A small copper chunk. Smelts into 1 Copper Bar."},
  ["Large Copper Chunk"]={title="Large Copper Chunk",type="Ore",detail="A rare large copper chunk found at Mining 11+. Smelts into 2 Copper Bars."},
  ["Pine Logs"]={title="Pine Logs",type="Resource",detail="Logs cut from a pine tree."},
  ["Poplar Logs"]={title="Poplar Logs",type="Resource",detail="Logs cut from a poplar tree. Requires Woodcutting 30 to gather."},
  ["Oak Logs"]={title="Oak Logs",type="Resource",detail="Oak logs. Requires Woodcutting 15 to gather."},
  ["Large Raw Leather"]={title="Large Raw Leather",type="Skinned Hide",detail="A large boar hide. It occupies the whole tanning vat."},
  ["Large Soaked Leather"]={title="Large Soaked Leather",type="Material",detail="A soaked large hide ready for the drying rack."},
  ["Large Leather"]={title="Large Leather",type="Material",detail="Cured large leather from a boar."},
  ["Copper ore"]={title="Copper Ore",type="Resource",detail="Raw copper ore."},
  ["Logs"]={title="Legacy Logs",type="Resource",detail="Legacy wood; treated as pine by old saves."},
  ["Pine Wood Parts"]={title="Pine Wood Parts",type="Material",detail="Wooden parts made from pine."},
  ["Oak Wood Parts"]={title="Oak Wood Parts",type="Material",detail="Wooden parts made from oak."},
  ["Pine Staff"]={title="Pine Staff",type="Weapon",detail="A pine staff. Equipped: 0.5% chance per Magic level to save the rune material on a successful cast (maximum 50%). A rune is still required."},
  ["Oak Staff"]={title="Oak Staff",type="Weapon",detail="An oak staff."},
  ["Pine Arrow Shafts"]={title="Pine Arrow Shafts",type="Fletching Material",detail="Arrow shafts made from pine."},
  ["Oak Arrow Shafts"]={title="Oak Arrow Shafts",type="Fletching Material",detail="Arrow shafts made from oak."},
  ["Pine Unstrung Bow"]={title="Pine Unstrung Bow",type="Fletching Material",detail="An unstrung pine bow."},
  ["Oak Unstrung Bow"]={title="Oak Unstrung Bow",type="Fletching Material",detail="An unstrung oak bow."},
  ["Pine Bow"]={title="Pine Bow",type="Weapon",detail="A pine ranged weapon.",damage=3,attackSpeed=.9,accuracy=7},
  ["Oak Bow"]={title="Oak Bow",type="Weapon",detail="A stronger oak ranged weapon.",damage=4,attackSpeed=.9,accuracy=8},
  ["Copper Bar"]={title="Copper Bar",type="Material",detail="Smelted copper used for smithing."},
  ["Basic Wood Parts"]={title="Basic Wood Parts",type="Material",detail="Wooden parts used in tool and weapon handles."},
  ["Green Slime Jar"]={title="Green Slime Jar",type="Monster Drop",detail="A jar of green slime. Rarely dropped by slimes."},
  ["Raw Hide"]={title="Raw Hide",type="Skinned Hide",detail="A usable hide recovered by skinning an animal. Soak it in a tanning vat."},
  ["Torn Hide"]={title="Torn Hide",type="Skinned Hide",detail="A badly damaged hide. It cannot be processed and is only useful to sell."},
  ["Soaked Hide"]={title="Soaked Hide",type="Material",detail="A soaked hide ready for the hide stretcher."},
  ["Leather"]={title="Leather",type="Material",detail="Finished leather used for bags, armor and other recipes."},
  ["Bones"]={title="Bones",type="Monster Drop",detail="Animal bones. Sellable for now."},
  ["Hemp Fibers"]={title="Hemp Fibers",type="Resource",detail="Fibers harvested from wild hemp with a knife."},
  ["Bow String"]={title="Bow String",type="Fletching Material",detail="Spun from 3 Hemp Fibers at a spinning wheel."},
  ["Arrow Shafts"]={title="Arrow Shafts",type="Fletching Material",detail="Wooden arrow shafts cut from logs with a knife. Crafted in batches of 10 and stack up to 100."},
  ["Copper Arrowheads"]={title="Copper Arrowheads",type="Smithing Material",detail="Copper arrowheads forged at an anvil in batches of 10. Stack up to 100; use on Arrow Shafts."},
  ["Copper Arrows"]={title="Copper Arrows",type="Ammo",detail="Copper-tipped arrows for bows. Load them into an equipped Quiver. Loose stacks hold up to 100."},
  ["Quiver"]={title="Quiver",type="Ammo",detail="An arrow container for the AMMO slot. Holds any quantity of one arrow type at a time."},
  ["Unstrung Bow"]={title="Unstrung Bow",type="Fletching Material",detail="A shaped bow stave. Use a Bow String on it to finish the bow."},
  ["Bow"]={title="Bow",type="Weapon",detail="A basic ranged weapon.",damage=3,attackSpeed=.9,accuracy=7},
  ["Bronze bar"]={title="Bronze Bar",type="Material",detail="A smelted bronze bar."},
  ["Large Leather Bag"]={title="Large Leather Bag",type="Bag",detail="10 base inventory slots."},
  ["Large Leather Bag D"]={title="Large Leather Bag [D]",type="Bag",detail="Grade D. 10 base slots."},["Large Leather Bag C"]={title="Large Leather Bag [C]",type="Bag",detail="Grade C. 12 base slots."},["Large Leather Bag B"]={title="Large Leather Bag [B]",type="Bag",detail="Grade B. 14 base slots."},["Large Leather Bag A"]={title="Large Leather Bag [A]",type="Bag",detail="Grade A. 16 base slots."},
  ["Small Leather Bag"]={title="Small Leather Bag",type="Bag",detail="6 base inventory slots."},
  ["Small Leather Bag D"]={title="Small Leather Bag [D]",type="Bag",detail="Grade D. 6 base slots."},["Small Leather Bag C"]={title="Small Leather Bag [C]",type="Bag",detail="Grade C. 7 base slots."},["Small Leather Bag B"]={title="Small Leather Bag [B]",type="Bag",detail="Grade B. 8 base slots."},["Small Leather Bag A"]={title="Small Leather Bag [A]",type="Bag",detail="Grade A. 9 base slots."},
  ["Copper Coins"]={title="Copper Coins",type="Currency",detail="100 copper = 1 silver."},
  ["Silver Coins"]={title="Silver Coins",type="Currency",detail="100 silver = 1 gold."},
  ["Gold Coins"]={title="Gold Coins",type="Currency",detail="Stonegrove currency."}
 }
 s.itemInfo["Tin ore"]={title="Tin Ore",type="Resource",detail="Tin ore mined from a tin deposit."}
 for _,grade in ipairs({"A","B","C","D"}) do
  s.itemInfo["Cooked Jerky "..grade]=s.itemInfo["Jerky "..grade]
 end
 s.smelterImage=s.medievalImage;s.smelterQuad=q(64,32,16,16,s.medievalImage);s.anvilImage=s.medievalImage;s.anvilQuad=q(48,32,16,16,s.medievalImage);s.bankChestImage=love.graphics.newImage("assets/tableChest.png");s.leatherBagImage=love.graphics.newImage("assets/leatherBag.png");s.largeBagClosed=love.graphics.newImage("assets/leather_bagLarge_closed.png");s.largeBagOpen=love.graphics.newImage("assets/leather_bagLarge_open.png");s.smallBagClosed=love.graphics.newImage("assets/leather_bagSmall_small.png");s.smallBagClosedQuad=q(8,8,16,16,s.smallBagClosed);s.smallBagOpen=love.graphics.newImage("assets/leather_bagSmall_open.png");s.campfireBase=love.graphics.newImage("assets/campfire_base.png");s.campfireAnim=love.graphics.newImage("assets/campfire_anim.png");s.campfireQuads={q(0,0,16,16,s.campfireAnim),q(16,0,16,16,s.campfireAnim),q(0,16,16,16,s.campfireAnim),q(16,16,16,16,s.campfireAnim)}
 for _,grade in ipairs({""," A"," B"," C"," D"}) do
  s.itemQuads["Small Leather Bag"..grade]=s.smallBagClosedQuad
 end
 s.objectColors={poplar=objectColor("assets/treePoplar.png"),
  tree=objectColor("assets/basicTree.png"),copper=objectColor("assets/oreCopper.png"),gemRuby=objectColor("assets/gemRock_ruby.png"),gemSapphire=objectColor("assets/gemRock_emerald.png"),gemEmerald=objectColor("assets/gemRock_sapphire.png"),hemp=objectColor("assets/resource_hemp.png"),
  rat=objectColor("assets/monster_rat.png"),wolf=objectColor("assets/monster_wolf.png"),slime=objectColor("assets/monster_slime.png"),
  smelter=objectColor("assets/tableSmelting.png"),anvil=objectColor("assets/tableForging.png"),tanningVat=objectColor("assets/station_tanningVat.png"),
  hideStretcher=objectColor("assets/station_hideStretcher_done.png"),spinningWheel=objectColor("assets/station_spinningWheel.png"),
  alchemy=objectColor("assets/station_alchemyMortar.png"),stove=objectColor("assets/station_stove.png"),magicAltar=objectColor("assets/magic_altar.png")
 };require("game.expansion").load(s);require("game.cave_snake").load(s);require("game.whole_fish").load(s);require("game.fishing_tiers").load(s);require("game.food").apply(s)
 s.itemImages["Unstrung Fishing Rod"]=s.itemImages["Fishing Pole"]
 s.itemQuads["Unstrung Fishing Rod"]=s.fishingPoleQuads.rest
 s.itemInfo["Unstrung Fishing Rod"]={title="Unstrung Fishing Rod",type="Material",detail="Woodworking 1. Combine with Rawhide String at Woodworking to make a Fishing Pole."}
 require("game.iron_gear").load(s)
 s.onyxImage=love.graphics.newImage('assets/onyx_progression.png');s.onyxImage:setFilter('nearest','nearest')
 for name,frame in pairs({['Rough Onyx']=1,['Cut Onyx']=3,['Carved Onyx']=2}) do s.itemImages[name]=s.onyxImage;s.itemQuads[name]=love.graphics.newQuad((frame-1)*16,0,16,16,s.onyxImage:getDimensions()) end
 s.itemImages['Onyx Dust']=s.itemImages['Ruby Dust']
 s.itemInfo['Cut Onyx']={title='Cut Onyx',type='Cut Jewel',detail='Enchant and socket this gem, or sacrifice it with Chisel + Copper Hammer into 3 Carved Onyx. Carving destroys any enchantment on it.'}
 s.itemInfo['Onyx Dust']={title='Onyx Dust',type='Gem Dust',detail='Matching dust for enchanting Cut Onyx. Each dust adds +0.1; Onyx base 5, cap 10.'}
 s.socketImage=love.graphics.newImage('assets/socket_states.png');s.socketImage:setFilter('nearest','nearest');s.socketQuads={}
 for frame=1,2 do s.socketQuads[frame]=love.graphics.newQuad((frame-1)*16,0,16,16,s.socketImage:getDimensions()) end
 require('game.custom_content').applySprites(s)
 require('game.fieldcraft_content').load(s)
 require('game.naga_queen').load(s)
 require('game.metal_progression').load(s)
 require('game.tailoring_content').load(s)
 require('game.advanced_gear').load(s)
 require('game.dark_content').load(s)
for name,info in pairs(s.itemInfo)do if name:match('^Steel ')and(info.type=='Weapon'or info.type=='Tool'or info.type=='Offhand')then s.itemImages[name]=s.unfinishedMetalIcon;s.itemQuads[name]=nil end end
require('game.new_fishing_content').load(s);require('game.bag_system').load(s);require('game.quality').load(s);require('game.seafood_content').load(s);require('game.food').apply(s);require('game.bone_religion').load(s);require('game.high_tier_fish').load(s)
return s
end
return S
