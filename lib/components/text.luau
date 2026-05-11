--!native

local ansi = require '../ansi'
local canvas = require '../canvas'

-- defs
type rgb = vector
type buff = canvas.canvas

local STYLES: { [string]: string } = {
	bold = ansi.BOLD,
	dim = ansi.DIM,
	italic = ansi.ITALIC,
	underline = ansi.UNDERLINE,
}
export type node = ((buf: buff, def: props) -> ()) & {
	bold: node,
	dim: node,
	italic: node,
	underline: node,
}
export type props = {
	anchor: vector?,
	pos: vector,
	text: string,
	color: rgb?,
}

-- functions
local function styled(attrs: string)
	return function(buf: buff, def: props)
		local pos = def.pos
		local str = def.text
		local color = def.color
		local len = #str

		local anchor = def.anchor or vector.zero
		local col = pos.x - math.round(anchor.x * (len - 1))
		local row = pos.y
		local zindex = pos.z
		if row < 1 or row > buf.height then return end

		local width = buf.width
		local base = (row - 1) * width
		local ansi_str = attrs .. (if color then ansi.foreground(color) else '')

		for index = 1, len do
			local char_col = col + index - 1
			if char_col < 1 or char_col > width then continue end

			local cell_index = base + char_col - 1
			if buffer.readu8(buf.mode, cell_index) ~= 0 and zindex < buffer.readi8(buf.z, cell_index) then continue end

			buffer.writeu8(buf.mode, cell_index, 1)
			buffer.writei8(buf.z, cell_index, zindex)

			buf.chars[cell_index + 1] = string.sub(str, index, index)
			buf.ansis[cell_index + 1] = ansi_str
			buf.top[cell_index + 1] = nil
			buf.bot[cell_index + 1] = nil
		end
	end
end

-- module
local memo: { [string]: node } = {}
local function namespace(attrs: string): node
	local cached = memo[attrs]
	if cached then return cached end

	local fn = styled(attrs)
	local node = setmetatable({}, {
		__call = function(_, buf, def)
			return fn(buf, def)
		end,
		__index = function(_, key)
			local code = STYLES[key]
			return if code then namespace(attrs .. code) else nil
		end,
	}) :: any
	memo[attrs] = node
	return node
end

return namespace ''
