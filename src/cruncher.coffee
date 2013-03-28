window.Cruncher = Cr = window.Cruncher || {}

$ ->
    Cr.editor = editor = null
    Cr.editor = editor = CodeMirror.fromTextArea $('#code')[0],
        lineNumbers: true
        lineWrapping: true,
        gutters: ['lineState']
        theme: 'cruncher'

    getFreeMarkSpans = (line) ->
        handle = editor.getLineHandle line
        if handle.markedSpans?
            (span for span in handle.markedSpans \
                when span.marker.className == 'free-number')
        else
            []
    
    Cr.parsedLines = parsedLines = []
    reparseLine = (line) ->
        text = editor.getLine line
       
        textToParse = text

        spans = getFreeMarkSpans line
        for span in spans
            textToParse = (textToParse.substring 0, span.from) +
                ((Array span.to - span.from + 1).join '') + # horrifying hack
                (textToParse.substring span.to)

        try
            parsed = parser.parse textToParse
            if parsed?.values?
                value.line = line for value in parsed.values
                parsedLines[line] = parsed

            Cr.unsetLineState line, 'parseError'
            
        catch e
            console.log textToParse
            parsedLines[line] = null
            Cr.setLineState line, 'parseError'

    markAsFree = (from, to) ->
        editor.markText from, to,
            className: 'free-number'
            inclusiveLeft: false
            inclusiveRight: false
            atomic: true

    oldCursor = null
    solveChange = (instance, changeObj) ->
        # runs while evaluating and constraining a line
        # returns weakened version of onChange handler that just makes sure
        # user's cursor stays in a sane position while we evalLine

        if changeObj.to.line == oldCursor.line and oldCursor.ch > changeObj.from.ch
            cursorOffset = changeObj.text[0].length - (changeObj.to.ch - changeObj.from.ch)
            editor.setCursor
                line: oldCursor.line
                ch: oldCursor.ch + cursorOffset

        else
            editor.setCursor oldCursor

    evaluatingLines = []
    Cr.evalLine = evalLine = (line) ->
        # runs after a line changes
        # (except, of course, when evalLine is the changer)
        # reconstrain the free variable(s) [currently only 1 is supported]
        # so that the equation is true,
        # or make the line an equation

        reparseLine line

        Cr.unsetLineState line, stateName for stateName in \
            ['overDetermined', 'underDetermined']
        
        # intercept change events for this line,
        # but pass other lines (which might be dependencies)
        # through to the normal handler
        evaluatingLines[line] = true
        oldCursor = editor.getCursor()

        text = editor.getLine line
        parsed = parsedLines[line]
        if parsed?.constructor == Cr.Expression # edited a line without another side (yet)
            freeString = parsed.toString()

            from =
                line: line
                ch: text.length + ' = '.length
            to =
                line: line
                ch: text.length + ' = '.length + freeString.length

            editor.replaceRange ' = ' + freeString, from, from

            markAsFree from, to

            reparseLine line
            
        else if parsed?.constructor == Cr.Equation
            freeValues = (value for value in parsed.values when typeof value.num == 'function')
            console.log 'freeValues', freeValues
            # search for free variables that we can change to keep the equality constraint
            if freeValues?.length < 1
                Cr.setLineState line, 'overDetermined'

            else if freeValues?.length == 1
                [leftF, rightF] = for val in [parsed.left, parsed.right]
                    do (val) -> if typeof val.num == 'function' then val.num else (x) -> val.num

                try
                    solution = (numeric.uncmin ((x) -> (Math.pow (leftF x[0]) - (rightF x[0]), 2)), [1]).solution[0]
                    solutionText = solution.toFixed 2

                    editor.replaceRange solutionText, (Cr.valueFrom freeValues[0]), (Cr.valueTo freeValues[0])

                    markAsFree (Cr.valueFrom freeValues[0]),
                        { line: line, ch: freeValues[0].start + solutionText.length }
                    reparseLine line
                    
                catch e
                    console.log 'The numeric solver was unable to solve this equation!', e.stack, JSON.stringify e

            else
                Cr.setLineState line, 'underDetermined'

        evaluatingLines[line] = false

    onChange = (instance, changeObj) ->
        # executes on user or cruncher change to text
        # (except during evalLine)
        return if not editor

        line = changeObj.to.line
        if evaluatingLines[line]
            solveChange instance, changeObj
        else
            evalLine line

        Cr.updateConnectionsForChange changeObj
    
    editor.on 'change', onChange

    Cr.nearestValue = nearestValue = (pos) ->
        # find nearest number (Value) to pos = { line, ch }
        # used for identifying hover/drag target

        parsed = parsedLines[pos.line]
        return unless parsed? and
            pos.ch < (editor.getLine pos.line).length

        nearest = null
        for value in parsed.values
            if value.start <= pos.ch <= value.end
                nearest = value
                break

        return nearest

    Cr.valueFrom = (value) ->
        { line: value.line, ch: value.start }

    Cr.valueTo = (value) ->
        { line: value.line, ch: value.end }
    
    Cr.valueString = (value) ->
        editor.getRange (Cr.valueFrom value), (Cr.valueTo value)
    
    ($ document).on 'mouseenter', '.cm-number', Cr.startHover

    editor.refresh()

    for line in [0..editor.lineCount() - 1]
        evalLine line
