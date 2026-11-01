-- World layout (Master Plan §6 server layout). The graybox world is generated at runtime by
-- WorldService so the repo is playable without a place file; swap in real art later.

return {
	WaterSurfaceY = 0,
	OceanRadius = 520, -- horizontal half-size of the dive volume
	SeabedDepth = 2260,
	DockCount = 16,
	DockRingRadius = 300,
	DockSize = Vector3.new(56, 2, 44),
	DockHeight = 6, -- top of the dock above the water surface
	PlazaRadius = 70,
	MaxStands = 34, -- 6 base + 24 upgrades + 4 pass
	StandSpacing = 7,
	AirPocketsPerZone = { [3] = 3, [4] = 3, [5] = 2 },
}
