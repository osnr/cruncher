class window.Equation
    constructor: (@left, @right) ->
        @values = @left.values.concat @right.values

class window.Expression
    constructor: (value) ->
        @values = [value]
        @num = value.num

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
        @values = @values.concat other.values

        @

    toString: ->
        @num.toFixed 2

class window.Value
    constructor: (@num) ->
        if not @num? # free variable
            @num = (x) -> x

    append: (num) ->
        @num = Number(@num + '' + num)
        @

    neg: ->
        @num *= -1
        @

    setLocation: (start, end) ->
        @start = start
        @end = end
        @

    toString: ->
        @num.toFixed 2
