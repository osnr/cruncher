window.Cruncher = Cr = window.Cruncher || {}

class Cr.OverDeterminedException

class Cr.UnderDeterminedException

class Cr.SolveException

class Cr.Equation
    constructor: (@left, @right) ->
        @values = @left.values.concat @right.values

    substitute: (oldValue, newNum) ->
        newValue = new Cr.Value newNum
        new Cr.Equation (@left.substitute oldValue, newValue),
            (@right.substitute oldValue, newValue)

    solve: =>
        # returns [free value, solution]
        freeValues = (value for value in @values \
            when typeof value.num == 'function')

        if freeValues?.length < 1
            throw new Cr.OverDeterminedException

        else if freeValues?.length == 1
            [leftF, rightF] = for side in [@left, @right]
                do (side) ->
                    if typeof side.num == 'function'
                        side.num
                    else
                        (x) -> side.num

            try
                solution = Cr.newtonsMethod ((x) ->
                        (leftF x) - (rightF x)),
                        1
                return [freeValues[0], solution]

            catch e
                console.log e.stack
                throw new Cr.SolveException

        else
            throw new Cr.UnderDeterminedException

class Cr.Expression
    constructor: (value, ops) ->
        @values = [value]
        @num = value.num
        @ops = []

        ops ?= []
        for [op, other] in ops
            @op op, other

    substitute: (oldValue, newValue) ->
        if @values[0] == oldValue
            new Cr.Expression newValue, @ops
        else
            newOps = ([op, (other.substitute oldValue, newValue)] for [op, other] in @ops)
            new Cr.Expression @values[0], newOps

    doBaseOp = (op, left, right) ->
        switch op
            when 'PLUS'
                return left + right
            when 'MINUS'
                return left - right
            when 'DIV'
                return left / right
            when 'MUL'
                return left * right
            when 'POW'
                return Math.pow left, right

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
        @ops.push [op, other]

        @num = doOp op, @num, other.num
        @values = @values.concat other.values

        @

    numString: -> # error if free number expression
        @num.toString()

class Cr.Value
    constructor: (@num) ->
        if not @num? # free number
            @num = (x) -> x

    neg: ->
        @num *= -1
        @

    setLocation: (start, end) ->
        @start = start
        @end = end
        @

    numString: -> # error if free number
        @num.toString()
