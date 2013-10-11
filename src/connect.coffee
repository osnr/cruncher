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
            updateConnections cid, Cr.valueString value
        else
            disconnect cid, value

    ($ '.CodeMirror').css 'pointer-events', 'none'

    ($ document)
        .on('mousemove.connect', onMoveConnect)
        .on 'mouseup.connect', onUpConnect
        # .css 'cursor', 'pointer'

connect = (cid, value) ->
    mark = Cr.editor.markText (Cr.valueFrom value),
        (Cr.valueTo value),
        className: 'connected-number-cid-' + cid
        inclusiveLeft: true # so mark survives replacement of its inside
        inclusiveRight: true
    mark.cid = cid

    mark

getMarkCid = (mark) -> # hack
    className = mark.className
    if className.match /^connected-number-cid-\d+/
        parseFloat className.substring ((className.lastIndexOf '-') + 1)
    else
        null

disconnect = (cid, value) ->
    # only triggers with 'real' disconnect,
    # not mark disconnect (which happens during
    # connection-building, a special case)
    disconnectPos cid, Cr.valueFrom value

    cidMarks = (mark for mark in Cr.editor.getAllMarks() when mark.cid == cid)
    if cidMarks.length == 1
        delete Cr.cids[cid]
        disconnectMark cid, cidMarks[0]

disconnectPos = (cid, pos) ->
    marks = Cr.editor.findMarksAt pos
    disconnectMark cid, mark for mark in marks

disconnectMark = (cid, mark) ->
    if mark.cid == cid
        mark.clear()

Cr.cids = {}
Cr.newCid = do ->
    maxCid = 0
    ->
        Cr.cids[maxCid] = true
        maxCid++

findMark = (from, to) ->
    marks = (Cr.editor.findMarksAt from).concat \
        Cr.editor.findMarksAt to

    for mark in marks
        if mark.className.match /^connected-number-cid-\d+/
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
            Cr.editor.replaceRange newString, range.from, range.to

Cr.depsOnValue = depsOnValue = (value, sameConnection) ->
    # takes a value `value`, returns all _marks_ dependent on `value`
    # either same-line free numbers or connected numbers
    # (not including `value` itself)
    deps = []

    # find free deps
    parsed = (Cr.editor.getLineHandle value.line).parsed
    freeValues = (v for v in parsed.values when typeof v.num == 'function')
    for freeValue in freeValues
        if freeValue != value
            deps.push.apply deps, depsOnValue freeValue
            deps.push (mark for mark in Cr.editor.findMarksAt \
                Cr.valueFrom freeValue when mark.className == 'free-number')[0]

    if sameConnection then return deps

    # find connection deps
    mark = findMark (Cr.valueFrom value), (Cr.valueTo value)
    cid = getMarkCid mark if mark?
    if cid?
        for cMark in Cr.editor.getAllMarks() when cMark.cid == cid
            cValue = Cr.nearestValue cMark.find().from
            if cValue != value
                deps.push.apply deps, (depsOnValue cValue, true)
                deps.push cMark

    return deps
