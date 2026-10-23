-- Format.luau — تنسيق الأرقام الكبيرة كما في اللعبة الأصلية:
-- K / M / B / T / Qa / Qi (لا Zillion في الأصلية).
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Format.num(n: number): string
	if n ~= n then
		return "0"
	end
	if n < 0 then
		return "-" .. Format.num(-n)
	end
	if n < 1000 then
		if n % 1 == 0 then
			return string.format("%d", n)
		end
		return string.format("%.1f", n)
	end
	local tier = math.floor(math.log10(n) / 3)
	if tier > #SUFFIXES - 1 then
		tier = #SUFFIXES - 1
	end
	local scaled = n / (10 ^ (tier * 3))
	local text
	if scaled >= 100 then
		text = string.format("%d", math.floor(scaled))
	elseif scaled % 1 == 0 then
		text = string.format("%d", scaled)
	else
		text = string.format("%.1f", scaled)
		if string.sub(text, -2) == ".0" then
			text = string.sub(text, 1, -3)
		end
	end
	return text .. SUFFIXES[tier + 1]
end

return Format
