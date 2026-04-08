import("Table", "system", "csv", "File", "json")

local function mean(t)
    local s, n = 0, 0
    for _, v in t.iter do s = s + v; n = n + 1 end
    return s / n
end

local function median(t)
    local arr = Table.create(t:len(), function(i) return t[i] end, "tailcall")
    Table.sort(arr)
    local n = #arr
    return n % 2 == 1 and arr[math.floor((n+1)/2)] or (arr[n/2] + arr[n/2+1])/2
end

local function stddev(t)
    local m = mean(t)
    local sum, n = 0, 0
    for _, v in t.iter do sum = sum + (v-m)^2; n = n+1 end
    return math.sqrt(sum / (n-1))
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
    local n, mean_x, mean_y = 0, 0, 0
    for i, vx in x.iteri do
        local vy = y[i]
        mean_x = mean_x + vx
        mean_y = mean_y + vy
        n = n + 1
    end
    mean_x = mean_x/n
    mean_y = mean_y/n
    local num, dx, dy = 0,0,0
    for i, vx in x.iteri do
        local vy = y[i]
        num = num + (vx-mean_x)*(vy-mean_y)
        dx = dx + (vx-mean_x)^2
        dy = dy + (vy-mean_y)^2
    end
    return num / math.sqrt(dx*dy)
end

local t_rows = csv.read("data/train.csv")
local t = Table.new()

for _, row in ipairs(t_rows) do
    for k,v in pairs(row) do
        if not t[k] then
            t[k] = select(1, Table.new()) -- toma solo un valor para evitar error
        end
        t[k][#t[k]+1] = v
    end
end

--local target = Table.create(t.log_price:len(), function(i)
--    return tonumber(t.log_price[i]) or 0
--end, "tailcall")
local target = {}
for i = 1, #t.log_price, 1 do
    target[i] = tonumber(t.log_price[i]) or 0
end
Table.apply(target)

local stats = Table.new()
local correlations = Table.new()

for col_name, col_data in t.iter do
    local numeric_col = Table.create(col_data:len(), function(i)
        return tonumber(col_data[i]) or 0
    end, "tailcall")

    if #numeric_col > 0 then
        local min_val, max_val = minmax(numeric_col)
        stats[col_name] = {
            mean = mean(numeric_col),
            median = median(numeric_col),
            std = stddev(numeric_col),
            min = min_val,
            max = max_val
        }
        if col_name ~= "log_price" then
            correlations[col_name] = corr(target, numeric_col)
        end
    end
end

local out = File.new("data/stats.json", "w", true)
out:write(json.encode({stats=stats, correlations=correlations}))

system.print("Variables con correlacion |r| > 0.5 con log_price:")
for col, c in correlations.iter do
    if math.abs(c) > 0.5 then
        system.printf("%s -> correlacion: %.2f", col, c)
    end
end

system.print("Calculo de estadisticas completado. JSON generado en data/stats.json")
