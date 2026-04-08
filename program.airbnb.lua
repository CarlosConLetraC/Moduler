import("Table", "system", "csv", "File", "json")

local function mean(t)
    local s, n = 0, 0
    for i = 1, t:len() do
        local v = t[i]
        if v ~= nil then
            s = s + v
            n = n + 1
        end
    end
    return n > 0 and s / n or 0
end

local function stddev(t)
    local m = mean(t)
    local s, n = 0, 0

    for i = 1, t:len() do
        local v = t[i]
        if v ~= nil then
            s = s + (v - m)^2
            n = n + 1
        end
    end

    return n > 1 and math.sqrt(s / (n - 1)) or 0
end

local function minmax(t)
    local min_v, max_v = nil, nil

    for i = 1, t:len() do
        local v = t[i]
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
    local xs, ys = {}, {}

    local n = math.min(x:len(), y:len())

    for i = 1, n, 1 do
        local vx = tonumber(x[i])
        local vy = tonumber(y[i])

        if vx and vy then
            xs[#xs+1] = vx
            ys[#ys+1] = vy
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
        dx = dx + dxv^2
        dy = dy + dyv^2
    end

    local denom = math.sqrt(dx * dy)
    if denom == 0 then return 0 end

    return num / denom
end

local function is_id_column(name)
    return string.find(name:lower(), "id") ~= nil
end

-- =========================
-- 1. LOAD DATA
-- =========================

local rows = csv.read("data/train.csv")

if not rows or rows:len() == 0 then
    error("CSV vacío o inválido")
end

-- =========================
-- 2. HEADERS
-- =========================

local headers = {}
for k, _ in rows[1].iter do
    table.insert(headers, k)
end

-- =========================
-- 3. BUILD COLUMNS
-- =========================

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

-- =========================
-- 4. TARGET
-- =========================

local target = cols["log_price"]
if not target then
    error("Falta columna log_price en dataset")
end

-- =========================
-- 5. FEATURE ENGINEERING SAFE FILTER
-- =========================

local function count_valid(t)
    local c = 0
    for i = 1, t:len(), 1 do
        if t[i] ~= nil and tonumber(t[i]) ~= nil then
            c = c + 1
        end
    end
    return c
end

local stats = Table.new()
local correlations = Table.new()

for _, col in ipairs(headers) do
    local data = cols[col]

    local numeric = Table.create(data:len(), function(i)
        return tonumber(data[i])
    end, "tailcall")

    local total = data:len()
    local valid = count_valid(data)
    local ratio = total > 0 and valid / total or 0

    local variation = stddev(numeric)
    local is_id = is_id_column(col)
    local is_target = (col == "log_price")
    if is_target or (ratio > 0.6 and variation > 0 and not is_id) then

        local min_v, max_v = minmax(numeric)

        stats[col] = {
            mean = mean(numeric),
            median = 0,
            std = variation,
            min = min_v,
            max = max_v
        }

        if not is_target then
            correlations[col] = corr(target, numeric)
        end
    end
end

local function feature_is_valid(col, numeric, raw)
    local valid = 0
    local total = raw:len()

    for i = 1, total, 1 do
        if numeric[i] ~= nil then
            valid = valid + 1
        end
    end

    local ratio = valid / total
    local variation = stddev(numeric)

    if ratio < 0.6 then return false end
    if variation <= 0 then return false end
    if is_id_column(col) then return false end
    if col == "log_price" then return true end

    return true
end

-- =========================
-- 6. STATS + CORR
-- =========================

for _, col in ipairs(headers) do
    local data = cols[col]

    local numeric = Table.create(data:len(), function(i)
        return tonumber(data[i])
    end, "tailcall")

    if feature_is_valid(col, numeric, data) then
        local min_v, max_v = minmax(numeric)

        stats[col] = {
            mean = mean(numeric),
            median = 0,
            std = stddev(numeric),
            min = min_v,
            max = max_v
        }

        if col ~= "log_price" then
            correlations[col] = corr(target, numeric)
        end
    end
end

-- =========================
-- 7. OUTPUT JSON
-- =========================

local out = File.new("data/stats.json", "w", true)
out:clear()

out:write(json.encode({
    stats = stats,
    correlations = correlations
}))

-- =========================
-- 8. EXPORT CLEAN CSV
-- =========================

local f = io.open("data/processed.csv", "w")
f:write(table.concat(headers, ",") .. "\n")

for i = 1, rows:len() do
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