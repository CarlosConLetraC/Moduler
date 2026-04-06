import("Table", "system", "csv")

local f = system.wgetdownload("https://www.openml.org/data/get_csv/16826755/phpMYEkMl", true)
local t = Table.apply(csv.read(f))

for k, v in t.iter do
	system.print(k, v)
end