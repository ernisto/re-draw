local ansi = require '../ansi'
local RESET = ansi.RESET

-- defs
export type cell = { text: string, ansi: string? }
export type col = { align: 'left' | 'right' }
export type opts = {
	padding: number,
	cols: { col },
	rows: { { cell } },
}

-- functions
local function format_cell(cell: cell, width: number, align: 'left' | 'right'): string
	local fmt = if align == 'right' then `%{width}s` else `%-{width}s`
	local pad = string.format(fmt, cell.text)
	return if cell.ansi then cell.ansi .. pad .. RESET else pad
end

local function print_table(opts: opts)
	local widths = table.create(#opts.cols, 0)
	for _, row in opts.rows do
		for index, cell in row do
			if #cell.text > widths[index] then widths[index] = #cell.text end
		end
	end

	local sep = string.rep(' ', opts.padding)
	for _, row in opts.rows do
		local parts = table.create(#row)
		for index, cell in row do
			parts[index] = format_cell(cell, widths[index], opts.cols[index].align)
		end
		print(table.concat(parts, sep))
	end
end

-- module
return table.freeze { print = print_table }
