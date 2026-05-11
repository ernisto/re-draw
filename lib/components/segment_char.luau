--!native

local canvas = require '../canvas'

-- defs
type buff = canvas.canvas
type rgb = vector

local NORTH, EAST, SOUTH, WEST = 1, 2, 4, 8

export type style = { [number]: string }
local SOLID: style = {
	[NORTH] = '╵',
	[SOUTH] = '╷',
	[EAST] = '╶',
	[WEST] = '╴',
	[NORTH + SOUTH] = '│',
	[EAST + WEST] = '─',
	[NORTH + EAST] = '└',
	[NORTH + WEST] = '┘',
	[SOUTH + EAST] = '┌',
	[SOUTH + WEST] = '┐',
	[NORTH + SOUTH + EAST] = '├',
	[NORTH + SOUTH + WEST] = '┤',
	[EAST + WEST + SOUTH] = '┬',
	[EAST + WEST + NORTH] = '┴',
	[NORTH + SOUTH + EAST + WEST] = '┼',
}

local DASHED: style = {
	[NORTH] = '╵',
	[SOUTH] = '╷',
	[EAST] = '╶',
	[WEST] = '╴',
	[NORTH + SOUTH] = '┊',
	[EAST + WEST] = '┄',
	[NORTH + EAST] = '└',
	[NORTH + WEST] = '┘',
	[SOUTH + EAST] = '┌',
	[SOUTH + WEST] = '┐',
	[NORTH + SOUTH + EAST] = '├',
	[NORTH + SOUTH + WEST] = '┤',
	[EAST + WEST + SOUTH] = '┬',
	[EAST + WEST + NORTH] = '┴',
	[NORTH + SOUTH + EAST + WEST] = '┼',
}

local HEAVY: style = {
	[NORTH] = '╹',
	[SOUTH] = '╻',
	[EAST] = '╺',
	[WEST] = '╸',
	[NORTH + SOUTH] = '┃',
	[EAST + WEST] = '━',
	[NORTH + EAST] = '┗',
	[NORTH + WEST] = '┛',
	[SOUTH + EAST] = '┏',
	[SOUTH + WEST] = '┓',
	[NORTH + SOUTH + EAST] = '┣',
	[NORTH + SOUTH + WEST] = '┫',
	[EAST + WEST + SOUTH] = '┳',
	[EAST + WEST + NORTH] = '┻',
	[NORTH + SOUTH + EAST + WEST] = '╋',
}

local DOUBLE: style = {
	[NORTH] = '║',
	[SOUTH] = '║',
	[EAST] = '═',
	[WEST] = '═',
	[NORTH + SOUTH] = '║',
	[EAST + WEST] = '═',
	[NORTH + EAST] = '╚',
	[NORTH + WEST] = '╝',
	[SOUTH + EAST] = '╔',
	[SOUTH + WEST] = '╗',
	[NORTH + SOUTH + EAST] = '╠',
	[NORTH + SOUTH + WEST] = '╣',
	[EAST + WEST + SOUTH] = '╦',
	[EAST + WEST + NORTH] = '╩',
	[NORTH + SOUTH + EAST + WEST] = '╬',
}

local states: { [buff]: seg_state } = setmetatable({}, { __mode = 'k' }) :: any
type seg_state = { bits: buffer, z: buffer }

-- functions
local function ensure_state(buf: buff): seg_state
	local cached = states[buf]
	if cached then return cached end

	local count = buf.width * buf.height
	local fresh = {
		bits = buffer.create(count),
		z = buffer.create(count),
	}
	states[buf] = fresh
	return fresh
end

local function put_char(buf: buff, pos: vector, dirs: number, color: rgb?, style: style)
	local col, row, zindex = pos.x, pos.y, pos.z
	if col < 1 or col > buf.width or row < 1 or row > buf.height then return end

	local index = (row - 1) * buf.width + col - 1

	-- z check vs canvas: if cell occupied at higher z, skip
	if buffer.readu8(buf.mode, index) ~= 0 and zindex < buffer.readi8(buf.z, index) then return end

	local state = ensure_state(buf)
	local prev_bits = buffer.readu8(state.bits, index)
	local merge = prev_bits ~= 0 and buffer.readi8(state.z, index) == zindex
	local bits = if merge then bit32.bor(prev_bits, dirs) else dirs

	buffer.writeu8(state.bits, index, bits)
	buffer.writei8(state.z, index, zindex)

	local char = style[bits] or error(`no glyph for bits {bits}`)
	canvas.put(buf, pos, char, color)
end

-- module
return table.freeze {
	style = { SOLID = SOLID, DASHED = DASHED, HEAVY = HEAVY, DOUBLE = DOUBLE },
	dir = { NORTH = NORTH, EAST = EAST, SOUTH = SOUTH, WEST = WEST },
	put = put_char,
}
