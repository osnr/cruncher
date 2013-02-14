class window.Equation
    constructor: (@left, @right) ->

class window.Value
	constructor: (@num) ->
		@currency = null
		@percentage = false

	op: (op, other) ->
		switch op
			when ''
				@num = Number(@num + '' + other.num)
			when 'PLUS'
				@num += other.num
			when 'MINUS'
				@num -= other.num
			when 'DIV'
				@num /= other.num
			when 'MUL'
				@num *= other.num
			when 'POW'
				@num = Math.pow(@num, other.num)
			when 'PCT_OFF'
				@num = (1 - @num / 100) * other.num
		@

	setUnit: (unit) ->
		if unit == '%'
			@percentage = true
		else
			@currency = unit
		@

	toString: ->
		str = ''
		if @currency
			str += @currency
		str += @num.toFixed 2
