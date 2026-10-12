import math
BASE={f'{size} {material} Bag':i*2+(material=='Leather')for i,size in enumerate(('Small','Medium','Large'),1)for material in ('Linen','Leather')}
BONUS={'D':0,'C':1,'B':2,'A':3}
XP=[0];points=0
for level in range(1,99):
 points+=math.floor(level+300*2**(level/7));XP.append(math.floor(points/4))
def strength(saved):
 xp=saved.get('skills',{}).get('Strength',{}).get('xp',0)
 return max(i+1 for i,n in enumerate(XP)if n<=xp)
CONTAINERS={f'{wood} {kind}':base+index*3 for index,wood in enumerate(('Pine','Oak','Poplar')) for kind,base in (('Crate',5),('Barrel',7))}
def validate_container(obj):
 if obj.get('name') not in CONTAINERS:return
 if obj.get('qty',1)!=1 or obj.get('qualityGrade','D') not in BONUS:raise ValueError('Invalid container quantity or grade')
 capacity=CONTAINERS[obj['name']]+BONUS[obj.get('qualityGrade','D')]
 contents=obj.get('contents',{})
 if not isinstance(contents,dict):raise ValueError('Invalid container contents')
 for slot,it in contents.items():
  if type(slot)is not int or not 1<=slot<=capacity or not isinstance(it,dict):raise ValueError('Invalid container slot')
  name=it.get('name','')
  if name in {'Angled Timber','Horizontal Timber','Vertical Timber','Bush Leaves','Stump Pole','Cover Tent','Lean-to','Leather Drape Tent','Shrimp Pot','Crab Pot','Lobster Pot'}:raise ValueError('Camp deployment items must remain in main bags')
  if name in CONTAINERS or name in BASE or name=='Rune Bag' or name.endswith('Quiver'):raise ValueError('Containers cannot be nested')
  qty=it.get('qty',1)
  if type(qty)is not int or qty<1:raise ValueError('Invalid stored quantity')

def validate(saved):
 level=strength(saved)
 for index,bag in saved.get('bags',{}).items():
  if type(index)is not int or not 1<=index<=(4 if level==99 else 3):raise ValueError('Bag equipment slot locked')
  name=bag.get('name');grade=bag.get('qualityGrade')
  if name not in BASE or grade not in BONUS:raise ValueError('Invalid bag or grade')
  capacity=BASE[name]+BONUS[grade]+level//10
  if bag.get('size')!=capacity:raise ValueError('Invalid bag capacity')
  for slot,obj in bag.get('slots',{}).items():
   if type(slot)is not int or not 1<=slot<=capacity or not isinstance(obj,dict):raise ValueError('Invalid inventory slot')
   validate_container(obj)
   if obj.get('name')in BASE and obj.get('qualityGrade')not in BONUS:raise ValueError('Invalid bag item grade')
 for obj in saved.get('bank',{}).values():
  if obj:validate_container(obj)
  if obj and obj.get('name')in BASE and obj.get('qualityGrade')not in BONUS:raise ValueError('Invalid bank bag grade')
 return True
def bag_signatures(saved):
 result=[]
 def record(obj):
  name=obj.get('name','');grade=obj.get('qualityGrade')or(name[-1]if len(name)>2 and name[-2]==' 'and name[-1]in BONUS else 'D')
  if name[-2:-1]==' 'and name[-1:]in BONUS:name=name[:-2]
  if name=='Linen Bag':name='Large Linen Bag'
  if name in BASE:result.extend([(name,grade)]*int(obj.get('qty',1)))
 for bag in saved.get('bags',{}).values():
  record(dict(bag,qty=1))
  for obj in bag.get('slots',{}).values():
   if obj:record(obj)
 for obj in saved.get('bank',{}).values():
  if obj:validate_container(obj)
  if obj:record(obj)
 return sorted(result)

def migrate(saved):
 if saved.get('bagSchemaVersion')==2:return saved
 level=strength(saved);overflow=[]
 def item(obj):
  name=obj.get('name','');grade=obj.get('qualityGrade')or(name[-1]if name[-2:-1]==' 'and name[-1:]in BONUS else 'D')
  if name[-2:-1]==' 'and name[-1:]in BONUS:name=name[:-2]
  if name=='Linen Bag':name='Large Linen Bag'
  if name in BASE:obj['name']=name;obj['qualityGrade']=grade
  return obj
 for index,bag in list(saved.get('bags',{}).items()):
  item(bag);name=bag['name'];grade=bag['qualityGrade'];cap=BASE[name]+BONUS[grade]+level//10
  bag['baseSize']=BASE[name];bag['size']=cap
  for slot,obj in list(bag.get('slots',{}).items()):
   if obj:item(obj)
   if slot>cap or index>(4 if level==99 else 3):
    if obj:overflow.append(obj)
    del bag['slots'][slot]
  if index>(4 if level==99 else 3):overflow.append({'name':name,'qty':1,'qualityGrade':grade});del saved['bags'][index]
 bank=saved.setdefault('bank',{})
 for obj in bank.values():
  if obj:item(obj)
 for obj in overflow:
  slot=1
  while bank.get(slot):slot+=1
  bank[slot]=obj;saved['bankSize']=max(saved.get('bankSize',25),slot)
 saved['bagSchemaVersion']=2
 return saved
