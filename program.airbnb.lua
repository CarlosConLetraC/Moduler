import("Table", "system", "csv", "File", "json")

local function mean(t)
    local s, n = 0, 0

    for i = 1, t:len(), 1 do
        local v = tonumber(t[i])
        if v ~= nil then
            s = s + v
            n = n + 1
        end
    end

    return n > 0 and (s / n) or 0
end

local function stddev(t)
    local m = mean(t)
    local s, n = 0, 0

    for i = 1, t:len(), 1 do
        local v = tonumber(t[i])
        if v ~= nil then
            s = s + (v - m) ^ 2
            n = n + 1
        end
    end

    return n > 1 and math.sqrt(s / (n - 1)) or 0
end

local function minmax(t)
    local min_v, max_v = nil, nil

    for i = 1, t:len(), 1 do
        local v = tonumber(t[i])
        if v ~= nil then
            if not min_v then
                min_v, max_v = v, v
            else
                min_v = math.min(min_v, v)
                max_v = math.max(max_v, v)
            end
        end
    end

    return min_v, max_v
end

local function corr(x, y)
    local xs, ys = {}

    local n = math.min(x:len(), y:len())

    for i = 1, n, 1 do
        local vx = tonumber(x[i])
        local vy = tonumber(y[i])

        if vx ~= nil and vy ~= nil then
            xs[#xs + 1] = vx
            ys[#ys + 1] = vy
        end
    end

    local m = #xs
    if m <= 1 then return 0 end

    local mx, my = 0, 0

    for i = 1, m, 1 do
        mx = mx + xs[i]
        my = my + ys[i]
    end

    mx, my = mx / m, my / m

    local num, dx, dy = 0, 0, 0

    for i = 1, m, 1 do
        local dxv = xs[i] - mx
        local dyv = ys[i] - my

        num = num + dxv * dyv
        dx = dx + dxv ^ 2
        dy = dy + dyv ^ 2
    end

    local denom = math.sqrt(dx * dy)
    if denom == 0 then return 0 end

    return num / denom
end

local function is_id_column(name)
    return string.find(name:lower(), "id") ~= nil
end

local rows = csv.read("data/train.csv")

if not rows or rows:len() == 0 then
    error("CSV vacío o inválido")
end

local headers = {}
for k, _ in rows[1].iter do
    table.insert(headers, k)
end

local cols = Table.new()

for i = 1, rows:len(), 1 do
    local row = rows[i]

    for j = 1, #headers, 1 do
        local col = headers[j]

        if not cols[col] then
            cols[col] = Table.new()
        end

        table.insert(cols[col], row[col])
    end
end

local target = cols["log_price"]
if not target then
    error("Falta columna log_price", 3)
end

local function valid_ratio(data)
    local valid = 0
    local total = data:len()

    for i = 1, total, 1 do
        if tonumber(data[i]) ~= nil then
            valid = valid + 1
        end
    end

    return total > 0 and (valid / total) or 0
end

local stats = Table.new()
local correlations = Table.new()

for _, col in ipairs(headers) do
    local data = cols[col]

    local numeric = Table.create(data:len(), function(i)
        return tonumber(data[i])
    end, "tailcall")

    local ratio = valid_ratio(data)
    local is_id = is_id_column(col)
    local is_target = (col == "log_price")

    if is_target or (ratio > 0.3 and not is_id) then
        local min_v, max_v = minmax(data)

        stats[col] = {
            mean = mean(data),
            std = stddev(data),
            min = min_v,
            max = max_v
        }

        if not is_target then
            correlations[col] = corr(target, data)
        end
    end
end

local out = File.new("data/stats.json", "w", true)
out:clear()
out:write(json.encode({
    stats = stats,
    correlations = correlations
}))

local f = io.open("data/processed.csv", "w")
f:write(table.concat(headers, ",") .. "\n")

for i = 1, rows:len(), 1 do
    local line = {}

    for _, col in ipairs(headers) do
        local v = rows[i][col]
        if v == nil then v = "" end
        line[#line + 1] = tostring(v)
    end

    f:write(table.concat(line, ",") .. "\n")
end

f:close()
system.print("Pipeline completado correctamente")
--[[
local csv = require("csv")
local Table = require("Table")

local rows = csv.read("data/processed.csv")
local headers = {}
if #rows > 0 then
    for h, _ in pairs(rows[1]) do
        table.insert(headers, h)
    end
end

local useful_headers = {}
for _, h in ipairs(headers) do
    local non_nil_count = 0
    for _, row in ipairs(rows) do
        if row[h] ~= nil then non_nil_count = non_nil_count + 1 end
    end
    if non_nil_count > 0 then
        table.insert(useful_headers, h)
    end
end

local function is_useful_col(col)
    local values = {}
    for _, row in ipairs(rows) do
        local v = row[col]
        if v ~= nil then
            values[v] = true
        end
    end
    local non_nil_count = 0
    for _, row in ipairs(rows) do
        if row[col] ~= nil then non_nil_count = non_nil_count + 1 end
    end
    return non_nil_count > 50 and table.getn(values) > 1
end

local numeric_cols = {}
for _, h in ipairs(useful_headers) do
    local all_numeric = true
    for _, row in ipairs(rows) do
        local v = row[h]
        if v ~= nil and type(v) ~= "number" then
            all_numeric = false
            break
        end
    end
    if all_numeric and is_useful_col(h) then
        table.insert(numeric_cols, h)
    end
end

local log_price_exists = false
for _, h in ipairs(numeric_cols) do
    if h == "log_price" then log_price_exists = true end
end
if not log_price_exists then
    error("log_price no existe en el dataset")
end

local function pearson_corr(col1, col2)
    local mean1, mean2, n = 0, 0, 0
    for _, row in ipairs(rows) do
        local x, y = row[col1], row[col2]
        if x and y then
            mean1 = mean1 + x
            mean2 = mean2 + y
            n = n + 1
        end
    end
    if n == 0 then return 0 end
    mean1 = mean1 / n
    mean2 = mean2 / n

    local num, den1, den2 = 0, 0, 0
    for _, row in ipairs(rows) do
        local x, y = row[col1], row[col2]
        if x and y then
            local dx, dy = x - mean1, y - mean2
            num = num + dx*dy
            den1 = den1 + dx*dx
            den2 = den2 + dy*dy
        end
    end
    if den1 == 0 or den2 == 0 then return 0 end
    return num / math.sqrt(den1*den2)
end

local important_cols = {}
for _, c in ipairs(numeric_cols) do
    if c ~= "log_price" then
        local r = pearson_corr(c, "log_price")
        if math.abs(r) > 0.1 then
            table.insert(important_cols, c)
        end
    end
end

print("Columnas importantes:", table.concat(important_cols, ", "))
<<<<<<< HEAD
]]
=======
]]
>>>>>>> 5d6556d7aed047c86b6edece42253bc4c9f47b6f
