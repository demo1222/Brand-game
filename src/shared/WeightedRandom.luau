--!strict
-- Weighted random pick (Master Plan §20.5). Pure module; unit-tested in tests/.

local WeightedRandom = {}

export type Entry<T> = { item: T, weight: number }

function WeightedRandom.pick<T>(entries: { Entry<T> }, rng: Random): T
	local total = 0
	for _, e in entries do
		if e.weight > 0 then
			total += e.weight
		end
	end
	local roll = rng:NextNumber() * total
	for _, e in entries do
		if e.weight > 0 then
			roll -= e.weight
			if roll <= 0 then
				return e.item
			end
		end
	end
	return entries[#entries].item
end

-- Convert a {[name] = weight} map into an ordered entry list using `order` (stable odds display).
function WeightedRandom.fromMap(map: { [string]: number }, order: { string }): { Entry<string> }
	local out = {}
	for _, name in order do
		local w = map[name]
		if w and w > 0 then
			table.insert(out, { item = name, weight = w })
		end
	end
	return out
end

-- Normalised percentages for odds display (§16: displayed odds must match the roll table).
function WeightedRandom.percentages<T>(entries: { Entry<T> }): { { item: T, percent: number } }
	local total = 0
	for _, e in entries do
		total += math.max(e.weight, 0)
	end
	local out = {}
	for _, e in entries do
		table.insert(out, { item = e.item, percent = if total > 0 then math.max(e.weight, 0) / total * 100 else 0 })
	end
	return out
end

return WeightedRandom
