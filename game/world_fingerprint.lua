local F={}
function F.of(value)
 local h,n=17,0
 local function append(s)for i=1,#s do h=(h*131+s:byte(i))%2147483647;n=n+1 end end
 local function visit(v)
  local t=type(v);append(t..':')
  if t=='table'then local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys,function(a,b)if type(a)~=type(b)then return type(a)<type(b)end;return a<b end);for _,k in ipairs(keys)do visit(k);visit(v[k])end;append('}')
  elseif t=='string'then append(#v..':'..v)
  elseif t=='number'then append(string.format('%.17g',v))
  else append(tostring(v))end
 end
 visit(value);return string.format('%08x-%d',h,n)
end
return F
