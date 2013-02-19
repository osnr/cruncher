$ ->
    window.Cruncher ||= {}

    $editor = $ '#editor'
    
    ($ '#editor').keypress (event) ->
        console.log rangy.getSelection()
        console.log String.fromCharCode(event.which)

    highlightRange = (range) ->
        range = range.cloneRange()
        
        tokens = Cruncher.tokenize $.trim range.toString()

        range.deleteContents()

        $line = $ '<p></p>'
        
        if tokens.length == 0
            range.insertNode ($ '<br></br>')[0]

        range.surroundContents $line[0]
                
        for token in tokens
            ($ '<span></span>')
                .text(token.text)
                .addClass(token.id)
                .appendTo $line

        range
    
    evalEditor = ->
        # assumes #editor contains all plain text
        textNode = $editor.contents()[0]

        range = rangy.createRange()
        range.setStart textNode
        loop
            endIndex = textNode.data.indexOf('\n', 1)
            if endIndex == -1
                endIndex = textNode.data.length

            range.setEnd textNode, endIndex

            range = highlightRange range

            console.log range.toHtml()
            range.collapse false

            textNode = $(range.startContainer).contents()[range.startOffset]

            break if textNode.data.length <= 0
            
            range.setStart textNode

    evalEditor()
    
    lineFreeRanges = []

    onEnter = ->
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
        
    updateFreeRanges = (from, to) ->
        unlockedRange = lineFreeRanges[from.line]
        return unless unlockedRange and
            unlockedRange.start <= from.ch < unlockedRange.end

        console.log 'you edited an unlocked region'
    
    evalLine = (line) ->
        editor.off 'change', onChange
        oldCursor = editor.getCursor()

        text = editor.getLine(line)
        try
            parsed = parser.parse(text)
        catch e
            parsed = null

        if parsed?.constructor == Value
            equationString = text + ' = '
            
            lineFreeRanges[line] = [
                start: equationString.length
                end: equationString.length + parsed.toString().length
            ]
            
            equationString += parsed.toString()
            
            editor.setLine line, equationString
            
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

        updateFreeRanges changeObj.from, changeObj.to
        
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

    endHover = ->
        ($ '.number-widget').fadeOut 200, ->
            ($ '.hovering-number').removeClass('hovering-number')
            ($ this).remove()

    showNumberWidget = (token, pos) ->
        ($ '.number-widget').remove()
        
        $numberWidget = $ '<div class="number-widget"><a id="link"><i class="icon-link"></i></a><a id="lock"><i class="icon-lock"></i></a></div>'
        
        editor.addWidget(
            line: pos.line
            ch: token.start,
            $numberWidget[0]
        )

        ($ '.hovering-number').mouseleave endHover

        $numberWidget #.width(($ this).width())
            .offset (index, coords) ->
                top: coords.top + 12
                left: coords.left
            .mouseenter ->
                console.log 'enter'
                ($ '.hovering-number').unbind('mouseleave')

                ($ '.number-widget')
                    .stop(true)
                    .animate(opacity: 100)
                    .mouseleave endHover
            
            .on 'click', '#lock', ->
                ($ this)
                    .attr('id', 'unlock')
                    .find('i')
                        .removeClass('icon-lock')
                        .addClass 'icon-unlock'

                ($ '.hovering-number').addClass 'unlocked-number'
                lineFreeRanges[pos.line]?.push(token) or
                    lineFreeRanges[pos.line] = [token]
                console.log lineFreeRanges
                
            .on 'click', '#unlock', ->
                ($ this)
                    .attr('id', 'lock')
                    .find('i')
                        .removeClass('icon-unlock')
                        .addClass 'icon-lock'

    draggingState = null

    ($ document).on('mouseenter', '.number', (enterEvent) ->
        if draggingState? then return

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
            ($ '.hovering-number').removeClass 'hovering-number'
            
            ($ '.number-widget').stop(true)

            ($ this).addClass 'hovering-number'
            
            showNumberWidget hoverToken, hoverPos
        
    ).on 'mousedown', '.number', (downEvent) ->
        ($ this).addClass 'dragging-number'
        ($ '.number-widget').remove()

        draggingState = dr = {}
        
        dr.origin = editor.getCursor()
        
        token = nearestNumberToken dr.origin
        
        dr.value = Number(token.string)
        dr.fixedDigits = token.string.split('.')[1]?.length ? 0
        
        dr.start = line: dr.origin.line, ch: token.start
        dr.end = line: dr.origin.line, ch: token.end
                
        ($ document).mousemove((moveEvent) =>
            editor.setCursor dr.start # disable selection
            
            xOffset = moveEvent.pageX - downEvent.pageX
            dr.value += xOffset / 5

            valueString = dr.value.toFixed dr.fixedDigits
            editor.replaceRange valueString, dr.start, dr.end

            dr.end.ch = dr.start.ch + valueString.length
        ).mouseup =>
            ($ '.dragging-number').removeClass 'dragging-number'

            ($ document).unbind('mousemove')
                .unbind 'mouseup'

            draggingState = null
            
            editor.setCursor dr.origin

    editor.refresh()

    evalLine line for line in [0..editor.lineCount() - 1]

