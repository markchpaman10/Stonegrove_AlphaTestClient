-- Whole fish use the existing cooking grades, inventory and eating systems.
local W={levels={Tuna=30,Shark=60,Shrimp=6,Swordfish=40,['Small Fish']=1,['Large Fish']=7,Eel=10,['Crab Meat']=12,['Lobster Meat']=30,['Manta Ray']=20},xp={Tuna=100,Shark=180,Shrimp=18,Swordfish=120,['Small Fish']=40,['Large Fish']=60,Eel=80,['Crab Meat']=36,['Lobster Meat']=90,['Manta Ray']=60}}
local frames={['Large Fish']={1,2},['Small Fish']={3,4},Eel={5,6}}
function W.load(s)
 for raw,images in pairs(frames)do
  local cooked=love.graphics.newImage('assets/whole_fish_'..images[1]..'.png')
  local burnt=love.graphics.newImage('assets/whole_fish_'..images[2]..'.png')
  cooked:setFilter('nearest','nearest');burnt:setFilter('nearest','nearest')
  for _,grade in ipairs({'D','C','B','A'})do
   local name='Cooked '..raw..' '..grade
   s.itemImages[name]=cooked;s.itemInfo[name]={title='Cooked '..raw..' ['..grade..']',type='Food',detail='Whole fish. Grade '..grade..'.'}
  end
  local name='Burnt '..raw;s.itemImages[name]=burnt;s.itemInfo[name]={title=name,type='Burnt Food',detail='Burnt. Restores 1 health and sells for exactly 1 copper.'}
  local info=s.itemInfo[raw];if info then info.detail=(info.detail or '')..' Cook whole at Cooking '..W.levels[raw]..', or prepare fish fillets with a knife at Cooking 7.' end
 end
end
return W
