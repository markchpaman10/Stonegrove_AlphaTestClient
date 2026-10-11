local M={}
local ok,ffi=pcall(require,'ffi')
if not ok or ffi.os~='Windows' then function M.protect()end;function M.unprotect()end;return M end
ffi.cdef[[typedef struct { unsigned long cbData; unsigned char *pbData; } SG_LOGIN_BLOB;
int __stdcall CryptProtectData(SG_LOGIN_BLOB*,const unsigned short*,SG_LOGIN_BLOB*,void*,void*,unsigned long,SG_LOGIN_BLOB*);
int __stdcall CryptUnprotectData(SG_LOGIN_BLOB*,void*,SG_LOGIN_BLOB*,void*,void*,unsigned long,SG_LOGIN_BLOB*);
void* __stdcall LocalFree(void*);]]
local crypt=ffi.load('crypt32');local kernel=ffi.load('kernel32')
local function transform(value,decrypt)
 if type(value)~='string' or #value==0 or #value>65536 then return nil end
 local buffer=ffi.new('unsigned char[?]',#value);ffi.copy(buffer,value,#value)
 local input=ffi.new('SG_LOGIN_BLOB[1]');input[0].cbData=#value;input[0].pbData=buffer
 local output=ffi.new('SG_LOGIN_BLOB[1]')
 local result=(decrypt and crypt.CryptUnprotectData or crypt.CryptProtectData)(input,nil,nil,nil,nil,1,output)
 if result==0 then return nil end
 local text=ffi.string(output[0].pbData,output[0].cbData);kernel.LocalFree(output[0].pbData);return text
end
function M.protect(password)
 local encrypted=transform(password,false);if not encrypted then return nil end
 return 'dpapi1:'..encrypted:gsub('.',function(c)return string.format('%02x',c:byte())end)
end
function M.unprotect(cipher)
 if type(cipher)~='string' or cipher:sub(1,7)~='dpapi1:' then return nil end
 local hex=cipher:sub(8);if #hex>131072 or #hex%2~=0 or hex:find('[^%da-f]')then return nil end
 return transform(hex:gsub('..',function(pair)return string.char(tonumber(pair,16))end),true)
end
return M
