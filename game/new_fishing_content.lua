local N={}
function N.load(s)
 local function frames(raw,path,cooked,burnt)
  local im=love.graphics.newImage('assets/'..path);im:setFilter('nearest','nearest');local w,h=im:getDimensions()
  local function icon(name,x,typ)s.itemImages[name]=im;s.itemQuads[name]=love.graphics.newQuad(x,0,16,16,w,h);s.itemInfo[name]={title=name,type=typ,detail='Fishing/Cooking '..(raw=='Shrimp'and 6 or 40)..'.'}end
  if raw=='Shrimp'then icon(raw,0,'Raw Food')end
  for _,grade in ipairs({'D','C','B','A'})do icon('Cooked '..raw..' '..grade,cooked,'Food')end;icon('Burnt '..raw,burnt,'Burnt Food')
 end
 frames('Shrimp','shrimpSheet.png',16,32);frames('Swordfish','swordfishCookedSheet.png',0,16)
 s.itemImages.Swordfish=love.graphics.newImage('assets/swordfishRaw.png');s.itemImages.Swordfish:setFilter('nearest','nearest');s.itemInfo.Swordfish={title='Swordfish',type='Raw Food',detail='Fishing 40 with a Pine Fishing Pole or better. Cooking 40 whole, or use a knife at Cooking 7 for 6-10 fillets, scaled by Cooking.'}
 s.itemInfo['Fishing Pole'].detail=(s.itemInfo['Fishing Pole'].detail or '')..' Fishing 40: chance to catch Swordfish.'
end
return N
