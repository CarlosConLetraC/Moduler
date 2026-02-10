local Convert, Table, seen, FIXER, _Settings = {}, {}, {totaljumps = 0}, {}, {}

local tostring, tonumber, rawequal, rawset, type, typeof, unpack, pairs, ipairs =
	  tostring, tonumber, rawequal, rawset, type, typeof or type, unpack or table.unpack, pairs, ipairs

typeof, type = type, typeof
local rawlen                = rawlen or function(self)
	local mt = gmt(self)
	if not mt then return #self end
	
	local aux = gmt.__len
	gmt.__len = nil
	local n = #self
	gmt.__len = aux

	return n
end--function(v) return select("#", unpack(v)) end

local clamp                 = (Math or math).clamp or function(x, y, z)
	return
		(x >= y and x <= z and x) or
		(x <= y and x <= z and y) or
		(x >= y and x >= z and z) or
		((y + z) / 2)-(((y + z) / 2)%1)
end

local math_floor            = math.floor
local math_huge             = math.huge

local string_len            = string.len
local string_rep            = string.rep
local string_sub            = string.sub
local string_gsub           = string.gsub
local string_format         = string.format
local string_find           = string.find
local string_upper          = string.upper
local string_byte           = string.byte

local table_insert          = table.insert
local table_concat          = table.concat
local table_sort            = table.sort
local table_remove          = table.remove

local gmt, smt = debug.getmetatable or getmetatable, debug.setmetatable or setmetatable

local ReplaceKeymap = {
	["_"] = "_",
	["."] = ".",
	["("] = "(",
	[")"] = ")",
	["{"] = "{",
	["}"] = "}",
	["["] = "[",
	["]"] = "]",
	["="] = "=",
	["?"] = "?",
	["!"] = "!",
	["#"] = "#",
	["$"] = "$",
	["%"] = "%",
	["&"] = "&",
	["/"] = "/",
	["+"] = "+",
	["-"] = "-",
	["*"] = "*",
	["~"] = "~",
	["|"] = "|",
	["`"] = "`",
	[","] = ",",
	[":"] = ":",
	[";"] = ";",
	["^"] = "^",
	["°"] = "°",
	[">"] = ">",
	["<"] = "<",
	["0"] = "0",
	["1"] = "1",
	["2"] = "2",
	["3"] = "3",
	["4"] = "4",
	["5"] = "5",
	["6"] = "6",
	["7"] = "7",
	["8"] = "8",
	["9"] = "9",
	["@"] = "@",
	["\\"] = "\\"
}

_Settings.TAB_SIZE              = 4
_Settings.TAB_FORMAT            = string_rep(" ", _Settings.TAB_SIZE)
_Settings.PAGE_LIMIT            = 0 -- change this if you have trouble with some circular definitions. . .
_Settings.ERROR_ATTEMPT_TO      = "attempt to perform metamethod %s to table"
_Settings.FLOAT_SIZE            = "%.14g"--"%.19g"
--_Settings.DEFINED_ENVIROMENT    = _ENV or (_VERSION == "Lua 5.1" and getfenv()) or _G 
_Settings.OPERAND_VERSION       = (_VERSION == "Luau" and "%s") or (jit and "%p") or (_VERSION >= "Lua 5.1" and "%s")
--for i = 0, 512, 1 do _print(i..":", "\27[38;5;"..i.."mok\27[m") end
if _VERSION ~= "Luau" then
	--printf '\e[38;5;36m\e[m'
	_Settings.STRING_COLOR          = "\27[38;5;31m"--"\27\91\51\56\59\53\59\51\55\109"
	_Settings.STRING_SCAPE_COLOR    = "\27[38;5;28m"
	_Settings.CLOSE_COLOR           = "\27[m"
	_Settings.USERDATA_COLOR        = "\27[38;5;05m"
	_Settings.FUNCTION_COLOR        = "\27[38;5;124m"
	_Settings.NUMBER_COLOR          = "\27[38;5;220m" --"\27[38;5;214m"
	_Settings.CIRCULAR_COLOR        = "\27[38;5;8m"
	_Settings.NIL_COLOR             = "\27[38;5;214m"
	_Settings.BOOLEAN_COLOR         = "\27[38;5;184m"
	_Settings.THREAD_COLOR          = "\27[38;5;140m"

	ReplaceKeymap["\""]  = "\\\""
	ReplaceKeymap["\'"]  = "\\\'"
	ReplaceKeymap["\32"] = "\32"
	ReplaceKeymap["\t"]  = "\t"
	ReplaceKeymap["\\"]  = "\\\\"
	ReplaceKeymap["\r"]  = "\\r"
	ReplaceKeymap["\n"]  = "\\n"
else
	_Settings.STRING_COLOR          = ""
	_Settings.STRING_SCAPE_COLOR    = ""
	_Settings.CLOSE_COLOR           = ""
	_Settings.USERDATA_COLOR        = ""
	_Settings.FUNCTION_COLOR        = ""
	_Settings.NUMBER_COLOR          = ""
	_Settings.CIRCULAR_COLOR        = ""
	_Settings.NIL_COLOR             = ""
	_Settings.BOOLEAN_COLOR         = ""
	_Settings.THREAD_COLOR          = ""

	ReplaceKeymap["\""] = "\""
	ReplaceKeymap["\'"] = "\'"
	ReplaceKeymap["\32"] = "\32"
	ReplaceKeymap["\t"] = "\t"
	ReplaceKeymap["\\"] = "\\"
	ReplaceKeymap["\r"] = "\r"
	ReplaceKeymap["\n"] = "\n"
end

local DoTable, methods, TableMT

smt(FIXER, {
	__metatable = "locked",
	__newindex = function(self, idx, _) error(string_format("cannot define '%s' to protected table.", idx)) end
})

for i = 97, 122, 1 do
	ReplaceKeymap[string_format("%c", i)] = string_format("%c", i)
	ReplaceKeymap[string_format("%c", i-32)] = string_format("%c", i-32)
end

smt(ReplaceKeymap, {
	["__index"] = function(self, index)
		local st = {_Settings.STRING_SCAPE_COLOR}
		for i = 1, string_len(index), 1 do
			table_insert(st, string_format("\\%d", string_byte(index, i, i) or 0))
		end

		table_insert(st, _Settings.CLOSE_COLOR)
		table_insert(st, _Settings.STRING_COLOR)
		return table_concat(st)
	end,
	["__metatable"] = "locked"
})

Convert["function"] = function(val, _, _, _)
	local address = string_gsub(tostring(val), "function: ", "")
	return string_format(_Settings.FUNCTION_COLOR.."\"function at %s\"".._Settings.CLOSE_COLOR, address)
end

Convert["number"] = function(val, _, _, _)
	if tostring(val) == "inf" then
		return (rawget(math, "huge") and "math.huge --[[inf]]") or "infinite"
	end
	if tostring(val) == "-inf" then
		return (rawget(math, "huge") and "-math.huge --[[-inf]]") or "-infinite"
	end

	local snum = string_format(_Settings.FLOAT_SIZE, val)
	local x_neg = string_find(snum, "e%-%d+")
	if x_neg then
		local sn = tonumber(string_sub(string_sub(snum, x_neg), 3))
		return string_format(_Settings.NUMBER_COLOR.._Settings.FLOAT_SIZE.. _Settings.CLOSE_COLOR .."/".. _Settings.NUMBER_COLOR.."10^%.0f".._Settings.CLOSE_COLOR, val * 10 ^ sn, sn)
	end

	return _Settings.NUMBER_COLOR..snum.._Settings.CLOSE_COLOR
end

if _VERSION == "Luau" then
	Convert["string"] = function(val, _, _, _)
		local result = { "\"" }
		for i = 1, string_len(val), 1 do
			local char = string_sub(val, i, i)
			table_insert(result, ReplaceKeymap[char])
		end
		table_insert(result, "\"")
		return table_concat(result)
	end
else
	Convert["string"] = function(val, seen, _, _)
		local result = { _Settings.STRING_COLOR, "\"" }
		for i = 1, string_len(val), 1 do
			local char = string_sub(val, i, i)
			table_insert(result, ReplaceKeymap[char] or char)
		end
		table_insert(result, "\"".._Settings.CLOSE_COLOR) --"\"\27\91\51\55\109"
		return table_concat(result)
	end
end

Convert["userdata"] = function(val, _, _, _)
	local mt = gmt(val)
	if mt and rawget(mt, "__tostring") then
		return _Settings.USERDATA_COLOR .. '"' .. tostring(val) .. '"'.._Settings.CLOSE_COLOR
	end

	local address = string_gsub(tostring(val), "userdata: ", "")
	return string_format(_Settings.USERDATA_COLOR.."\"userdata at %s\"".._Settings.CLOSE_COLOR, address)
end

Convert["boolean"] = function(val, _, _, _)
	return _Settings.BOOLEAN_COLOR..tostring(val).._Settings.CLOSE_COLOR
end

Convert["nil"] = function(_, _, _, _)
	return _Settings.NIL_COLOR.."nil".._Settings.CLOSE_COLOR
end

Convert["thread"] = function(val, _, _, _)
	local address = string_format(string_gsub(tostring(val), "thread: ", ""), val)
	return string_format("%s\"thread at %s\"%s", _Settings.THREAD_COLOR, address, _Settings.CLOSE_COLOR)
end

local function doAddress(t)
	local mt = gmt(t)
	local ts = mt and rawget(mt, "__tostring")
	if ts then
		rawset(mt, "__tostring", nil)
		local address = string_sub(tostring(t), 8)
		rawset(mt, "__tostring", ts)

		return address
	end

	local address = string_sub(tostring(t), 8)
	return address
end

Convert["table"] = function(val, _, _, toppage)
	seen[val] = seen[val] or {
		["page"] = toppage,
		["value"] = val,
		["count"] = 0
	}
	do
		local mt0 = gmt(seen[val])
		if ((mt0 and rawget(mt0, "__mt") and rawget(mt0.__mt, "__tostring")) or (mt0 and rawget(mt0, "__tostring"))) and not rawequal((mt0.__mt or mt0).__tostring, TableMT.__tostring) and seen[val].count <= _Settings.PAGE_LIMIT then
			seen.totaljumps = clamp(seen.totaljumps - 1, 1, math_huge)
			return tostring(seen[val].value)
		end
		
		local mt1 = gmt(val)
		if ((mt1 and rawget(mt1, "__mt") and rawget(mt1.__mt, "__tostring")) or (mt1 and rawget(mt1, "__tostring"))) and not rawequal((mt1.__mt or mt1).__tostring, TableMT.__tostring) and seen[val].count <= _Settings.PAGE_LIMIT then
			seen.totaljumps = clamp(seen.totaljumps - 1, 1, math_huge)
			return tostring(val)
		end
	end
	local started = false

	for page, value in pairs(val) do
		started = true
		if type(value) == "table" then
			if seen[value] and seen[value].count >= _Settings.PAGE_LIMIT then
				seen[value].page = page
				local s = string_format(_Settings.CIRCULAR_COLOR.."{\"circular " .. (type(seen[value].value)) .. " (%s)? at ".. _Settings.OPERAND_VERSION .."\"}".._Settings.CLOSE_COLOR, seen[value].page or "N/A", doAddress(seen[value].value))
				--seen.totaljumps = clamp(seen.totaljumps - 1, 1, math_huge)
				return s
			end
			
			if seen[value] and seen[value].count < _Settings.PAGE_LIMIT then
				seen[value].count = seen[value].count + 1
				seen[value].page = page
				--seen.totaljumps = seen.totaljumps + 1
				local s = DoTable(seen[value].value, seen)
				seen.totaljumps = clamp(seen.totaljumps - 1, 0, math_huge)
				return s
			end

			seen[value] = seen[value] or {
				["page"] = page,
				["value"] = value,
				["count"] = 0
			}
			seen[value].page = page
			--break
		end
	end
	
	if not started then
		return "{}"
	end

	seen[val].count = seen[val].count + 1
	--seen.totaljumps = seen.totaljumps + 1
	local s = DoTable(seen[val].value, seen)
	--seen.totaljumps = clamp(seen.totaljumps - 1, 0, math_huge)
	return s
end


--if _VERSION == "Luau" then
--	Convert["vector"] = function(val, _, _, _)
--		return string_format("(%g, %g, %g)", val.X, val.Y, val.Z)
--	end
--elseif rawget(_G, jit) then
--	Convert["cdata"] = function(val, seen, _, _)
--		return string_format("\"%s\"", string_gsub(tostring(val), ":", " at"))
--	end
--end

smt(Convert, {
	__index = function(self, idx)
		return function(val, seen, _, _)
			local f = rawget(gmt(val) or FIXER, "__tostring")
			return f and f(val) or string_format("%s(%s)", type(val), tostring(val))
		end
	end
})

DoTable = function(t)
	local started = false
	local str = ""
	local tab = string_rep(_Settings.TAB_FORMAT, seen.totaljumps)
	seen.totaljumps = seen.totaljumps + 1
	
	for page, value in pairs(t) do
		started = true
		if type(value) == "table" then
			seen[value] = seen[value] or {
				["page"] = page,
				["count"] = 0,
				["value"] = value
			}
		end
		if type(page) == "table" then
			seen[page] = seen[page] or {
				["page"] = "N/A",
				["count"] = 0,
				["value"] = page
			}
		end
		
		local PAGE = Convert[type(page)](page, seen, seen.totaljumps, page)
		local VALUE = Convert[type(value)](value, seen, seen.totaljumps, page)
		
		str = str .. string_format("%s[%s] = %s%s\n", tab, PAGE, VALUE, next(t, page) == nil and "" or ",")
	end

	if started then
		seen.totaljumps = clamp(seen.totaljumps - 1, 0, math_huge)
		return string_format("{\n%s%s}", str, string_rep(_Settings.TAB_FORMAT, seen.totaljumps-1))
	end

	if seen[t] ~= nil and not started then
		if next(t) == nil then return "{}" end

		seen[t].page = seen[t].page or "N/A"
		seen[t].count = seen[t].count + 1
		local PAGE, VALUE
		
		local pmt = gmt(seen[t].page)
		local _pts = (pmt and pmt.__tostring)
		if pmt and not (rawequal(_pts, DoTable) or rawequal(_pts, TableMT.__tostring)) then
			local aux = seen[t]
			PAGE = _pts(seen[t].page)
			seen[t] = aux
		else
			PAGE = Convert[type(seen[t].page)](seen[t].page, seen, seen.totaljumps, seen[t].page)
		end

		local vmt = gmt(seen[t].value)
		local _vts = (vmt and vmt.__tostring)
		if vmt and not (rawequal(_vts, DoTable) or rawequal(_vts, TableMT.__tostring)) then
			local aux = seen[t]
			VALUE = _vts(seen[t].value)
			seen[t] = aux
		else
			VALUE = Convert[type(seen[t].value)](seen[t].value, seen, seen.totaljumps, seen[t].page)
		end

		seen.totaljumps = clamp(seen.totaljumps - 1, 0, math_huge)
		return string_format("{\n%s[%s] = %s\n%s}", string_rep(_Settings.TAB_FORMAT, seen.totaljumps-1), PAGE, VALUE, string_rep(_Settings.TAB_FORMAT, seen.totaljumps-1))
	end
	return "{}"
end

local function FN_TASK(self, idx)
	rawset(self, idx, nil)
end

local ftypes = {}
methods = {
	look = function(self, value0)
		return methods.foreach(self, function(index, value1)
			if rawequal(value0, value1) then return index end
		end)
	end,
	find = function(self, val, start, limit)
		start = (type(start) == "number" and start) or tonumber(start) or 1
		limit = (type(limit) == "number" and limit) or tonumber(limit) or rawlen(self)

		return methods.foreachi(self, function(i, v)
			if (i >= start and i <= limit) and v == val then
				return i, v
			end
		end)
	end,
	put = function(self, k, v)
		return rawset(self, k, v)
	end,
	iput = function(self, v)
		return rawset(self, rawlen(self) + 1, v)
	end,
	len = function(self, nobypass)
		if nobypass then
			local mt = gmt(self)
			if mt and rawget(mt, "__len") then
				return mt.__len(self)
			end
		end

		return select("#", unpack(self))
	end,
	pop = function(self, limit, ignore)
		limit = (type(limit) == "number" and limit) or tonumber(limit) or tonumber(limit, 16) or rawlen(self)
		local len = rawlen(self)
		local i = clamp(limit, 1, limit)
		local val = rawget(self, i)
		
		if not ignore then
			table_remove(self, i)
		else
			rawset(self, i, nil)
		end

		return self, i, val
	end,
	fori = function(self, fn, n1, n2, n3)
		n1 = (type(n1) == "number" and n1) or tonumber(n1) or 1
		n2 = (type(n2) == "number" and n2) or tonumber(n2) or rawlen(self)
		n3 = (type(n3) == "number" and n3) or tonumber(n3) or 1

		for n0 = n1, n2, n3 do
			local packed = { fn(n0, rawget(self, n0)) }
			if rawlen(packed) > 0 then
				return unpack(packed)
			end
		end
	end,
	foreach = function(self, f)
		for k, v in pairs(self) do
			local p = { f(k, v) }
			if rawlen(p) > 0 then
				return unpack(p)
			end
		end
	end,
	foreachi = function(self, f)
		for i, v in ipairs(self) do
			local p = { f(i, v) }
			if rawlen(p) > 0 then
				return unpack(p)
			end
		end
	end,
	shake = function(self, limit)
		limit = type(limit) == "number" and math_floor(limit or tonumber(limit) or tonumber(limit, 16)) or math_huge
		methods.foreach(self, function(i, v)
			if type(i) ~= "number" or limit < 1 then return end
			limit = limit - 1
			local len = rawlen(self)
			local aux = rawget(self, len)
			rawset(self, i, aux)
			rawset(self, len, v)
		end)
		return self
	end,
	reverse = function(self)
		local size = rawlen(self)
		return methods.foreachi(self, function(i, v)
			local aux = methods.get(self, i)
			methods.put(self, i, methods.get(self, size))--:put(size, aux)
			methods.put(self, size, aux)
			size = size - 1
			if i >= size then return self end
		end)
	end,
	get = function(self, idx)
		return rawget(self, idx)
	end,
	clone = function(self, noapply, ignoreMT)
		local t = (not noapply and Table.new()) or {}
		methods.foreach(self, function(k, v)
			rawset(t, k, v)
		end)
		local _mt = gmt(self)
		if not ignoreMT and _mt ~= nil then
			smt(t, _mt)
		end
		return t
	end,
	union = function(self, t, intersect, force)
		assert(not rawequal(self, t), "cannot do self-union.")
		if not ((intersect == nil) or (intersect == false)) then
			methods.foreach(t, function(idx, v)
				if type(idx) == "number" then
					methods.iput(self, v)
				elseif rawget(self, idx) == rawget(t, idx) and force == true then
					rawset(self, idx, v)
				elseif rawget(self, idx) == rawget(t, idx) and force ~= true then
					return -- skips next level
				else
					rawset(self, idx, v)
				end
			end)

			return self
		end

		local newT = Table.new()

		methods.foreach(self, function(idx, v)
			rawset(newT, idx, v)
		end)
		methods.foreach(t, function(idx, v)
			if type(idx) == "number" then
				methods.iput(newT, v)
			elseif rawget(newT, idx) == rawget(self, idx) and force == true then
				rawset(newT, idx, v)
			elseif rawget(newT, idx) == rawget(self, idx) and force ~= true then
				return -- skip to next level.
			else
				rawset(newT, idx, v)
			end
		end)

		return newT
	end,
	flush = function(self, fnTask)
		fnTask = (type(fnTask) == "function" and fnTask) or FN_TASK

		methods.foreach(self, function(idx)
			fnTask(self, idx)
		end)

		return self
	end,
	stack = function(self, ...)
		methods.foreachi({...}, function(_, v)
			methods.iput(self, v)
		end)
		return self
	end,
	tconcat = function(self, fn, sep)
		local tStr = ""
		sep = (sep ~= nil and tostring(sep)) or ""
		methods.foreachi(self, function(i, v)
			tStr = tStr .. tostring(
				type(fn) == "string" and tostring(v)
				or
				tostring(fn(i, v))
			) .. (i < rawlen(self) and sep or "")
		end)
		return tStr
	end,
	append = function(self, size, value, ftype, ...)
		ftype = (ftypes[ftype] and ftype) or "solid"
		ftypes[ftype](self, size, value, ...)
		return self
	end,
	unpack = unpack
}

TableMT = {
	__index = function(self, index)
		if (index == "methods") then return methods end
		if rawget(methods, index) then return methods[index] end
		if rawget(table, index) then return table[index] end
		if index == "iter" then
			return function(_, k)
				return next(self, k)
			end
		end

		local selfMT = gmt(self)
		local __mt = rawget(selfMT, "__mt")
		if not __mt then return rawget(methods, index) end

		local _idx = rawget(__mt, "__index")
		if not _idx then return end

		if type(_idx) == "table" then return _idx[index] end
		
		return _idx(self, index)
	end,
	__newindex = function(self, idx, val)
		local selfMT = gmt(self)
		local __mt = rawget(selfMT, "__mt")
		if not __mt then return rawset(self, idx, val) end

		local __newi = rawget(__mt, "__newindex")
		if not __newi then return rawset(self, idx, val) end

		return __newi(self, idx, val)
	end,
	__call = function(self, ...)
		local selfMT = gmt(self)
		local __mt = rawget(selfMT, "__mt")
		if not __mt then error(string_format(_Settings.ERROR_ATTEMPT_TO, "call"), 3) end

		local __call = rawget(__mt, "__call")
		if not __call then error(string_format(_Settings.ERROR_ATTEMPT_TO, "call"), 3) end

		return __call(self, ...)
	end,
	__add = function(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__add")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "arithmetic (add)"), 3) end
		return __op(self, what)
	end,
	__sub = function(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__sub")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "arithmetic (sub)"), 3) end
		return __op(self, what)
	end,
	__mul = function(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__mul")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "arithmetic (mul)"), 3) end
		return __op(self, what)
	end,
	__div = function(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__div")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "arithmetic (div)"), 3) end
		return __op(self, what)

	end,
	__mod = function(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__mod")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "arithmetic (mod)"), 3) end
		return __op(self, what)
	end,
	__pow = function(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__pow")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "arithmetic (pow)"), 3) end
		return __op(self, what)
	end,
	__unm = function(self)
		local selfMT = gmt(self)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__unm")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "arithmetic (unm)"), 3) end
		return __op(self, what)
	end,
	__concat = function(self, what)
		if type(self) == "table" then
			local selfMT = gmt(self)
			local __mt = rawget(selfMT, "__mt")
			if not __mt then error(string_format(_Settings.ERROR_ATTEMPT_TO, string_format("concat (%s and %s)", type(self), type(what))), 3) end
			
			local __op = rawget(__mt, "__concat")
			if not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, string_format("concat (%s and %s)", type(self), type(what))), 3) end
			
			return __op(self, what)
		end

		local selfMT = gmt(what)
		local __mt = rawget(selfMT, "__mt")
		if not __mt then error(string_format(_Settings.ERROR_ATTEMPT_TO, string_format("concat (%s and %s)", type(self), type(what))), 3) end

		local __op = rawget(__mt, "__concat")
		if not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, string_format("concat (%s and %s)", type(self), type(what))), 3) end
		
		return __op(what, self)
	end,
	__eq = function(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__eq")

		--if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "arithmetic (eq)")) end
		if not __mt or not __op then return rawequal(self, what) end

		return __op(self, what)
	end,
	__lt = function(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__lt")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "logical operator (lt)"), 3) end
		return __op(self, what)

	end,
	__le = function(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__le")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "logical operator (le)"), 3) end
		return __op(self, what)
	end,
	--__metatable = "locked",
	__tostring = function(self)
		local selfMT = gmt(self)
		local __mt = rawget(selfMT, "__mt")
		if not __mt then
			seen[self] = seen[self] or {
				["value"] = self,
				["count"] = 0
			}
			seen.totaljumps = seen.totaljumps + 1
			local s = DoTable(self, seen)
			seen.totaljumps = clamp(seen.totaljumps-1, 0, math_huge)
			--Table.tostring(FIXER)
			return s
		end

		local __op = rawget(__mt, "__tostring")
		if not __op then
			seen[self] = seen[self] or {
				["value"] = self,
				["count"] = 0
			}
			seen.totaljumps = seen.totaljumps + 1
			local s = DoTable(self, seen)
			seen.totaljumps = clamp(seen.totaljumps-1, 0, math_huge)
			--Table.tostring(FIXER)
			return s
		end
		--Table.tostring(FIXER)
		return __op(self)
	end,
}
if _VERSION > "Lua 5.1" --[[or _VERSION > "Lua 5.2"]] then
	 function TableMT.__len(self)
		local selfMT = gmt(self)
		local __mt = rawget(selfMT, "__mt")
		if not __mt then return rawlen(self) end

		local __op = rawget(__mt, "__len")
		if not __op then return end

		return __op(self)
	end
end
if _VERSION > "Lua 5.2" then
	function TableMT.__idiv(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__idiv")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "arithmetic (idiv)"), 3) end
		return __op(self, what)
	end

	function TableMT.__band(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__band")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "bitwise (band)"), 3) end
		return __op(self, what)
	end

	function TableMT.__bor(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__bor")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "bitwise (bor)"), 3) end
		return __op(self, what)
	end

	function TableMT.__bnot(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__bnot")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "bitwise (bnot)"), 3) end
		return __op(self, what)
	end

	function TableMT.__shl(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__shl")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "bitwise (shl)"), 3) end
		return __op(self, what)
	end

	function TableMT.__shr(self, what)
		local selfMT = gmt(self) or gmt(what)
		local __mt = rawget(selfMT, "__mt")
		local __op = __mt and rawget(__mt, "__shr")

		if not __mt or not __op then error(string_format(_Settings.ERROR_ATTEMPT_TO, "bitwise (shr)"), 3) end
		return __op(self, what)
	end
end

smt(methods, TableMT)

function ftypes.keyset(nt, size, fn, ...)
	for i = 1, size, 1 do
		rawset(nt, fn(i, ...))
	end
end

function ftypes.tailcall(nt, size, fn, ...)
	for i = 1, size, 1 do
		rawset(nt, i, fn(i, ...))
	end
end

function ftypes.callset(nt, size, fn, v, ...)
	for i = 1, size, 1 do
		local val = fn(i, ...)
		if v ~= val then
			rawset(nt, rawlen(nt)+1, val)
		end
	end
end

function ftypes.solid(nt, size, value, ...)
	for i = 1, size, 1 do
		rawset(nt, i, value)
	end
end

function Table.apply(t)
	smt(t, methods.clone(TableMT, true))
	return t
end

function Table.new(...)
	local t = {...}
	smt(t, methods.clone(TableMT, true))
	return t
end

function Table.create(size, value, ftype, ...)
	ftype = (ftypes[ftype] and ftype) or "solid"
	local newTable = Table.new()
	ftypes[ftype](newTable, size, value, ...)
	return newTable
end

function Table.setmetatable(t, mt)
	local baseMT = gmt(t) or gmt(Table.apply(t))
	baseMT.__mt = mt
	return t
end

function Table.getmetatable(t)
	local baseMT = gmt(t)
	return baseMT and baseMT.__mt
end

function Table.ftostring(v, nohighlight, _seen)
	local seen = _seen or seen
	seen.totaljumps = seen.totaljumps + 1--clamp(seen.totaljumps + 1, 1, _Settings.PAGE_LIMIT+1)
	local s = Convert[type(v)](v, seen, seen.totaljumps)
	--local _totaljumps = seen.totaljumps
	--seen.totaljumps = clamp(seen.totaljumps - 1, 1, _Settings.PAGE_LIMIT+1)
	for k, _ in pairs(seen) do
		--if k == "totaljumps" then system.warn("a", seen[k]) end
		seen[k] = k == "totaljumps" and clamp(seen[k]-1, 0, math_huge) or nil
		--if k == "totaljumps" then system.warn("b", seen[k]) end
	end
	--seen.totaljumps = _totaljumps - 1
	if nohighlight then
		s = string_gsub(s, string_gsub(_Settings.STRING_COLOR, "%[", "%1%1]"), "")
		s = string_gsub(s, string_gsub(_Settings.STRING_SCAPE_COLOR, "%[", "%1%1]"), "")
		s = string_gsub(s, string_gsub(_Settings.CLOSE_COLOR, "%[", "%1%1]"), "")
		s = string_gsub(s, string_gsub(_Settings.USERDATA_COLOR, "%[", "%1%1]"), "")
		s = string_gsub(s, string_gsub(_Settings.FUNCTION_COLOR, "%[", "%1%1]"), "")
		s = string_gsub(s, string_gsub(_Settings.NUMBER_COLOR, "%[", "%1%1]"), "")
		s = string_gsub(s, string_gsub(_Settings.CIRCULAR_COLOR, "%[", "%1%1]"), "")
		s = string_gsub(s, string_gsub(_Settings.NIL_COLOR, "%[", "%1%1]"), "")
		s = string_gsub(s, string_gsub(_Settings.BOOLEAN_COLOR, "%[", "%1%1]"), "")
		s = string_gsub(s, string_gsub(_Settings.THREAD_COLOR, "%[", "%1%1]"), "")
	end

	return s
end
Table.tostring = Table.ftostring
Table.settings = Table.apply(_Settings)
--_Settings.DEFINED_ENVIROMENT = methods.clone(_Settings.DEFINED_ENVIROMENT, true)

return Table.apply(Table)
