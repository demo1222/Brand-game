--!strict
-- Big-number formatting up to 1e33 (Master Plan §13.4, Appendix B).

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local NumberFormat = {}

function NumberFormat.short(n: number): string
	if n ~= n then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local i = math.floor(math.log10(n) / 3)
	i = math.min(i, #SUFFIXES - 1)
	local v = n / 10 ^ (i * 3)
	-- Guard against 999.95K rounding to "1000K"
	if v >= 999.5 and i < #SUFFIXES - 1 then
		i += 1
		v = n / 10 ^ (i * 3)
	end
	local fmt = if v < 10 then "%.2f%s" elseif v < 100 then "%.1f%s" else "%.0f%s"
	return sign .. string.format(fmt, v, SUFFIXES[i + 1])
end

function NumberFormat.commas(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if n < 0 then "-" else "") .. out
end

function NumberFormat.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

function NumberFormat.percent(p: number): string
	if p >= 1 then
		return string.format("%.1f%%", p)
	elseif p >= 0.01 then
		return string.format("%.2f%%", p)
	end
	return string.format("%.3f%%", p)
end

return NumberFormat
