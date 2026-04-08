import("Table")

local table_insert = table.insert
local table_concat = table.concat
local Table_apply = Table.apply
local Table_new = Table.new

local string_sub = string.sub
local string_match = string.match
local string_gsub = string.gsub
local string_find = string.find

local tostring = tostring

local csv = {}
local function trim(s)
    local s = (string_gsub(s, "^%s+", ""))
	return (string_gsub(s, "%s+$", ""))
end

local function escape_csv(v)
    v = tostring(v or "")

    if string_find(v, '[",]') then
        v = '"' .. string_gsub(v, '"', '""') .. '"'
    end

    return v
end

local function split_csv(line)
    local res = {}
    local buf = ""
    local in_quotes = false

    for i = 1, #line do
        local c = string_sub(line, i, i)

        if c == '"' then
            -- handle escaped quotes ""
            if in_quotes and string_sub(line, i+1, i+1) == '"' then
                buf = buf .. '"'
                i = i + 1
            else
                in_quotes = not in_quotes
            end
        elseif c == ',' and not in_quotes then
            table_insert(res, buf)
            buf = ""
        else
            buf = buf .. c
        end
    end

    table_insert(res, buf)
    return res
end

function csv.read(path)
    local file = assert(io.open(path, "r"))
    local headers = split_csv(file:read("*l"))

    local rows = Table.new()

    for line in file:lines() do
        if line ~= "" then
            local cols = split_csv(line)
            local row = Table.new()

            local max_len = math.max(#headers, #cols)

            for i = 1, max_len do
                local h = headers[i]
                if h then
                    local v = cols[i]

                    if v ~= nil then
                        v = trim(v)
                        v = string_gsub(v, '^"(.*)"$', "%1")
                        row[h] = tonumber(v) or v
                    else
                        row[h] = nil
                    end
                end
            end

            --rows[rawlen(rows) + 1] = row
			table_insert(rows, row)
        end
    end

    file:close()
    return rows
end

function csv.write(path, headers, rows)
    local file = assert(io.open(path, "w"))

    -- headers
    local h = {}
    for i = 1, #headers do
        h[i] = escape_csv(headers[i])
    end
    file:write(table_concat(h, ",") .. "\n")

    -- rows
    for _, row in ipairs(rows) do
        local line = {}

        for i = 1, #headers do
            local v = row[headers[i]]
            line[i] = escape_csv(v)
        end

        file:write(table_concat(line, ",") .. "\n")
    end

    file:close()
end

return csv