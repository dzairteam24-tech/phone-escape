-- NumberFormat: short display for huge numbers, K / M / B / T / Qa / Qi —
-- the same suffix style the original game uses (no "Zillion" there).
local NumberFormat = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function NumberFormat.format(value: number): string
	if value ~= value then
		return "0"
	end
	if value < 0 then
		return "-" .. NumberFormat.format(-value)
	end
	if value < 1000 then
		if value % 1 == 0 then
			return string.format("%d", value)
		end
		return string.format("%.1f", value)
	end
	local tier = math.floor(math.log10(value) / 3)
	if tier >= #SUFFIXES then
		tier = #SUFFIXES - 1
	end
	local scaled = value / (10 ^ (tier * 3))
	local text
	if scaled >= 100 then
		text = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		text = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		text = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	text = string.gsub(text, "%.0+$", "")
	text = string.gsub(text, "(%..-)0+$", "%1")
	return text .. SUFFIXES[tier + 1]
end

return NumberFormat
