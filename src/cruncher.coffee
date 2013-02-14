$ ->
    window.editor = editor = null
    window.editor = editor = CodeMirror.fromTextArea $('#code')[0],
        lineNumbers: true
        lineWrapping: true

    CodeMirror.keyMap.default['Enter'] = ->
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

        evalLine cursor.line + 1        

    lineFreeNumbers = []
    
    draggingState = null
    
    evalLine = (line) ->
        editor.off 'change', onChange
        oldCursor = editor.getCursor()

        text = editor.getLine(line)
        try
            parsed = parser.parse(text)
        catch e
            parsed = null

        if parsed?.constructor == Value
            editor.setLine line, text + ' = ' + parsed.toString()
            
        else if parsed?.constructor == Equation
            textSides = text.split('=')
            if oldCursor.ch < text.indexOf('=')
                editor.setLine line, textSides[0] + '= ' + parsed.left.toString()
            else
                editor.setLine line, parsed.right.toString() + ' =' + textSides[1]

                cursorOffset = -textSides[0].length + parsed.right.toString().length + 1
                oldCursor.ch = oldCursor.ch + cursorOffset
                
                # TODO put this somewhere else so drag logic isn't mixed with eval logic
                if draggingState?
                    draggingState.start.ch += cursorOffset
                    draggingState.end.ch += cursorOffset

        editor.setCursor oldCursor
        editor.on 'change', onChange

    onChange = (instance, changeObj) ->
        return if not editor

        line = changeObj.to.line
        evalLine line
    
    editor.on 'change', onChange

    nearestNumberToken = (pos) ->
        token = editor.getTokenAt pos

        if token.type != 'number'
            pos.ch += 1
            token = editor.getTokenAt pos

        if token.type != 'number'
            return null

        return token

    showNumberWidget = (token, pos) ->
        $('.number-widget').remove()
        
        $numberWidget = $('<div class="number-widget"><a class="icon-link"></a><a class="icon-lock"></a></div>')

        editor.addWidget(
            line: pos.line
            ch: token.start,
            $numberWidget[0]
        )

        $('.hovering-number').mouseleave ->
            $('.number-widget').fadeOut 200, ->
                $(this).remove()

        $numberWidget #.width($(this).width())
            .offset (index, coords) ->
                top: coords.top + 12
                left: coords.left
            .mouseenter ->
                console.log 'enter'
                $('.hovering-number').unbind 'mouseleave'

                $('.number-widget')
                    .stop(true)
                    .animate(opacity: 100)
                    .mouseleave ->
                        $('.number-widget').fadeOut 200, ->
                            $(this).remove()
        
    $(document).on('mouseenter', '.cm-number', (enterEvent) ->
        if draggingState? then return
        
        $(this).addClass 'hovering-number'
        hoverPos = editor.coordsChar(
            left: enterEvent.pageX,
            top: enterEvent.pageY
        )

        hoverToken = nearestNumberToken hoverPos

        if not hoverToken?
            hoverPos = editor.coordsChar(
                left: enterEvent.pageX,
                top: enterEvent.pageY + 2 # ugly hack because coordsChar's hit box doesn't quite line up with the DOM hover hit box
            )
            hoverToken = nearestNumberToken hoverPos
        
        console.log hoverToken

        if hoverToken?
            showNumberWidget hoverToken, hoverPos
        
    ).on('mouseleave', '.cm-number', ->
        $(this).removeClass 'hovering-number'

    ).on 'mousedown', '.cm-number', (downEvent) ->
        $(this).addClass 'dragging-number'
        $('.number-widget').remove()

        draggingState = dr = {}
        
        dr.origin = editor.getCursor()
        
        token = nearestNumberToken dr.origin
        
        dr.value = Number(token.string)
        dr.fixedDigits = token.string.split('.')[1]?.length ? 0
        
        dr.start = line: dr.origin.line, ch: token.start
        dr.end = line: dr.origin.line, ch: token.end
                
        $(document).mousemove((moveEvent) =>
            editor.setCursor dr.start # disable selection
            
            xOffset = moveEvent.pageX - downEvent.pageX
            dr.value += xOffset / 5

            valueString = dr.value.toFixed dr.fixedDigits
            editor.replaceRange valueString, dr.start, dr.end

            dr.end.ch = dr.start.ch + valueString.length
        ).mouseup =>
            $('.dragging-number').removeClass 'dragging-number'

            $(document).unbind('mousemove')
                .unbind 'mouseup'

            draggingState = null
            
            editor.setCursor dr.origin

    editor.refresh()

    evalLine line for line in [0..editor.lineCount() - 1]

