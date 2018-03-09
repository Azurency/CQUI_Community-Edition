------------------------------------------------------------------------------
-- Misc Support Functions
------------------------------------------------------------------------------

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local m_strEllipsis = Locale.Lookup("LOC_GENERIC_DOT_DOT_DOT");


-- ===========================================================================
--	Sets a Label or control that contains a label (e.g., GridButton) with
--	a string that, if necessary, will be truncated.
--
--	RETURNS: true if truncated.
-- ===========================================================================
function TruncateString(control, resultSize, longStr, trailingText)

  local textControl = control;

  -- Ensure this has the actual text control
  if control.GetTextControl ~= nil then
    textControl = control:GetTextControl();
    UI.AssertMsg(textControl.SetTruncateWidth ~= nil, "Calling TruncateString with an unsupported control");
  end

  
  -- TODO if trailingText is ever used, add a way to do it to TextControl
  UI.AssertMsg(trailingText == nil or trailingText == "", "trailingText is not supported");
  
  if(longStr == nil) then
    longStr = control:GetText();
  end

  --TODO a better solution than this function would be ideal
    --calling SetText implicitly truncates if the flag is set
    --a AutoToolTip flag could be made to avoid setting the tooltip from lua
    --trailingText could be added, right now its just an ellipsis but it could be arbitrary
    --this would avoid the weird type shenanigans when truncating TextButtons, TextControls, etc
  
  if textControl ~= nil then
    textControl:SetTruncateWidth(resultSize);

    if control.SetText ~= nil then
      control:SetText(longStr);
    else
      textControl:SetText(longStr);
    end
  else
    UI.AssertMsg(false, "Attempting to truncate a NIL control");
  end
  
  if textControl.IsTextTruncated ~= nil then
    return textControl:IsTextTruncated();
  else
    UI.AssertMsg(false, "Calling IsTextTruncated with an unsupported control");
    return true;
  end
end


-- ===========================================================================
--	Same as TruncateString(), but if truncation occurs automatically adds
--	the full text as a tooltip.
-- ===========================================================================
function TruncateStringWithTooltip(control, resultSize, longStr, trailingText)
  local isTruncated = TruncateString( control, resultSize, longStr, trailingText );
  if isTruncated then
    control:SetToolTipString( longStr );
  else
    control:SetToolTipString( nil );
  end
  return isTruncated;
end

-- ===========================================================================
--	Same as TruncateStringWithTooltip(), but removes leading white space
--	before truncation
-- ===========================================================================
function TruncateStringWithTooltipClean(control, resultSize, longStr, trailingText)
  local cleanString = longStr:match("^%s*(.-)%s*$");
  local isTruncated = TruncateString( control, resultSize, longStr, trailingText );
  if isTruncated then
    control:SetToolTipString( cleanString );
  else
    control:SetToolTipString( nil );
  end
  return isTruncated;
end


-- ===========================================================================
--	Performs a truncation based on the control's contents
-- ===========================================================================
function TruncateSelfWithTooltip( control )
  local resultSize = control:GetSizeX();
  local longStr	 = control:GetText();
  return TruncateStringWithTooltip(control, resultSize, longStr);
end


-- ===========================================================================
--	Truncate string based on # of characters
--	(Most useful when having to truncate a string *in* a tooltip.
-- ===========================================================================
function TruncateStringByLength( textString, textLen )
  if ( Locale.Length(textString) > textLen ) then
    return Locale.SubString(textString, 1, textLen) .. m_strEllipsis;
  end
  return textString;
end

function GetGreatWorksForCity(pCity:table)
  local result:table = {};
  if pCity then
    local pCityBldgs:table = pCity:GetBuildings();
    for buildingInfo in GameInfo.Buildings() do
      local buildingIndex:number = buildingInfo.Index;
      local buildingType:string = buildingInfo.BuildingType;
      if(pCityBldgs:HasBuilding(buildingIndex)) then
        local numSlots:number = pCityBldgs:GetNumGreatWorkSlots(buildingIndex);
        if (numSlots ~= nil and numSlots > 0) then
          local greatWorksInBuilding:table = {};

          -- populate great works
          for index:number=0, numSlots - 1 do
            local greatWorkIndex:number = pCityBldgs:GetGreatWorkInSlot(buildingIndex, index);
            if greatWorkIndex ~= -1 then
              local greatWorkType:number = pCityBldgs:GetGreatWorkTypeFromIndex(greatWorkIndex);
              table.insert(greatWorksInBuilding, GameInfo.GreatWorks[greatWorkType]);
            end
          end

          -- create association between building type and great works
          if #greatWorksInBuilding > 0 then
            result[buildingType] = greatWorksInBuilding;
          end
        end
      end
    end
  end
  return result;
end

-- Wraps a string according to the provided length, but, unlike the built in wrapping, will ignore the limit if a single continuous word exceeds the length of the wrap width
function CQUI_SmartWrap( textString, wrapWidth )
  local lines = {""}; --Table that holds each individual line as it's build
  function append(w) --Appends a new word to the end of the currently processed line along with proper spacing
    if(lines[#lines] ~= "") then
      w = lines[#lines] .. " " .. w;
    end
    return w;
  end

  for i, word in ipairs(Split(textString, " ")) do --Takes each word and builds it into lines that respect the wrapWidth param, except for long individual words
    if(i ~= 1 and string.len(append(word)) > wrapWidth) then
      lines[#lines] = lines[#lines] .. "[NEWLINE]";
      lines[#lines + 1] = "";
    end
    lines[#lines] = append(word);
  end

  local out = ""; --The output variable
  for _,line in ipairs(lines) do --Flattens the table back into a single string
    out = out .. line;
  end
  return out;
end


-- ===========================================================================
-- Convert a set of values (red, green, blue, alpha) into a single hex value.
-- Values are from 0.0 to 1.0
-- return math.floor(value is a single, unsigned uint as ABGR
-- ===========================================================================
function RGBAValuesToABGRHex( red, green, blue, alpha )

  -- optionally pass in alpha, to taste
  if alpha==nil then
    alpha = 1.0;
  end

  -- prepare ingredients so they are clamped from 0 to 255
  red 	= math.max( 0, math.min( 255, red*255 ));
  green 	= math.max( 0, math.min( 255, green*255 ));
  blue	= math.max( 0, math.min( 255, blue*255 ));
  alpha	= math.max( 0, math.min( 255, alpha*255 ));

  -- combine the ingredients, stiring gently
  local value = lshift( alpha, 24 ) + lshift( blue, 16 ) + lshift( green, 8 ) + red;

  -- return the baked goodness
  return math.floor(value);
end

-- ===========================================================================
--	Use to convert from CivBE style colors to ForgeUI color
-- ===========================================================================
function RGBAObjectToABGRHex( colorObject )
  return RGBAValuesToABGRHex( colorObject.x, colorObject.y, colorObject.z, colorObject.w );
end

-- ===========================================================================
--	Guess what, TextControls still use legacy color; use to convert to it.
--	RETURNS: Object with R G B A to a vector like format with fields X Y Z W
-- ===========================================================================
function ABGRHExToRGBAObject( hexColor )
  local ret = {};
  ret.w = math.floor( math.fmod( rshift(hexColor,24), 256));
  ret.z = math.floor( math.fmod( rshift(hexColor,16), 256));
  ret.y = math.floor( math.fmod( rshift(hexColor,8), 256));
  ret.x = math.floor( math.fmod( hexColor, 0x256 ));	-- lower MODs are messed up due what is in higher bits, need an AND!
  return ret;
end



-- ===========================================================================
-- Support for shifts
-- ===========================================================================
local g_supportFunctions_shiftTable = {};
g_supportFunctions_shiftTable[0] = 1;
g_supportFunctions_shiftTable[1] = 2;
g_supportFunctions_shiftTable[2] = 4;
g_supportFunctions_shiftTable[3] = 8;
g_supportFunctions_shiftTable[4] = 16;
g_supportFunctions_shiftTable[5] = 32;
g_supportFunctions_shiftTable[6] = 64;
g_supportFunctions_shiftTable[7] = 128;
g_supportFunctions_shiftTable[8] = 256;
g_supportFunctions_shiftTable[9] = 512;
g_supportFunctions_shiftTable[10] = 1024;
g_supportFunctions_shiftTable[11] = 2048;
g_supportFunctions_shiftTable[12] = 4096;
g_supportFunctions_shiftTable[13] = 8192;
g_supportFunctions_shiftTable[14] = 16384;
g_supportFunctions_shiftTable[15] = 32768;
g_supportFunctions_shiftTable[16] = 65536;
g_supportFunctions_shiftTable[17] = 131072;
g_supportFunctions_shiftTable[18] = 262144;
g_supportFunctions_shiftTable[19] = 524288;
g_supportFunctions_shiftTable[20] = 1048576;
g_supportFunctions_shiftTable[21] = 2097152;
g_supportFunctions_shiftTable[22] = 4194304;
g_supportFunctions_shiftTable[23] = 8388608;
g_supportFunctions_shiftTable[24] = 16777216;



-- ===========================================================================
--	Bit Helper function
--	Converts a number into a table of bits.
-- ===========================================================================
function numberToBitsTable( value:number )
  if value < 0 then
    return numberToBitsTable( bitNot(math.abs(value))+1 );	-- Recurse
  end

  local kReturn	:table = {};
  local i			:number = 1;
  while value > 0 do
    local digit:number = math.fmod(value, 2);
    if digit == 1 then
      kReturn[i] = 1;
    else
      kReturn[i] = 0;
    end
    value = (value - digit) * 0.5;
    i = i + 1;
  end

  return kReturn;
end

-- ===========================================================================
--	Bit Helper function
--	Converts a table of bits into it's corresponding number.
-- ===========================================================================
function bitsTableToNumber( kTable:table )
  local bits	:number = table.count(kTable);
  local n		:number = 0;
  local power :number = 1;
  for i = 1, bits,1 do
    n = n + kTable[i] * power;
    power = power * 2;
  end
  return n;
end

-- ===========================================================================
--	Bitwise not (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
function bitNot( value:number )
  local kBits:table	= numberToBitsTable(value);
  local size:number	= math.max(table.getn(kBits), 32)
  for i = 1, size do
    if(kBits[i] == 1) then
      kBits[i] = 0
    else
      kBits[i] = 1
    end
  end
  return bitsTableToNumber(kBits);
 end

 -- ===========================================================================
--	Bitwise or (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
 local function bitOr( na:number, nb:number)
  local ka :table = numberToBitsTable(na);
  local kb :table = numberToBitsTable(nb);

  -- Make sure both are the same size; pad with 0's if necessary.
  while table.count(ka) < table.count(kb) do ka[table.count(ka)+1] = 0; end
  while table.count(kb) < table.count(ka) do kb[table.count(kb)+1] = 0; end

  local kResult	:table	= {};
  local digits	:number = table.count(ka);
  for i:number = 1, digits, 1 do
    kResult[i] = (ka[i]==1 or kb[i]==1) and 1 or 0;
  end
  return bitsTableToNumber( kResult );
end


-- ===========================================================================
-- Left shift (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
function lshift( value, shift )
  return math.floor(value) * g_supportFunctions_shiftTable[shift];
end

-- ===========================================================================
-- Right shift (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
function rshift( value:number, shift:number )
  local highBit:number = 0;

  if value < 0 then
    value	= bitNot(math.abs(value)) + 1;
    highBit = 0x80000000;
  end

  for i=1, shift, 1 do
    value = bitOr( math.floor(value*0.5), highBit );
  end
  return math.floor(value);
end


-- ===========================================================================
--	Determine if string is IP4, IP6, or invalid
--
--	Based off of:
--	http://stackoverflow.com/questions/10975935/lua-function-check-if-ipv4-or-ipv6-or-string
--
--	Returns: 4 if IP4, 6 if IP6, or 0 if not valid
-- ===========================================================================
function GetIPType( ip )

    if ip == nil or type(ip) ~= "string" then
        return 0;
    end

    -- Check for IPv4 format, 4 chunks between 0 and 255 (e.g., 1.11.111.111)
    local chunks = {ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")}
    if (table.count(chunks) == 4) then
        for _,v in pairs(chunks) do
            if (tonumber(v) < 0 or tonumber(v) > 255) then
                return 0;
            end
        end
        return 4;	-- This is IP4
    end

  -- Check for ipv6 format, should be 8 'chunks' of numbers/letters without trailing chars
  local chunks = {ip:match(("([a-fA-F0-9]*):"):rep(8):gsub(":$","$"))}
  if table.count(chunks) == 8 then
    for _,v in pairs(chunks) do
      if table.count(v) > 0 and tonumber(v, 16) > 65535 then
        return 0;
      end
    end
    return 6;	-- This is IP6
  end
  return 0;
end




-- ===========================================================================
--	LUA Helper function
-- ===========================================================================
function RemoveTableEntry( T:table, key:string, theValue )
  local pos = nil;
  for i,v in ipairs(T) do
    if (v[key]==theValue) then
      pos=i;
      break;
    end
  end
  if(pos ~= nil) then
    table.remove(T, pos);
    return true;
  end
  return false;
end

-- ===========================================================================
--	orderedPairs()
--	Allows an ordered iteratation of the pairs in a table.  Use like pairs().
--	Original version from: http://lua-users.org/wiki/SortedIteration
-- ===========================================================================
function __genOrderedIndex( t )
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex )
    return orderedIndex
end
function orderedNext(t, state)
    -- Equivalent of the next function, but returns the keys in the alphabetic order.
  -- Using a temporary ordered key table that is stored in the table being iterated.
    key = nil;
    if state == nil then
        -- Is first time; generate the index.
        t.__orderedIndex = __genOrderedIndex( t );
        key = t.__orderedIndex[1];
    else
        -- Fetch next value.
        for i = 1,table.count(t.__orderedIndex) do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1];
            end
        end
    end

    if key then
        return key, t[key];
  else
    t.__orderedIndex = nil;		-- No more value to return, cleanup.
    end
end
function orderedPairs(t)
    return orderedNext, t, nil;
end


-- ===========================================================================
--	Split()
--	Allows splitting a string (tokenizing) into an array based on a delimeter.
--	Original version from: http://lua-users.org/wiki/SplitJoin
--	RETURNS: Table of tokenized strings
-- ===========================================================================
function Split(str:string, delim:string, maxNb:number)
  -- Eliminate bad cases...
    if string.find(str, delim) == nil then
        return { str };
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0;    -- No limit
    end
    local result:table = {};
    local pat	:string = "(.-)" .. delim .. "()";
    local nb	:number = 0;
    local lastPos:number;
    for part, pos in string.gmatch(str, pat) do
        nb = nb + 1;
        result[nb] = part;
        lastPos = pos;
        if nb == maxNb then
      break;
    end
    end
    -- Handle the last field
    if nb ~= maxNb then
        result[nb + 1] = string.sub(str, lastPos);
    end
    return result;
end


-- ===========================================================================
--	Clamp()
--	Returns the value passed, only changing if it's above or below the min/max
-- ===========================================================================
function Clamp( value:number, min:number, max:number )
  if value < min then
    return min;
  elseif value > max then
    return max;
  else
    return value;
  end
end



-- ===========================================================================
--	Round()
--	Rounds a number to X decimal places.
--	Original version from: http://lua-users.org/wiki/SimpleRound
-- ===========================================================================
function Round(num:number, idp:number)
  local mult:number = 10^(idp or 0);
  return math.floor(num * mult + 0.5) / mult;
end


-- ===========================================================================
--	Convert polar coordiantes to Cartesian plane.
--	ARGS: 	r		radius
--			phi		angle in degrees (90 is facing down, 0 is pointing right)
--			ratio	y-axis to x-axis to "squash" the circle if desired
--
--	Unwrapped Circle:	local x = r * math.cos( math.rad(phi) );
--						local y = r * math.sin( math.rad(phi) );
--						return x,y;
-- ===========================================================================
function PolarToCartesian( r:number, phi:number )
  return r * math.cos( math.rad(phi) ), r * math.sin( math.rad(phi) );
end
function PolarToRatioCartesian( r:number, phi:number, ratio:number )
  return r * math.cos( math.rad(phi) ), r * math.sin( math.rad(phi) ) * ratio;
end

-- ===========================================================================
--	Transforms a ABGR color by some amount
--	ARGS:	hexColor	Hex color value (0xAAGGBBRR)
--			amt			(0-255) the amount to darken or lighten the color
--			alpha		???
--RETURNS:	transformed color (0xAAGGBBRR)
-- ===========================================================================
function DarkenLightenColor( hexColor:number, amt:number, alpha:number )

  --Parse the a,g,b,r hex values from the string
  local hexString :string = string.format("%x",hexColor);
  local b = string.sub(hexString,3,4);
  local g = string.sub(hexString,5,6);
  local r = string.sub(hexString,7,8);
  b = tonumber(b,16);
  g = tonumber(g,16);
  r = tonumber(r,16);

  if (b == nil) then b = 0; end
  if (g == nil) then g = 0; end
  if (r == nil) then r = 0; end

  local a = string.format("%x",alpha);
  if (string.len(a)==1) then
      a = "0"..a;
  end

  b = b + amt;
  if (b < 0 or b == 0) then
    b = "00";
  elseif (b > 255 or b == 255) then
    b = "FF";
  else
    b = string.format("%x",b);
    if (string.len(b)==1) then
      b = "0"..b;
    end
  end

  g = g + amt;
  if (g < 0 or g == 0) then
    g = "00";
  elseif (g > 255 or g == 255) then
    g = "FF";
  else
    g = string.format("%x",g);
    if (string.len(g)==1) then
      g = "0"..g;
    end
  end

  r = r + amt;
  if (r < 0 or r == 0) then
    r = "00";
  elseif (r > 255 or r == 255) then
    r = "FF";
  else
    r = string.format("%x",r);
    if (string.len(r)==1) then
      r = "0"..r;
    end
  end

  hexString = a..b..g..r;
  return tonumber(hexString,16);
end


-- ===========================================================================
--	Recursively duplicate (deep copy)
--	Original from: http://lua-users.org/wiki/CopyTable
-- ===========================================================================
function DeepCopy( orig )
    local orig_type = type(orig);
    local copy;
    if orig_type == 'table' then
        copy = {};
        for orig_key, orig_value in next, orig, nil do
            copy[DeepCopy(orig_key)] = DeepCopy(orig_value);
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)));
    else -- number, string, boolean, etc
        copy = orig;
    end
    return copy;
end

-- ===========================================================================
--	Sizes a control to fit a maximum height, while maintaining the aspect ratio
--	of the original control. If no Y is specified, we will use the height of the screen.
--	ARG 1: control (table) - expects a control to be resized
--	ARG 5: OPTIONAL maxY (number) - the minimum height of the control.
-- ===========================================================================
function UniformToFillY( control:table, maxY:number )
  local currentX = control:GetSizeX();
  local currentY = control:GetSizeY();
  local newX = 0;
  local newY = 0;
  if (maxY == nil) then
    local _, screenY:number = UIManager:GetScreenSizeVal();
    newY = screenY;
  else
    newY = maxY;
  end
  newX = (currentX * newY)/currentY;
  control:SetSizeVal(newX,newY);
end







--[[ DataDumper.lua
Copyright (c) 2007 Olivetti-Engineering SA

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
]]

function dump(...)
  print(DataDumper(...), "\n---")
end

local dumplua_closure = [[
local closures = {}
local function closure(t)
  closures[#closures+1] = t
  t[1] = assert(loadstring(t[1]))
  return t[1]
end

for _,t in pairs(closures) do
  for i = 2,#t do
    debug.setupvalue(t[1], i-1, t[i])
  end
end
]]

local lua_reserved_keywords = {
  'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for',
  'function', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat',
  'return', 'then', 'true', 'until', 'while' }

local function keys(t)
  local res = {}
  local oktypes = { stringstring = true, numbernumber = true }
  local function cmpfct(a,b)
    if oktypes[type(a)..type(b)] then
      return a < b
    else
      return type(a) < type(b)
    end
  end
  for k in pairs(t) do
    res[#res+1] = k
  end
  table.sort(res, cmpfct)
  return res
end

local c_functions = {}
for _,lib in pairs{'_G', 'string', 'table', 'math',
    'io', 'os', 'coroutine', 'package', 'debug'} do
  local t = {}
  lib = lib .. "."
  if lib == "_G." then lib = "" end
  for k,v in pairs(t) do
    if type(v) == 'function' and not pcall(string.dump, v) then
      c_functions[v] = lib..k
    end
  end
end

function DataDumper(value, varname, fastmode, ident)
  local defined, dumplua = {}
  -- Local variables for speed optimization
  local string_format, type, string_dump, string_rep =
        string.format, type, string.dump, string.rep
  local tostring, pairs, table_concat =
        tostring, pairs, table.concat
  local keycache, strvalcache, out, closure_cnt = {}, {}, {}, 0
  setmetatable(strvalcache, {__index = function(t,value)
    local res = string_format('%q', value)
    t[value] = res
    return res
  end})
  local fcts = {
    string = function(value) return strvalcache[value] end,
    number = function(value) return value end,
    boolean = function(value) return tostring(value) end,
    ['nil'] = function(value) return 'nil' end,
    ['function'] = function(value)
      return string_format("loadstring(%q)", string_dump(value))
    end,
    userdata = function() error("Cannot dump userdata") end,
    thread = function() error("Cannot dump threads") end,
  }
  local function test_defined(value, path)
    if defined[value] then
      if path:match("^getmetatable.*%)$") then
        out[#out+1] = string_format("s%s, %s)\n", path:sub(2,-2), defined[value])
      else
        out[#out+1] = path .. " = " .. defined[value] .. "\n"
      end
      return true
    end
    defined[value] = path
  end
  local function make_key(t, key)
    local s
    if type(key) == 'string' and key:match('^[_%a][_%w]*$') then
      s = key .. "="
    else
      s = "[" .. dumplua(key, 0) .. "]="
    end
    t[key] = s
    return s
  end
  for _,k in ipairs(lua_reserved_keywords) do
    keycache[k] = '["'..k..'"] = '
  end
  if fastmode then
    fcts.table = function (value)
      -- Table value
      local numidx = 1
      out[#out+1] = "{"
      for key,val in pairs(value) do
        if key == numidx then
          numidx = numidx + 1
        else
          out[#out+1] = keycache[key]
        end
        local str = dumplua(val)
        out[#out+1] = str..","
      end
      if string.sub(out[#out], -1) == "," then
        out[#out] = string.sub(out[#out], 1, -2);
      end
      out[#out+1] = "}"
      return ""
    end
  else
    fcts.table = function (value, ident, path)
      if test_defined(value, path) then return "nil" end
      -- Table value
      local sep, str, numidx, totallen = " ", {}, 1, 0
      local meta, metastr = getmetatable(value)
      if meta then
        ident = ident + 1
        metastr = dumplua(meta, ident, "getmetatable("..path..")")
        totallen = totallen + #metastr + 16
      end
      for _,key in pairs(keys(value)) do
        local val = value[key]
        local s = ""
        local subpath = path or ""
        if key == numidx then
          subpath = subpath .. "[" .. numidx .. "]"
          numidx = numidx + 1
        else
          s = keycache[key]
          if not s:match "^%[" then subpath = subpath .. "." end
          subpath = subpath .. s:gsub("%s*=%s*$","")
        end
        s = s .. dumplua(val, ident+1, subpath)
        str[#str+1] = s
        totallen = totallen + #s + 2
      end
      if totallen > 80 then
        sep = "\n" .. string_rep("  ", ident+1)
      end
      str = "{"..sep..table_concat(str, ","..sep).." "..sep:sub(1,-3).."}"
      if meta then
        sep = sep:sub(1,-3)
        return "setmetatable("..sep..str..","..sep..metastr..sep:sub(1,-3)..")"
      end
      return str
    end
    fcts['function'] = function (value, ident, path)
      if test_defined(value, path) then return "nil" end
      if c_functions[value] then
        return c_functions[value]
      elseif debug == nil or debug.getupvalue(value, 1) == nil then
        return string_format("loadstring(%q)", string_dump(value))
      end
      closure_cnt = closure_cnt + 1
      local res = {string.dump(value)}
      for i = 1,math.huge do
        local name, v = debug.getupvalue(value,i)
        if name == nil then break end
        res[i+1] = v
      end
      return "closure " .. dumplua(res, ident, "closures["..closure_cnt.."]")
    end
  end
  function dumplua(value, ident, path)
    return fcts[type(value)](value, ident, path)
  end
  if varname == nil then
    varname = ""
  elseif varname:match("^[%a_][%w_]*$") then
    varname = varname .. " = "
  end
  if fastmode then
    setmetatable(keycache, {__index = make_key })
    out[1] = varname
    table.insert(out,dumplua(value, 0))
    return table.concat(out)
  else
    setmetatable(keycache, {__index = make_key })
    local items = {}
    for i=1,10 do items[i] = '' end
    items[3] = dumplua(value, ident or 0, "t")
    if closure_cnt > 0 then
      items[1], items[6] = dumplua_closure:match("(.*\n)\n(.*)")
      out[#out+1] = ""
    end
    if #out > 0 then
      items[2], items[4] = "local t = ", "\n"
      items[5] = table.concat(out)
      items[7] = varname .. "t"
    else
      items[2] = varname
    end
    return table.concat(items)
  end
end
