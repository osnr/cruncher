class window.Equation
    constructor: (@left, @right) ->

class window.Value
    constructor: (@num) ->
        @currency = null
        @percentage = false
        if not @num? # free variable
            @num = (x) -> x

    doBaseOp = (op, left, right) ->
        switch op
            when ''
                return Number(left + '' + right)
            when 'PLUS'
                return left + right
            when 'MINUS'
                return left - right
            when 'DIV'
                return left / right
            when 'MUL'
                return left * right
            when 'POW'
                return Math.pow(left, right)
            when 'PCT_OFF'
                return (1 - left / 100) * right

    doOp = (op, left, right) ->
        if typeof left == 'number'
            if typeof right == 'number' # left and right both numbers
                return doBaseOp op, left, right
            else if typeof right == 'function' # left number, right free
                return (x) -> doOp op, left, (right x)

        else if typeof left == 'function'
            if typeof right == 'number' # left free, right number
                return (x) -> doOp op, (left x), right
            else if typeof right == 'function' # left free, right free
                return (x) -> (y) -> doOp op, (left x), (right y)

    op: (op, other) ->
        @num = doOp op, @num, other.num

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
