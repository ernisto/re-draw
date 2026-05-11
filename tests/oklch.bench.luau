--!native

local oklch = require '../lib/oklch'

-- fixtures
local rgb_red = vector.create(255, 64, 32)
local rgb_blue = vector.create(32, 96, 220)
local linear_sample = oklch.rgb_to_linear(rgb_red)
local lms_sample = oklch.linear_to_lms(linear_sample)
local lab_sample = oklch.lms_to_oklab(lms_sample)
local lch_red = oklch.oklab_to_oklch(lab_sample)

-- module
return table.freeze {
	['srgb_to_linear_channel'] = function()
		oklch.srgb_to_linear_channel(0.5)
	end,
	['linear_to_srgb_channel'] = function()
		oklch.linear_to_srgb_channel(0.5)
	end,

	['rgb_to_linear'] = function()
		oklch.rgb_to_linear(rgb_red)
	end,
	['linear_to_rgb'] = function()
		oklch.linear_to_rgb(linear_sample)
	end,

	['linear_to_lms'] = function()
		oklch.linear_to_lms(linear_sample)
	end,
	['lms_to_linear'] = function()
		oklch.lms_to_linear(lms_sample)
	end,

	['lms_to_oklab'] = function()
		oklch.lms_to_oklab(lms_sample)
	end,
	['oklab_to_lms'] = function()
		oklch.oklab_to_lms(lab_sample)
	end,

	['oklab_to_oklch'] = function()
		oklch.oklab_to_oklch(lab_sample)
	end,
	['oklch_to_oklab'] = function()
		oklch.oklch_to_oklab(lch_red)
	end,

	['rgb_to_oklch'] = function()
		oklch.rgb_to_oklch(rgb_red)
	end,
	['oklch_to_rgb'] = function()
		oklch.oklch_to_rgb(lch_red)
	end,

	['mix t=0.5'] = function()
		oklch.lerp(rgb_red, rgb_blue, 0.5)
	end,

	['palette 16'] = function()
		oklch.palette(16)
	end,
	['palette 64'] = function()
		oklch.palette(64)
	end,
	['palette 256'] = function()
		oklch.palette(256)
	end,
}
