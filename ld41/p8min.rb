#!/usr/bin/env ruby

file = ARGF.read

# nab the code part only

parts = file.split( '__gfx__' )
code = parts[ 0 ]
therest = '__gfx__' << parts[ 1 ]

# remove comments
code.gsub!( /--.*$/, '' )

# remove leading space
code.gsub!( /^\s+/, '' )

# remove spurious space between stuff
code.each_line do |line|
	line.gsub!( /(?=([^']*'[^']*')*[^']*$)([ \t])\s+/, '\2' )
	line.gsub!( /(?=([^']*'[^']*')*[^']*$)([\(=,\)\+\-\*'])[ \t]/, '\2' )
	line.gsub!( /(?=([^']*'[^']*')*[^']*$)[ \t]([\)=\,\~\+\-\*'])/, '\2' )
	print line
end

print therest





























# shrink identifiers
# keywords = [
# 	'for',
# 	'while',
# 	'do',
# 	'function',
# 	'and',
# 	'or',
# 	'if',
# 	'or',
# 	'and',
# 	'not',
# 	'then',
# 	'else',
# 	'elseif',
# 	'end',
# 	'local',
# 	'return',
# 	'add',
# 	'del',
# 	'count',
# 	'setmetatable',
# 	'nil',
# 	'true',
# 	'false',
# 	'assert',
# 	'repeat',
# 	'break',
# 	'until',

# 	'poke',
# 	'stat',
# 	'sub',
# 	'print',
# 	'add',
# 	'all',
# 	'count',
# 	'del',
# 	'foreach',
# 	'pairs',
# 	'_draw',
# 	'_init',
# 	'_update',
# 	'_update60',
# 	'camera',
# 	'circ',
# 	'circfill',
# 	'clip',
# 	'cls',
# 	'color',
# 	'cursor',
# 	'fget',
# 	'flip',
# 	'fset',
# 	'line',
# 	'pal',
# 	'palt',
# 	'pget',
# 	'print',
# 	'pset',
# 	'rect',
# 	'rectfill',
# 	'sget',
# 	'spr',
# 	'sset',
# 	'sspr',
# 	'music',
# 	'sfx',
# 	'cartdata',
# 	'dget',
# 	'dset',
# 	'cocreate',
# 	'coresume',
# 	'costatus',
# 	'yield',
# 	'camera',
# 	'circ',
# 	'circfill',
# 	'clip',
# 	'cls',
# 	'color',
# 	'cursor',
# 	'fget',
# 	'flip',
# 	'fset',
# 	'line',
# 	'pal',
# 	'palt',
# 	'pget',
# 	'print',
# 	'pset',
# 	'rect',
# 	'rectfill',
# 	'sget',
# 	'spr',
# 	'sset',
# 	'sspr',
# 	'btn',
# 	'btnp',
# 	'map',
# 	'mapdraw',
# 	'mget',
# 	'mset',
# 	'abs',
# 	'atan2',
# 	'band',
# 	'bnot',
# 	'bor',
# 	'bxor',
# 	'cos',
# 	'flr',
# 	'max',
# 	'mid',
# 	'min',
# 	'rnd',
# 	'sgn',
# 	'shl',
# 	'shr',
# 	'sin',
# 	'sqrt',
# 	'srand',
# 	'cstore',
# 	'memcpy',
# 	'memset',
# 	'peek',
# 	'poke',
# 	'reload',
# ]
# # things with '__'

# code.each_line do |line|
#     elements = line.split
# end


