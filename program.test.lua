import("Table", "system", "csv")

local f = system.curldownload("https://www.openml.org/data/get_csv/16826755/phpMYEkMl", true)
local t = csv.read(f)

for k, v in t.iter do
	print(k, v)
end