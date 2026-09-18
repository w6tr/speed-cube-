--!strict
--[[
	Look.luau -- the lighting rig.

	Speed Cube is played indoors at night. The sun is under the horizon,
	the hall is lit by the lamps Arena.luau hangs over each station, and
	the brightest thing on any screen is meant to be the cube. That is
	what makes a Neon sticker read as glowing rather than as a pale part.

	Every number is in Config.Look.

	TWO PLACES, on purpose:
	  * default.project.json sets Lighting for STUDIO'S EDIT VIEW (and
	    Technology, which a script may neither assign nor read).
	  * this file sets it again at run time, and is the last word.
	Keep them roughly in step or the hall will look wrong while you build
	it and right while you play it.

	Running this twice is safe: the post-processing effects are replaced,
	never stacked.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Look = {}

--[[
	Throw away anything of `className` already sitting in Lighting (a
	leftover from a previous run, or from somebody's Studio session) and
	return a fresh one.
]]
local function fresh(className: string): Instance
	for _, child in Lighting:GetChildren() do
		if child:IsA(className) then
			child:Destroy()
		end
	end
	local inst = Instance.new(className)
	inst.Parent = Lighting
	return inst
end

function Look.apply()
	local L = Config.Look

	Lighting.ClockTime = L.ClockTime
	Lighting.Brightness = L.Brightness
	Lighting.Ambient = L.Ambient
	Lighting.OutdoorAmbient = L.OutdoorAmbient
	Lighting.ExposureCompensation = L.ExposureCompensation
	Lighting.EnvironmentDiffuseScale = L.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = L.EnvironmentSpecularScale
	Lighting.GlobalShadows = true
	-- Atmosphere does the distance fade; the old fog would fight it.
	Lighting.FogEnd = 100000

	-- Haze. Without it the far side of the hall is cardboard in a void;
	-- with it, distance washes out and the room has depth.
	local air = fresh("Atmosphere") :: Atmosphere
	air.Density = L.Atmosphere.Density
	air.Offset = L.Atmosphere.Offset
	air.Color = L.Atmosphere.Color
	air.Decay = L.Atmosphere.Decay
	air.Glare = L.Atmosphere.Glare
	air.Haze = L.Atmosphere.Haze

	-- The workhorse. Threshold sits just under Neon's brightness, so only
	-- the emissive parts bleed and the floor stays matte.
	local bloom = fresh("BloomEffect") :: BloomEffect
	bloom.Intensity = L.Bloom.Intensity
	bloom.Size = L.Bloom.Size
	bloom.Threshold = L.Bloom.Threshold

	local grade = fresh("ColorCorrectionEffect") :: ColorCorrectionEffect
	grade.Brightness = L.Correction.Brightness
	grade.Contrast = L.Correction.Contrast
	grade.Saturation = L.Correction.Saturation
	grade.TintColor = L.Correction.TintColor

	-- Softens the far side of the hall so the eye stays on the cube,
	-- which sits about 8 studs from the camera.
	local dof = fresh("DepthOfFieldEffect") :: DepthOfFieldEffect
	dof.FocusDistance = L.Depth.FocusDistance
	dof.InFocusRadius = L.Depth.InFocusRadius
	dof.FarIntensity = L.Depth.FarIntensity
	dof.NearIntensity = L.Depth.NearIntensity

	-- Lighting.Technology is deliberately absent here. A script may not
	-- write it AND may not read it either: touching it at all throws
	-- "lacking capability RobloxScript". default.project.json is the only
	-- place it can live, so if the hall ever looks flat and unlit, check
	-- Technology in Studio's property panel by hand.
end

return Look
