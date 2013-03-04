$ ->
    window.Cruncher ||= {}

    $editor = $ '#editor'
    
    ($ '#editor').keypress (event) ->
        console.log rangy.getSelection()
        console.log String.fromCharCode(event.which)

    highlightLine = (range) ->
        range = range.cloneRange()
        text = range.toString().replace /\n/g, ''
        
        tokens = Cruncher.tokenize text

        range.deleteContents()

        $line = $('<p></p>').data('text', text)
        
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

            range = highlightLine range

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
    
    evalLine = (node) ->
        text = node.data
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

    onChange = (instance, changeObj) ->
        return if not editor

        updateFreeRanges changeObj.from, changeObj.to
        
        line = changeObj.to.line
        evalLine line
    
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
            ($ this).remove()

        ($ '.hovering-number').removeClass('hovering-number')

    showNumberWidget = (node) ->
        ($ '.number-widget').remove()
        
        $numberWidget = $('<div class="number-widget"><a id="link"><i class="icon-link"></i></a><a id="lock"><i class="icon-lock"></i></a></div>')
            .appendTo node

        ($ '.hovering-number').mouseleave endHover

        $numberWidget #.width(($ this).width())
            .offset ->
                pos = $(node).position()
                top: pos.top + 15
                left: pos.left
            .mouseenter ->
                console.log 'enter'
            
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

        ($ this).addClass 'hovering-number'
            
        showNumberWidget $(this)
        
    ).on 'mousedown', '.number', (downEvent) ->
        ($ this).addClass 'dragging-number'
        ($ '.number-widget').remove()

        draggingState = dr = {}
        $editor.attr('contenteditable', 'false')
            .attr('unselectable', 'on')
            .css 'user-select', 'none'
        
        dr.value = Number $(this).text()
        dr.fixedDigits = $(this).text().split('.')[1]?.length ? 0
        
        ($ document).mousemove((moveEvent) =>
            xOffset = moveEvent.pageX - downEvent.pageX
            dr.value += xOffset / Math.abs(xOffset) #/ 5

            valueString = dr.value.toFixed dr.fixedDigits
            console.log valueString
            ($ this).text valueString
        ).mouseup =>
            ($ '.dragging-number').removeClass 'dragging-number'

            ($ document).unbind('mousemove')
                .unbind 'mouseup'

            draggingState = null
            $editor.attr('contenteditable', 'true')
                .attr('unselectable', '')
                .css 'user-select', ''

    # editor.refresh()

    # evalLine line for line in [0..editor.lineCount() - 1]

