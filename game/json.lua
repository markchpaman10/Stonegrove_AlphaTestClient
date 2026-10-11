local J={}
local escapes={['"']='\\"',['\\']='\\\\',['\b']='\\b',['\f']='\\f',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
local keyQuotes={};local keyCount=0
local fragments=setmetatable({},{__mode="k"})
local function quote(v)
 if not v:find('[%z\1-\31\\"]')then return '"'..v..'"'end
 return '"'..v:gsub('[%z\1-\31\\"]',function(c)return escapes[c]or string.format('\\u%04x',c:byte())end)..'"'
end
local function quoteKey(k)
 local q=keyQuotes[k];if q then return q end;q=quote(k)
 if #k<=128 then if keyCount>=1024 then keyQuotes={};keyCount=0 end;keyQuotes[k]=q;keyCount=keyCount+1 end;return q
end
local function emit(v,seen,out)
 if type(v)=='table'and fragments[v]then out[#out+1]=fragments[v];return end
 local t=type(v)
 if t=='nil'then out[#out+1]='null'
 elseif t=='boolean'then out[#out+1]=tostring(v)
 elseif t=='number'then assert(v==v and math.abs(v)<math.huge,'Nonfinite number');out[#out+1]=tostring(v)
 elseif t=='string'then out[#out+1]=quote(v)
 else
  assert(t=='table','Invalid JSON value');assert(not seen[v],'Cycle');seen[v]=true
  local n=0;local array=true;for k in pairs(v)do if type(k)~='number'or k<1 or k%1~=0 then array=false end;n=n+1 end
  if array and(#v~=n or n==0)then array=false end
  out[#out+1]=array and'['or'{';local first=true
  if array then for i=1,n do if not first then out[#out+1]=','end;first=false;emit(v[i],seen,out)end
  else for k,x in pairs(v)do assert(type(k)=='string','JSON key');if not first then out[#out+1]=','end;first=false;out[#out+1]=quoteKey(k);out[#out+1]=':';emit(x,seen,out)end end
  out[#out+1]=array and']'or'}';seen[v]=nil
 end
end
function J.encode(v,seen)local out={};emit(v,seen or{},out);return table.concat(out)end
-- Cache only private immutable packed snapshots; decoded input never becomes a fragment.
function J.cache(v)if type(v)=='table'and not fragments[v]then fragments[v]=J.encode(v)end;return v end
function J.decode(s)
 local i,depth=1,0;local function ws()local _,e=s:find('^%s*',i);i=(e or i-1)+1 end
 local parse
 local function str()assert(s:sub(i,i)=='"','String');i=i+1;local a={};while i<=#s do local nextSpecial=s:find('[%z\1-\31\\"]',i);assert(nextSpecial,'Unclosed string');if nextSpecial>i then a[#a+1]=s:sub(i,nextSpecial-1)end;i=nextSpecial;local c=s:sub(i,i);i=i+1;if c=='"'then return #a==1 and a[1]or table.concat(a)elseif c=='\\'then local e=s:sub(i,i);i=i+1;local m={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'};if e=='u'then local h=s:sub(i,i+3);assert(h:match('^%x%x%x%x$'),'Unicode');local cp=tonumber(h,16);i=i+4;if cp>=0xD800 and cp<=0xDBFF then assert(s:sub(i,i+1)=='\\u','Surrogate');local low=tonumber(s:sub(i+2,i+5),16);assert(low and low>=0xDC00 and low<=0xDFFF,'Surrogate');cp=0x10000+(cp-0xD800)*1024+low-0xDC00;i=i+6 end;assert(not(cp>=0xD800 and cp<=0xDFFF),'Surrogate');a[#a+1]=require('utf8').char(cp)else assert(m[e],'Escape');a[#a+1]=m[e]end else assert(c:byte()>=32,'Control character');a[#a+1]=c end end;error('Unclosed string')end
 parse=function()ws();depth=depth+1;assert(depth<128,'JSON nesting');local c=s:sub(i,i);local v;if c=='"'then v=str()elseif c=='{'or c=='['then local object=c=='{';v={};i=i+1;ws();local closing=object and '}'or']';if s:sub(i,i)~=closing then repeat local key;if object then key=str();ws();assert(s:sub(i,i)==':','Colon');i=i+1 end;local value=parse();if object then assert(v[key]==nil,'Duplicate key');v[key]=value else v[#v+1]=value end;ws();if s:sub(i,i)~=','then break end;i=i+1;ws()until false end;assert(s:sub(i,i)==closing,'Closing bracket');i=i+1 elseif s:sub(i,i+3)=='true'then v=true;i=i+4 elseif s:sub(i,i+4)=='false'then v=false;i=i+5 elseif s:sub(i,i+3)=='null'then i=i+4 else local a,b=s:find('^-?%d+%.?%d*[eE]?[+-]?%d*',i);local token=a and s:sub(a,b);assert(token and tonumber(token),'Number');v=tonumber(token);assert(v==v and math.abs(v)<math.huge,'Number');i=i+#token end;depth=depth-1;return v end
 local v=parse();ws();assert(i>#s,'Trailing JSON');return v
end
return J
