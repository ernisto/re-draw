local ansi = require '@self/ansi'
local area = require '@self/area'
local geometry = require '@self/components/geometry'
local luau_code = require '@self/components/luau_code'
local segment_char = require '@self/components/segment_char'
local text = require '@self/components/text'

local canvas = require '@self/canvas'
export type canvas = canvas.canvas

local layout_tabl = require '@self/components/table'
export type layout_table_cell = layout_tabl.cell

local area_chart = require '@self/components/area_chart'
export type chart_sequence = area_chart.sequence

-- module
return table.freeze {
	canvas = canvas.create,
	area = area.new,
	ansi = ansi,

	style = segment_char.style,
	luau_code = luau_code.highlight,
	pixel = canvas.pixel,
	print = canvas.emit,
	text = text,
	line = geometry.line,
	box = geometry.box,

	layout = table.freeze { table = layout_tabl.print },
	chart = table.freeze { area = area_chart.print },
	oklch = require '@self/oklch',
}
