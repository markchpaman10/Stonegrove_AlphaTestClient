local R={}
function R.draw(sprites,player,equipment,world)

  local H=require('game.humanoid');love.graphics.setColor(1,1,1)
  local function drawLayer(image,frames,dir,head)
   local key=dir=='left' and 'right' or dir;H.draw(image,frames[key][player.frame],player.x,player.y,dir=='left' and -1 or 1,player.race,head and 'head' or 'body')
  end
  local function shadowLayer(image,frames,dir,head)
   local key=dir=='left' and 'right' or dir;love.graphics.setColor(.035,.045,.05,.30);H.shadow(image,frames[key][player.frame],player.x,player.y,dir=='left' and -1 or 1,player.race,head and 'head' or 'body')
  end
  shadowLayer(sprites.bodyImage,sprites.player.body,player.bodyDir);shadowLayer(sprites.headImage,sprites.player.head,player.headDir,true);love.graphics.setColor(1,1,1)
  -- Up-facing held equipment belongs behind the paper doll.
  if player.headDir=="up" then
   local bgHeld=player.equipped;local bgImg=bgHeld and sprites.itemImages[bgHeld] or nil
   if world.fishing then bgHeld=world.fishing.tool or"Fishing Pole";bgImg=sprites.itemImages[bgHeld] elseif world.gather and world.gather.node then local def=world:getDef(world.gather.node.kind);bgHeld=def and def.tool or bgHeld;bgImg=bgHeld and sprites.itemImages[bgHeld] or bgImg elseif player.activity=="anvil" then bgHeld="Copper Hammer";bgImg=sprites.hammerImage elseif player.activity=="smelter" then bgHeld="Copper Tongs";bgImg=sprites.tongsImage end
   if equipment.offhand=="Copper Shield" or equipment.offhand=="Iron Shield" then local si=sprites.itemImages[equipment.offhand];local q=sprites.itemQuads[equipment.offhand];if q then love.graphics.draw(si,q,player.x-6,player.y+2,0,.7,.7,8,8) else love.graphics.draw(si,player.x-6,player.y+2,0,.7,.7,8,8) end end
   require('game.paperdoll').draw(sprites,equipment.offhand,player.x,player.y,player.headDir,player.frame,player.race)
   if bgImg and not require('game.paperdoll').draw(sprites,bgHeld,player.x,player.y,player.headDir,player.frame,player.race)then local swing=player.toolSwing>0 and math.sin((player.toolSwing/.24)*math.pi)*.75 or 0;if require("game.fishing_tiers").tools[bgHeld]then require("game.fishing_tiers").drawHeld(sprites,bgHeld,world.fishing,player.x+4,player.y-1,swing,.7,.7) else local bgQuad=bgHeld and sprites.itemQuads[bgHeld] or nil;if bgQuad then love.graphics.draw(bgImg,bgQuad,player.x+4,player.y-1,swing,.7,.7,8,8) else love.graphics.draw(bgImg,player.x+4,player.y-1,swing,.7,.7,8,8) end end end
  end
  local function drawCape()
  require('game.paperdoll').draw(sprites,equipment.cape,player.x,player.y,player.bodyDir,player.frame,player.race)
  if equipment.cape=="Cape" then drawLayer(sprites.capeImage,sprites.cape,player.bodyDir) end
  end
  if player.bodyDir~='up' then drawCape() end
  drawLayer(sprites.bodyImage,sprites.player.body,player.bodyDir);if equipment.body=="Copper Armor" then drawLayer(sprites.armorCopperImage,sprites.armorCopper.body,player.bodyDir)
 elseif equipment.body=="Leather Armor" then drawLayer(sprites.armorLeatherImage,sprites.armorLeather.body,player.bodyDir) elseif equipment.body=="Wizard Robes" then drawLayer(sprites.armorWizardImage,sprites.armorWizard.body,player.bodyDir) end;require("game.iron_gear").draw(sprites,equipment.body,player.x,player.y,player.bodyDir,player.frame,player.race);require("game.iron_gear").draw(sprites,equipment.legs,player.x,player.y,player.bodyDir,player.frame,player.race);require('game.paperdoll').draw(sprites,equipment.body,player.x,player.y,player.bodyDir,player.frame,player.race);require('game.paperdoll').draw(sprites,equipment.legs,player.x,player.y,player.bodyDir,player.frame,player.race);if player.bodyDir=='up' then drawCape() end;drawLayer(sprites.headImage,sprites.player.head,player.headDir,true);H.beard(sprites,player.race,player.x,player.y,player.headDir,player.frame)
  if equipment.head=="Copper Helm" then drawLayer(sprites.armorCopperImage,sprites.armorCopper.helm,player.headDir,true)
  elseif equipment.head=="Leather Helm" then drawLayer(sprites.armorLeatherImage,sprites.armorLeather.helm,player.headDir,true) elseif equipment.head=="Wizard Hat" then drawLayer(sprites.armorWizardImage,sprites.armorWizard.helm,player.headDir,true) end
  require("game.iron_gear").draw(sprites,equipment.head,player.x,player.y,player.headDir,player.frame,player.race)
  require('game.paperdoll').draw(sprites,equipment.head,player.x,player.y,player.headDir,player.frame,player.race)
  require('game.race_ears').draw(sprites,player.race,player.x,player.y,player.headDir,player.frame,equipment.head)
  local heldName=player.equipped;local heldImg=heldName and sprites.itemImages[heldName] or nil
  if world.fishing then heldName=world.fishing.tool or"Fishing Pole";heldImg=sprites.itemImages[heldName]
  elseif world.gather and world.gather.node then local def=world:getDef(world.gather.node.kind);heldName=def and def.tool or heldName;heldImg=heldName and sprites.itemImages[heldName] or heldImg
  elseif player.activity=="anvil" then heldName="Copper Hammer";heldImg=sprites.hammerImage
  elseif player.activity=="smelter" then heldName="Copper Tongs";heldImg=sprites.tongsImage end
  local offhand=equipment.offhand
  if player.headDir~='up'and offhand and offhand~='Iron Shield'and offhand~='Copper Shield'and offhand~='Torch'and offhand~='Lit Torch'then require('game.paperdoll').draw(sprites,offhand,player.x,player.y,player.headDir,player.frame,player.race)end
  if (offhand=="Copper Shield" or offhand=="Iron Shield") and player.headDir~="up" then local simg=sprites.itemImages[offhand];local quad=sprites.itemQuads[offhand];local dir=player.headDir;local side=(dir=="left" and 1 or -1);local sx=player.x+side*6;local sy=player.y+2;love.graphics.setColor(1,1,1);if quad then love.graphics.draw(simg,quad,sx,sy,0,.7,.7,8,8) else love.graphics.draw(simg,sx,sy,0,.7,.7,8,8) end end;if (offhand=="Torch" or offhand=="Lit Torch") then local timg=sprites.itemImages[offhand];local side=(player.headDir=="left" and 1 or -1);love.graphics.setColor(1,1,1);love.graphics.draw(timg,player.x+side*6,player.y+1,0,.8,.8,8,8) end
  if heldImg and player.headDir~="up"and not require('game.paperdoll').draw(sprites,heldName,player.x,player.y,player.headDir,player.frame,player.race)then
   local dir=player.headDir;local flip=dir=="left" and -1 or 1;local ox=dir=="left" and -5 or (dir=="right" and 5 or 4);local oy=(dir=="up" and -1 or 2)
   local swing=0;if world.fishing then swing=math.sin(love.timer.getTime()*3)*.12 elseif player.toolSwing>0 then local phase=player.toolSwing/.24;swing=(dir=="left" and -1 or 1)*math.sin(phase*math.pi)*.75 end
   love.graphics.setColor(1,1,1);local baseRot=0;if heldName=="Copper Axe" or (heldName=="Bow" or tostring(heldName):match(" Bow$")) then flip=-flip end;if require("game.fishing_tiers").tools[heldName]then require("game.fishing_tiers").drawHeld(sprites,heldName,world.fishing,player.x+ox,player.y+oy,baseRot+swing,flip*.7,.7) else local heldQuad=heldName and sprites.itemQuads[heldName] or nil;if heldQuad then love.graphics.draw(heldImg,heldQuad,player.x+ox,player.y+oy,baseRot+swing,flip*.7,.7,8,8) else love.graphics.draw(heldImg,player.x+ox,player.y+oy,baseRot+swing,flip*.7,.7,8,8) end end
  end 
end
return R
