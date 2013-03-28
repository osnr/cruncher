window.Cruncher = Cr = window.Cruncher || {}

$ ->
    Cr.editor = editor = null
    Cr.editor = editor = CodeMirror.fromTextArea $('#code')[0],
        lineNumbers: true
        lineWrapping: true,
        gutters: ['lineState']
        theme: 'cruncher'

    Cr.getFreeMarkedSpans = getFreeMarkedSpans = (line) ->
        handle = editor.getLineHandle line
        if handle.markedSpans?
            return (span for span in handle.markedSpans \
                when span.marker.className == 'free-number')
        else
            return []
    
    parsedLines = []
    reparseLine = (line) ->
        text = editor.getLine line
       
        textToParse = text
        markedPieces = []

        freeMarkedSpans = getFreeMarkedSpans line
        # FIXME work for > 1 mark
        if freeMarkedSpans?[0]
            freeMark = freeMarkedSpans[0]

            markedPieces.push (text.substring 0, freeMark.from)
            markedPieces.push (text.substring freeMark.to, text.length)

            freePlaceholder = (Array freeMark.to - freeMark.from + 1).join ''

            textToParse = markedPieces.join freePlaceholder # horrifying hack

        try
            parsed = parser.parse textToParse
            if parsed?.values?
                value.line = line for value in parsed.values
                parsedLines[line] = parsed

            Cr.unsetLineState line, 'parseError'
            
        catch e
            parsedLines[line] = null

            Cr.setLineState line, 'parseError'

    fixCursor = (oldCursor) ->
        # runs while evaluating and constraining a line
        # returns weakened version of onChange handler that just makes sure
        # user's cursor stays in a sane position while we evalLine

        return (instance, changeObj) ->
            return unless oldCursor.line == changeObj.to.line

            if oldCursor.ch > changeObj.from.ch
                cursorOffset = changeObj.text[0].length - (changeObj.to.ch - changeObj.from.ch)
                editor.setCursor
                    line: oldCursor.line
                    ch: oldCursor.ch + cursorOffset

            else
                editor.setCursor oldCursor
            
    markAsFree = (from, to) ->
        editor.markText from, to,
            className: 'free-number'
            inclusiveLeft: false
            inclusiveRight: false
            atomic: true

    Cr.evalLine = evalLine = (line) ->
        # runs after a line changes
        # (except, of course, when evalLine is the changer)
        # reconstrain the free variable(s) [currently only 1 is supported]
        # so that the equation is true,
        # or make the line an equation

        reparseLine line

        Cr.unsetLineState line, stateName for stateName in \
            ['overDetermined', 'underDetermined']
        
        editor.off 'change', onChange
        fixOnChange = fixCursor editor.getCursor()
        editor.on 'change', fixOnChange

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
            freeMarkedSpans = getFreeMarkedSpans line
            
            # search for free variables that we can change to keep the equality constraint
            if freeMarkedSpans?.length < 1
                Cr.setLineState line, 'overDetermined'

            else if freeMarkedSpans?.length == 1
                [leftF, rightF] = for val in [parsed.left, parsed.right]
                    do (val) -> if typeof val.num == 'function' then val.num else (x) -> val.num

                try
                    solution = (numeric.uncmin ((x) -> (Math.pow (leftF x[0]) - (rightF x[0]), 2)), [1]).solution[0]
                    solutionText = solution.toFixed 2

                    editor.replaceRange solutionText,
                        { line: line, ch: freeMarkedSpans[0].from },
                        { line: line, ch: freeMarkedSpans[0].to }
                    
                    markAsFree { line: line, ch: freeMarkedSpans[0].from },
                        { line: line, ch: freeMarkedSpans[0].from + solutionText.length }

                    reparseLine line
                    
                catch e
                    console.log 'The numeric solver was unable to solve this equation!', e

            else
                Cr.setLineState line, 'underDetermined'

        editor.off 'change', fixOnChange
        editor.on 'change', onChange

    onChange = (instance, changeObj) ->
        # executes on user or cruncher change to text
        # (except during evalLine)
        return if not editor

        line = changeObj.to.line
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
