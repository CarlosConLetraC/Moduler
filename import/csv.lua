import("Table")

local Table_apply = Table.apply
local Table_new = Table.new
local csv = {}
local function trim(s) return s:match("^%s*(.-)%s*$") end

function csv.read(path)
	local data, headers = {}, {}
	local file = type(path) == "userdata" and path or assert(io.open(path, "r"), "csv: cannot open file '"..tostring(path).."'")

	for line in file:lines() do
		if #headers == 0 then
			for h in line:gmatch("([^,]+)") do
				headers[#headers+1] = trim(h)
			end
		else
			local row = Table_new()--{}
			local i = 1

			for v in line:gmatch("([^,]*)") do
				if i > #headers then break end

				v = trim(v):gsub('"', '')

				row[headers[i]] = tonumber(v) or v
				i = i + 1
			end

			data[#data+1] = row
		end
	end

	file:close()
	return Table_apply(data)
end

return csv