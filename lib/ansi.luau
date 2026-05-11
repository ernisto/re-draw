--!native

-- defs
type rgb = vector

local RESET = '\27[0m'
local BOLD = '\27[1m'
local DIM = '\27[2m'
local ITALIC = '\27[3m'
local UNDERLINE = '\27[4m'
local NORMAL = '\27[22m'
local DEFAULT_FG = '\27[39m'
local DEFAULT_BG = '\27[49m'

local BLACK = '\27[30m'
local RED = '\27[31m'
local GREEN = '\27[32m'
local YELLOW = '\27[33m'
local BLUE = '\27[34m'
local MAGENTA = '\27[35m'
local CYAN = '\27[36m'
local WHITE = '\27[37m'

local GREY = '\27[90m'
local BRIGHT_RED = '\27[91m'
local BRIGHT_GREEN = '\27[92m'
local BRIGHT_YELLOW = '\27[93m'
local BRIGHT_BLUE = '\27[94m'
local BRIGHT_MAGENTA = '\27[95m'
local BRIGHT_CYAN = '\27[96m'
local BRIGHT_WHITE = '\27[97m'

local fg_cache: { [vector]: string } = {}
local bg_cache: { [vector]: string } = {}

local rgb_lookup: { [string]: rgb } = {
	[BLACK] = vector.create(0, 0, 0),
	[RED] = vector.create(170, 0, 0),
	[GREEN] = vector.create(0, 170, 0),
	[YELLOW] = vector.create(170, 85, 0),
	[BLUE] = vector.create(0, 0, 170),
	[MAGENTA] = vector.create(170, 0, 170),
	[CYAN] = vector.create(0, 170, 170),
	[WHITE] = vector.create(170, 170, 170),

	[GREY] = vector.create(85, 85, 85),
	[BRIGHT_RED] = vector.create(255, 85, 85),
	[BRIGHT_GREEN] = vector.create(85, 255, 85),
	[BRIGHT_YELLOW] = vector.create(255, 255, 85),
	[BRIGHT_BLUE] = vector.create(85, 85, 255),
	[BRIGHT_MAGENTA] = vector.create(255, 85, 255),
	[BRIGHT_CYAN] = vector.create(85, 255, 255),
	[BRIGHT_WHITE] = vector.create(255, 255, 255),
}

-- functions
local function to_rgb(code: string): rgb
	local named = rgb_lookup[code]
	if named then return named end

	local r, g, b = string.match(code, '\27%[[34]8;2;(%d+);(%d+);(%d+)m')
	assert(r and g and b, `unsupported ansi code: {code}`)

	return vector.create(tonumber(r) :: number, tonumber(g) :: number, tonumber(b) :: number)
end

local function foreground(rgb: rgb): string
	local cached = fg_cache[rgb]
	if cached then return cached end

	local code = string.format('\27[38;2;%d;%d;%dm', math.floor(rgb.x), math.floor(rgb.y), math.floor(rgb.z))
	fg_cache[rgb] = code
	return code
end

local function background(rgb: rgb): string
	local cached = bg_cache[rgb]
	if cached then return cached end

	local code = string.format('\27[48;2;%d;%d;%dm', math.floor(rgb.x), math.floor(rgb.y), math.floor(rgb.z))
	bg_cache[rgb] = code
	return code
end

-- module
return table.freeze {
	RESET = RESET,
	BOLD = BOLD,
	DIM = DIM,
	ITALIC = ITALIC,
	UNDERLINE = UNDERLINE,
	NORMAL = NORMAL,
	DEFAULT_FG = DEFAULT_FG,
	DEFAULT_BG = DEFAULT_BG,

	BLACK = BLACK,
	RED = RED,
	GREEN = GREEN,
	YELLOW = YELLOW,
	BLUE = BLUE,
	MAGENTA = MAGENTA,
	CYAN = CYAN,
	WHITE = WHITE,

	GREY = GREY,
	BRIGHT_RED = BRIGHT_RED,
	BRIGHT_GREEN = BRIGHT_GREEN,
	BRIGHT_YELLOW = BRIGHT_YELLOW,
	BRIGHT_BLUE = BRIGHT_BLUE,
	BRIGHT_MAGENTA = BRIGHT_MAGENTA,
	BRIGHT_CYAN = BRIGHT_CYAN,
	BRIGHT_WHITE = BRIGHT_WHITE,

	foreground = foreground,
	background = background,
	to_rgb = to_rgb,
}
