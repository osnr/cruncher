$ ->
    window.editor = editor = null
    window.editor = editor = CodeMirror.fromTextArea $('#code')[0],
        lineNumbers: true
        lineWrapping: true,
        theme: 'cruncher'

    CodeMirror.keyMap.default['Enter'] = ->
        # custom handling of Enter key so that if user does: (cursor is |)
        # 2 + 2| = 4
        # 2 + 2[ENTER] = 4
        # the 2 + 2 = 4 all stays on the previous line:
        # 2 + 2 = 4
        # |
        # instead of breaking weirdly and regenerating line 1:
        # 2 + 2 = 4
        # | = 4
        
        cursor = editor.getCursor()
        cursor.ch += 1

        token = editor.getTokenAt cursor
        aroundEquals = token.type == 'equals'

        while token.string != '' and not aroundEquals and token.type == null
            token = editor.getTokenAt
                line: cursor.line
                ch: token.end + 1
            aroundEquals = token.type == 'equals'

        if aroundEquals
            eol =
                line: cursor.line
                ch: editor.getLine(cursor.line).length
            
            editor.replaceRange '\n', eol, eol
            editor.setCursor
                line: cursor.line + 1
                ch: 0
            
        else
            editor.replaceRange '\n', cursor, cursor

        reparseLine cursor.line + 1
        evalLine cursor.line + 1        

    getFreeMarks = (line) ->
        (editor.getLineHandle line).markedSpans
    
    parsedLines = []
    reparseLine = (line) ->
        text = editor.getLine line
       
        textToParse = text
        markedPieces = []

        freeMarks = getFreeMarks line
        # FIXME work for > 1 mark
        if freeMarks?[0]
            freeMark = freeMarks[0]

            markedPieces.push (text.substring 0, freeMark.from)
            markedPieces.push (text.substring freeMark.to, text.length)

            freePlaceholder = (Array freeMark.to - freeMark.from + 1).join ''

            textToParse = markedPieces.join freePlaceholder # horrifying hack

        console.log 'parsing', textToParse            
        try
            parsedLines[line] = parser.parse textToParse
        catch e
            console.log 'parse error', e
            parsedLines[line] = null

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

                # TODO put this somewhere else so drag logic isn't mixed with eval logic
                if draggingState?
                    draggingState.from.ch += cursorOffset
                    draggingState.to.ch += cursorOffset
            else
                editor.setCursor oldCursor
            
            console.log 'editing', oldCursor, changeObj

    evalLine = (line) ->
        # runs after a line changes and it's been reparsed into parsedLines
        # (except, of course, when evalLine is the changer)
        # reconstrain the free variable(s) [currently only 1 is supported]
        # so that the equation is true,
        # or make the line an equation
        
        editor.off 'change', onChange
        fixOnChange = fixCursor editor.getCursor()
        editor.on 'change', fixOnChange

        text = editor.getLine line
        parsed = parsedLines[line]
        if parsed?.constructor == Expression # edited a line without another side (yet)
            freeString = parsed.toString()

            from =
                line: line
                ch: text.length + ' = '.length
            to =
                line: line
                ch: text.length + ' = '.length + freeString.length

            editor.replaceRange ' = ' + freeString, from, from

            editor.markText from, to, { className: 'free-number' }

            reparseLine line
            
        else if parsed?.constructor == Equation
            freeMarks = getFreeMarks line
            
            # search for free variables that we can change to keep the equality constraint
            if freeMarks?.length < 1
                console.log 'This equation cannot be solved! Not enough freedom'

            else if freeMarks?.length == 1
                console.log 'Solvable if you constrain', freeMarks
                [leftF, rightF] = for val in [parsed.left, parsed.right]
                    do (val) -> if typeof val.num == 'function' then val.num else (x) -> val.num

                try
                    window.leftF = leftF; window.rightF = rightF
                    solution = (numeric.uncmin ((x) -> (Math.pow (leftF x[0]) - (rightF x[0]), 2)), [1]).solution[0]
                    solutionText = solution.toFixed 2
                    console.log 'st', solutionText

                    editor.replaceRange solutionText,
                        { line: line, ch: freeMarks[0].from },
                        { line: line, ch: freeMarks[0].to }
                    
                    editor.markText { line: line, ch: freeMarks[0].from },
                        { line: line, ch: freeMarks[0].from + solutionText.length },
                        { className: 'free-number' }

                    reparseLine line
                    
                catch e
                    debugger
                    console.log 'The numeric solver was unable to solve this equation!', e

            else
                console.log 'This equation cannot be solved! Too much freedom', freeMarks

        editor.off 'change', fixOnChange
        editor.on 'change', onChange

    onChange = (instance, changeObj) ->
        # executes on user or cruncher change to text
        # (except during evalLine)
        return if not editor

        line = changeObj.to.line
        reparseLine line
        evalLine line
    
    editor.on 'change', onChange

    nearestValue = (pos) ->
        # find nearest number (Value) to pos = { line, ch }
        # used for identifying hover/drag target

        parsed = parsedLines[pos.line]
        return unless parsed?

        nearest = null
        for value in parsed.values
            if value.start <= pos.ch <= value.end
                nearest = value
                console.log nearest
                break

        return nearest

    draggingState = null

    ($ document).on('mouseenter', '.cm-number', (enterEvent) ->
        # add hover class, construct number widget
        # when user hovers over a number
        
        if draggingState? then return

        hoverPos = editor.coordsChar
            left: enterEvent.pageX
            top: enterEvent.pageY

        hoverValue = nearestValue hoverPos

        if not hoverValue?
            hoverPos = editor.coordsChar
                left: enterEvent.pageX
                top: enterEvent.pageY + 2 # ugly hack because coordsChar's hit box doesn't quite line up with the DOM hover hit box

            hoverValue = nearestValue hoverPos
        
        console.log hoverValue

        if hoverValue?
            ($ '.hovering-number').removeClass 'hovering-number'
            
            ($ '.number-widget').stop(true)

            ($ this).addClass 'hovering-number'
            
            (new NumberWidget hoverValue,
                hoverPos,
                (line) ->
                    reparseLine line
                    evalLine line).show()
        
    ).on 'mousedown', '.cm-number:not(.free-number)', (downEvent) ->
        # initiate and handle dragging/scrubbing behavior
        
        ($ this).addClass 'dragging-number'
        ($ '.number-widget').remove()

        draggingState = dr = {}
        
        dr.origin = editor.getCursor()
        
        value = nearestValue dr.origin
        
        dr.num = value.num
        dr.fixedDigits = value.toString().split('.')[1]?.length ? 0
        
        dr.from = line: dr.origin.line, ch: value.start
        dr.to = line: dr.origin.line, ch: value.end

        xCenter = downEvent.pageX
        
        ($ document).mousemove((moveEvent) =>
            editor.setCursor dr.from # disable selection

            xOffset = moveEvent.pageX - xCenter
            xCenter = moveEvent.pageX
            
            delta = if xOffset >= 2 then 1 else if xOffset <= -2 then -1 else 0
            console.log xOffset / (Math.abs xOffset)

            if delta != 0
                dr.num += delta
                
                numString = dr.num.toFixed dr.fixedDigits
                editor.replaceRange numString, dr.from, dr.to

                dr.to.ch = dr.from.ch + numString.length
        ).mouseup =>
            ($ '.dragging-number').removeClass 'dragging-number'

            ($ document).unbind('mousemove')
                .unbind 'mouseup'

            editor.setCursor dr.origin

            draggingState = dr = null

    editor.refresh()

    for line in [0..editor.lineCount() - 1]
        reparseLine line
        evalLine line
