local utf8=require('utf8')
local N={limit=24}
function N.normalize(value)
 if type(value)~='string' or value:find('[%c]') then return nil end
 value=value:match('^%s*(.-)%s*$');local length=utf8.len(value)
 if not length or length<1 or length>N.limit then return nil end
 return value
end
function N.append(value,text)
 if type(text)~='string' then return value end
 text=text:gsub('[%c]','');if not utf8.len(text) then return value end
 local combined=value..text;local cut=utf8.offset(combined,N.limit+1)
 return cut and combined:sub(1,cut-1) or combined
end
function N.backspace(value)
 local i=utf8.offset(value,-1);return i and value:sub(1,i-1) or ''
end
return N
