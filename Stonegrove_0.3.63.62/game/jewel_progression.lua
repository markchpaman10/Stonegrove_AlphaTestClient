local P={cuts={['Rough Onyx']={out='Cut Onyx',level=1,xp=12},['Rough Ruby']={out='Cut Ruby',level=10,xp=18},['Rough Sapphire']={out='Cut Sapphire',level=20,xp=30},['Rough Emerald']={out='Cut Emerald',level=30,xp=45}}}
P.unlocks={{1,'Extract jewels from jewel-bearing rocks with Chisel and Copper Hammer'},{1,'Cut Rough Onyx with Chisel and Copper Hammer'},{1,'Carve Cut Onyx into 3 Carved Onyx rune materials'},{1,'Create up to 2 permanent equipment socket positions'},{10,'Cut Rough Ruby: 18 base XP per success'},{20,'Cut Rough Sapphire: 30 base XP per success'},{20,'Create up to 3 equipment socket positions'},{30,'Cut Rough Emerald: 45 base XP per success'},{40,'Create up to 4 equipment socket positions'},{50,'Create up to 5 equipment socket positions'},{60,'Create up to 6 equipment socket positions'},{70,'Guaranteed jewel extraction'},{72,'Socket creation reaches its 98% success cap'},{76,'Rough gem cutting reaches its 98% success cap'}}
function P.socketLimit(level)if level>=60 then return 6 elseif level>=50 then return 5 elseif level>=40 then return 4 elseif level>=20 then return 3 else return 2 end end
function P.socketChance(level)return math.min(.98,.55+level*.006)end
function P.cutChance(level)return math.min(.98,.60+level*.005)end
function P.extractionChance(level)return level>=70 and 1 or math.min(.99,.55+level*.0065)end
return P
