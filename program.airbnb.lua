import("Table", "system", "csv", "File", "json")

local function mean(t)
    local s, n = 0, 0
    for _, v in t.iter do s = s + v; n = n + 1 end
    return n > 0 and s / n or 0
end

local function median(t)
    local arr = Table.clone(t)--Table.create(t:len(), function(i) return t[i] end, "tailcall")
    arr:sort()--Table.sort(arr)
    local n = arr:len()
    return n % 2 == 1 and arr[math.floor((n+1)/2)] or (arr[math.floor(n/2)] + arr[math.floor(n/2+1)])/2
end

local function stddev(t)
    local m = mean(t)
    local sum, n = 0, 0
    for _, v in t.iter do sum = sum + (v-m)^2; n = n+1 end
    return n > 1 and math.sqrt(sum / (n-1)) or 0
end

local function minmax(t)
    local min, max
    for i, v in t.iteri do
        if i == 1 then min, max = v, v
        else min = math.min(min, v); max = math.max(max, v) end
    end
    return min, max
end

local function corr(x, y)
    local xs, ys = {}, {}

    for i = 1, math.min(x:len(), y:len()), 1 do
        local vx = tonumber(x[i])
        local vy = tonumber(y[i])

        if vx ~= nil and vy ~= nil then
            table.insert(xs, vx)
            table.insert(ys, vy)
        end
    end

    local n = #xs
    if n <= 1 then return 0 end

    local mean_x, mean_y = 0, 0
    for i = 1, n do
        mean_x = mean_x + xs[i]
        mean_y = mean_y + ys[i]
    end
    mean_x = mean_x / n
    mean_y = mean_y / n

    local num, dx, dy = 0, 0, 0
    for i = 1, n, 1 do
        local vx = xs[i]
        local vy = ys[i]

        num = num + (vx - mean_x) * (vy - mean_y)
        dx = dx + (vx - mean_x)^2
        dy = dy + (vy - mean_y)^2
    end

    local denom = math.sqrt(dx * dy)
    if denom == 0 then return 0 end

    return num / denom
end

local t_rows = csv.read("data/train.csv")
local t = Table.new()

local t_count = 0
for _, row in t_rows.iteri do
    for k, v in row.iter do
        if not t[k] then
            t[k] = t[k] or Table.new()
        end
        t[k][rawlen(t[k]) + 1] = v
    end
end

local target = Table.create(t.log_price:len(), function(i)
    return tonumber(t.log_price[i])
end, "xtailcall")

local stats = Table.new()
local correlations = Table.new()

for col_name, col_data in t.iter do
    local numeric_col = Table.create(col_data:len(), function(i)
        return tonumber(col_data[i])
    end, "xtailcall")

    if numeric_col:len() > 0 then
        local min_val, max_val = minmax(numeric_col)
        stats[col_name] = {
            mean = mean(numeric_col),
            median = median(numeric_col),
            std = stddev(numeric_col),
            min = min_val,
            max = max_val
        }
        if col_name ~= "log_price" then
            correlations[col_name] = corr(t.log_price, col_data)
        end
    end
end

local out = File.new("data/stats.json", "w", true)
out:flush()
out:write(json.encode({stats=stats, correlations=correlations}))

system.print("Variables con correlacion |r| > 0.5 con log_price:")
for col, c in correlations.iter do
    if math.abs(c) > 0.5 then
        system.printf("%s -> correlacion: %.2f", col, c)
    end
end

local headers = {}
for col_name, _ in t.iter do
    table.insert(headers, col_name)
end
local out_csv = io.open("data/processed.csv", "w")--File.new("data/processed.csv", "rw", true)
out_csv:write(table.concat(headers, ",") .. "\n")

local n_filas = rawlen(t[headers[1]])
for i = 1, n_filas, 1 do
    local row = {}
    for _, col in ipairs(headers) do
        local val = t[col][i] or ""
        table.insert(row, tostring(val))
    end
    out_csv:write(table.concat(row, ",") .. "\n")
end

system.print("Dataset procesado generado en data/processed.csv")
system.print("Calculo de estadisticas completado. JSON generado en data/stats.json")
