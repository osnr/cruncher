window.Cruncher = Cr = window.Cruncher || {}

Cr.VERSION = '2014-02-07'

$ ->
    onEquals = (cm) ->
        cursor = cm.getCursor 'end'

        cm.replaceRange '=', {
            line: cursor.line
            ch: cursor.ch
        }, {
            line: cursor.line
            ch: (cm.getLine cursor.line).length
        }

    Cr.editor = editor = null
    Cr.editor = editor = CodeMirror.fromTextArea $('#code')[0],
        lineNumbers: false
        lineWrapping: true,
        gutters: ['lineState']
        theme: 'cruncher'
        autofocus: true
        extraKeys:
            '=': onEquals

    # There are two extra properties we put on each line handle in CodeMirror.
    #     evaluating: is this line being evaluated?
    #     parsed: parse / evaluation object for the line (Equation or Expression)
    # They're attached to the handle so that they follow the line around if it moves.

    # generate unique ids for text markers
    CodeMirror.TextMarker::toString = do ->
        id = 0
        -> @id ? @id = id++

    CodeMirror.TextMarker::replaceContents = (text, origin) ->
        {from, to} = @.find()
        overlapMarks = editor.findMarksAt from

        incLefts = []
        incRights = []
        for mark in overlapMarks
            incLefts[mark] = mark.inclusiveLeft
            incRights[mark] = mark.inclusiveRight
            mark.inclusiveLeft = true
            mark.inclusiveRight = true

        Cr.editor.replaceRange text, from, to, origin
        for mark in overlapMarks
            mark.inclusiveLeft = incLefts[mark]
            mark.inclusiveRight = incRights[mark]

        @

    reparseLine = (line) ->
        text = editor.getLine line
        handle = editor.getLineHandle line
       
        textToParse = text

        spans = Cr.getFreeMarkedSpans line
        for span in spans
            textToParse = (textToParse.substring 0, span.from) +
                ((Array span.to - span.from + 1).join '') + # horrifying hack
                (textToParse.substring span.to)

        try
            parsed = parser.parse textToParse
            if parsed?.values?
                value.line = line for value in parsed.values
                handle.parsed = parsed
            else
                handle.parsed = null
            
            Cr.unsetLineState line, 'parseError'
            
        catch e
            console.log 'parse error', e, line, textToParse
            handle.parsed = null
            Cr.setLineState line, 'parseError'

            i = 0
            firstToken = null
            while (not firstToken) and (i < text.length)
                firstToken = Cr.editor.getTokenTypeAt { line: line, ch: i }
                i += 1
            if firstToken == 'equals'
                # wipe out the line, they probably deleted the entire left half
                editor.setLine line, ''

    Cr.markAsFree = markAsFree = (from, to) ->
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
        # 
        # e.g. {2} |+ 3 = 5 -> {20} |+ 3 = 5
        #      we shift the cursor right 1 character
        if changeObj.to.line == oldCursor.line and oldCursor.ch > changeObj.from.ch
            cursorOffset = changeObj.text[0].length - (changeObj.to.ch - changeObj.from.ch)
            newCursor =
                line: oldCursor.line
                ch: oldCursor.ch + cursorOffset
            editor.setCursor newCursor
            oldCursor = newCursor

        else
            editor.setCursor oldCursor

    Cr.evalLine = evalLine = (line) ->
        # runs after a line changes
        # (except, of course, when evalLine is the changer)
        # reconstrain the free number(s) [currently only 1 is supported]
        # so that the equation is true,
        # or make the line an equation

        reparseLine line

        Cr.unsetLineState line, stateName for stateName in \
            ['overDetermined', 'underDetermined']

        handle = editor.getLineHandle line
        
        # intercept change events for this line,
        # but pass other lines (which might be dependencies)
        # through to the normal handler
        # TODO deal with circular dependencies (this makes them undefined behavior)
        handle.evaluating = true
        oldCursor = editor.getCursor()

        text = editor.getLine line
        parsed = handle.parsed
        if parsed?.constructor == Cr.Expression # edited a line without another side (yet)
            if typeof parsed.num == 'function'
                # we have an expression with a free number in it
                # just lock it
                mark = (s.marker for s in Cr.getFreeMarkedSpans line)[0]
                mark.clear()

                reparseLine line
                evalLine line
            else
                freeString = parsed.numString()

                from =
                    line: line
                    ch: text.length + ' = '.length
                to =
                    line: line
                    ch: text.length + ' = '.length + freeString.length

                editor.replaceRange ' = ' + freeString, from, null, '+solve'
                markAsFree from, to

                reparseLine line

        else if parsed?.constructor == Cr.Equation
            try
                [freeValue, solution] = parsed.solve()

                mark = (s.marker for s in Cr.getFreeMarkedSpans line)[0]

                oldCursor = editor.getCursor()

                sig = Cr.sig text.substring(0, freeValue.start) +
                    text.substring(freeValue.end)
                mark.replaceContents (Cr.roundSig solution, sig), '+solve'

                editor.setCursor oldCursor

                handle.equalsMark?.clear()
                reparseLine line

            catch e
                if e instanceof Cr.OverDeterminedException
                    Cr.setLineState line, 'overDetermined'
                    Cr.updateSign line, handle
                else if e instanceof Cr.UnderDeterminedException
                    Cr.setLineState line, 'underDetermined'
                else
                    throw e

        handle.evaluating = false

    editor.on 'change', (instance, changeObj) ->
        return if Cr.scr? # don't catch if scrubbing

        for adjustment in editor.doc.adjustments
            do adjustment
        editor.doc.adjustments = []

        if (changeObj.origin == '+solve') and editor.doc.history.done.length >= 2
            # automatic origin -- merge with last change (hack)
            history = editor.doc.history
            lastChange = history.done.pop()
            prevChange = history.done.pop()
            $.merge prevChange.changes, lastChange.changes
            prevChange.headAfter = lastChange.headAfter
            prevChange.anchorAfter = lastChange.anchorAfter
            history.done.push prevChange

        # executes on user or cruncher change to text
        # (except during evalLine)
        if changeObj.removed.length > 1
            lineRange = [changeObj.from.line..Cruncher.editor.lineCount() - 1]
        else
            lineRange = [changeObj.from.line..changeObj.to.line + changeObj.text.length - 1]

        for line in lineRange
            handle = editor.getLineHandle line
            continue unless handle

            if handle.evaluating
                solveChange instance, changeObj
            else
                evalLine line

        # replace all value locations that might be affected by a newline
        if changeObj.text.length > 1
            for line in [changeObj.to.line + 1..editor.lineCount() - 1]
                handle = editor.getLineHandle line
                continue unless handle.parsed?.values?

                for value in handle.parsed.values
                    value.line = line

        Cr.updateConnectionsForChange changeObj

    includeInMark = (mark) ->
        mark.inclusiveLeft = true
        mark.inclusiveRight = true

        editor.doc.adjustments.push ->
            mark.inclusiveLeft = false
            mark.inclusiveRight = false

    editor.on 'beforeSelectionChange', (instance, selection) ->
        return if not Cr.scr?

        selection.head = editor.getCursor('head')
        selection.anchor = editor.getCursor('anchor')

    editor.on 'beforeChange', (instance, changeObj) ->
        if changeObj.origin == '+delete' or Cr.scr?
            return

        startMark = (m for m in (editor.findMarksAt changeObj.from) \
            when m.cid?)[0]
        endMark = (m for m in (editor.findMarksAt changeObj.to) \
            when m.cid?)[0]

        if startMark? and not endMark?
            startRange = startMark.find()
            if Cr.inside startRange.from, changeObj.from, startRange.to
                changeObj.cancel()

        else if endMark? and not startMark?
            endRange = endMark.find()
            if Cr.inside endRange.from, changeObj.to, endRange.to
                changeObj.cancel()

        else if startMark? and endMark?
            startRange = startMark.find()
            endRange = endMark.find()
            if startMark != endMark
                if (Cr.inside startRange.from, changeObj.from, startRange.to) or
                        (Cr.inside endRange.from, changeObj.to, endRange.to)
                   changeObj.cancel()
            else if (Cr.inside startRange.from, changeObj.from, startRange.to) and
                    ((changeObj.text.length > 1) or not (/^[\-0-9\.,]+$/.test changeObj.text[0]))
                changeObj.cancel()
            else if ((changeObj.text.length == 1) and (/^[\-0-9\.,]+$/.test changeObj.text[0])) or
                    (not changeObj.origin? and not (/^ = /.test changeObj.text[0]))
                includeInMark startMark # (== endMark)
                        
    ($ document).on 'mouseenter', '.cm-number', Cr.startHover

    editor.refresh()

    Cr.forceEval = ->
        for line in [0..editor.lineCount() - 1]
            evalLine line

    setTitle = (title) ->
        editor.doc.title = title
        document.title = title + ' - Cruncher'
        ($ '#file-name').val title

    Cr.swappedDoc = (uid, title) ->
        editor.doc.uid = uid
        history.pushState {}, "", "?" + uid

        editor.doc.adjustments = []
        do Cr.forceEval
        setTitle title

    Cr.newDoc = (uid = Cr.generateUid()) ->
        editor.swapDoc (CodeMirror.Doc '', 'cruncher')
        Cr.swappedDoc uid, 'Untitled'

    ($ '#file-name').on 'change keyup paste', ->
        title = ($ @).val()
        return if title == editor.doc.title

        if not title? or title.match /^ *$/
            console.log 'Invalid title'
            return
            # TODO alert

        setTitle title

    do ->
        paramUid = window.location.search.substring 1
        console.log paramUid
        if paramUid == ""
            do Cr.newDoc
        else
            Cr.loadDoc paramUid

    if not localStorage['dontIntro']
        ($ '#about').modal('show')
        localStorage['dontIntro'] = true

    ($ '.about').click ->
        ($ '#about').modal('show')

    setInterval Cr.autosave, 5000
