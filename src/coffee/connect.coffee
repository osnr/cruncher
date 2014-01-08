window.Cruncher = Cr = window.Cruncher || {}

paper = null
$ ->
    paper = Raphael 'overlay', '100%', '100%'

Cr.startConnect = (cid, value, ox, oy) ->
    connect cid, value

    originPath = 'M'+ox+','+oy
    originCursor = Cr.editor.getCursor()

    path = paper
        .path(originPath + 'L'+ox+','+oy)
        .attr
            stroke: '#003056'
            'stroke-width': 2

    prevTargetValue = null
    prevTargetMark = null
    onMoveConnect = (event) ->
        path.attr 'path', originPath + 'L'+event.pageX+','+event.pageY
        targetValue = Cr.nearestValue Cr.editor.coordsChar
            left: event.pageX
            top: event.pageY + 2

        if targetValue != prevTargetValue
            disconnectMark cid, prevTargetMark if prevTargetMark?
            prevTargetMark = null
            prevTargetValue = null

            if targetValue? and not (getValueCid targetValue)?
                prevTargetMark = connect cid, targetValue
                prevTargetValue = targetValue

        Cr.editor.setCursor originCursor

    onUpConnect = ->
        ($ '.CodeMirror').css 'pointer-events', 'auto'
        ($ document)
            .unbind('mousemove.connect')
            .unbind 'mouseup.connect'
        path.remove()

        if prevTargetMark? # did we actually connect?
            animateConnect cid
            updateConnections cid, Cr.valueString value
        else
            disconnect cid, value

    ($ '.CodeMirror').css 'pointer-events', 'none'

    ($ document)
        .on('mousemove.connect', onMoveConnect)
        .on 'mouseup.connect', onUpConnect

connect = (cid, value) ->
    mark = Cr.editor.markText (Cr.valueFrom value),
        (Cr.valueTo value),
        className: 'connected-number-cid-' + cid
        inclusiveLeft: false
        inclusiveRight: false
    mark.cid = cid

    mark

animateConnect = (cid) ->
    ($ '.connected-number-cid-' + cid).transition(
        fontSize: 20
        duration: 170
    ).transition
        fontSize: 14

disconnect = (cid, value) ->
    # only triggers with 'real' disconnect,
    # not mark disconnect (which happens during
    # connection-building, a special case)
    disconnectPos cid, Cr.valueFrom value

    cidMarks = (mark for mark in Cr.editor.getAllMarks() when mark.cid == cid)
    if cidMarks.length == 1
        disconnectMark cid, cidMarks[0]

disconnectPos = (cid, pos) ->
    marks = Cr.editor.findMarksAt pos
    disconnectMark cid, mark for mark in marks

disconnectMark = (cid, mark) ->
    if mark.cid == cid
        mark.clear()

Cr.newCid = -> # new cid on the block
    cid = 0
    cid++ while ($ '.connected-number-cid-' + cid).length > 0
    cid

findMark = (from, to) ->
    marks = (Cr.editor.findMarksAt from).concat \
        Cr.editor.findMarksAt to

    for mark in marks when mark.cid?
        return mark

Cr.getValueCid = getValueCid = (value) ->
    mark = findMark (Cr.valueFrom value), (Cr.valueTo value)
    if mark?
        mark.cid
    else
        null

Cr.updateConnectionsForChange = (changeObj) ->
    mark = findMark changeObj.from, changeObj.to
    if mark?
        range = mark.find()
        updateConnections mark.cid, (Cr.editor.getRange range.from, range.to)

updateConnections = (cid, newString) ->
    for mark in Cr.editor.getAllMarks() when mark.cid == cid
        range = mark.find()
        if range? and (Cr.editor.getRange range.from, range.to) != newString
            mark.replaceContents newString, '+solve'

Cr.dependentsOn = (mark, seenMarks = []) ->
    return [] if not mark?

    pos = mark.find().from
    if not mark.cid?
        cidMarks = (m for m in (Cr.editor.findMarksAt pos) \
            when m.cid?)
        if cidMarks.length >= 1
            # throw out this base scrub-mark in favor
            # of one w/ connections
            mark = cidMarks[0]
        else if cidMarks.length > 1
            throw new Error

    seenMarks.push mark
    depts = []

    if mark.cid?
        for cMark in Cr.editor.getAllMarks()
            continue unless cMark.cid == mark.cid and
                (seenMarks.indexOf cMark) == -1
            cPos = cMark.find().from

            seenMarks.push cMark
            depts.push
                mark: cMark
                value: Cr.nearestValue cPos
                type: 'connection'
                line: cPos.line
                lineParsed: (Cr.editor.getLineHandle cPos.line).parsed
                depts: (Cr.dependentsOn cMark, seenMarks)

    parsed = (Cr.editor.getLineHandle pos.line).parsed
    freeSpan = (Cr.getFreeMarkedSpans pos.line)[0]
    if freeSpan?
        freeMark = freeSpan.marker
        freePos =
            line: pos.line
            ch: freeSpan.from

        if parsed? and not (Cr.eq freePos, pos)
            freeValue = Cr.nearestValue freePos
            value = Cr.nearestValue pos

            lineText = Cr.editor.getLine pos.line

            seenMarks.push freeMark
            depts.push
                mark: freeMark
                value: freeValue
                type: 'free'
                line: pos.line
                lineParsed: parsed
                depts: (Cr.dependentsOn freeMark, seenMarks)

    depts

Cr.id = (x) -> x

Cr.functions = (xValue, depts) ->
    functions = {}

    for dept in depts
        if dept.type == 'connection'
            f = Cr.id
        else if dept.type == 'free'
            f = (x) -> dept.lineParsed.substitute(xValue, x).solve()[1]
        functions[dept.mark] = f

        continue unless dept.depts?.length > 0

        deptFunctions = Cr.functions dept.value, dept.depts
        for own deptMark of deptFunctions
            # run adjustment on deptFunctions' functions
            # right now, they're dept.value -> y
            # we want them to be xValue -> y
            deptF = deptFunctions[deptMark]
            functions[deptMark] = do (f, deptF) ->
                (x) -> deptF (f x)

    functions
