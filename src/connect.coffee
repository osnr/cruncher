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

            if targetValue? and not (getCidFor targetValue)?
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

Cr.connections = connections = {}

connect = (cid, value) ->
    connections[cid] = connections[cid] ? []
    
    mark = Cr.editor.markText (Cr.valueFrom value),
        (Cr.valueTo value),
        className: 'connected-number-cid-' + cid
        inclusiveLeft: true # so mark survives replacement of its inside
        inclusiveRight: true
    connections[cid].push mark
    console.log connections[cid]
    mark

getMarkCid = (mark) -> # hack
    className = mark.getOptions()['className']
    if className.match /^connected-number-cid-\d+/
        parseFloat className.substring ((className.lastIndexOf '-') + 1)
    else
        null

disconnect = (cid, value) ->
    disconnectPos cid, Cr.valueFrom value

    if connections[cid].length == 1
        # only triggers with 'real' disconnect,
        # not mark disconnect (which happens during
        # connection-building, a special case)
        disconnectMark cid, connections[cid][0]

disconnectPos = (cid, pos) ->
    marks = Cr.editor.findMarksAt pos
    disconnectMark cid, mark for mark in marks

disconnectMark = (cid, mark) ->
    connection = connections[cid]

    if mark in connection
        mark.clear()
        i = connection.indexOf mark
        connection.splice i, 1 unless i == -1

Cr.newCid = ->
    for i in [0..100]
        return i unless connections[i]?.length > 0

findMarksIn = (from, to) ->
    marks = (Cr.editor.findMarksAt from).concat \
        Cr.editor.findMarksAt to

    (mark for mark in marks when mark.getOptions()['className']
        .match /^connected-number-cid-\d+/)    

Cr.getCidFor = getCidFor = (value) ->
    marks = findMarksIn (Cr.valueFrom value), (Cr.valueTo value)
    for mark in marks
        return getMarkCid mark

    return null

Cr.updateConnectionsForChange = (changeObj) ->
    marks = findMarksIn changeObj.from, changeObj.to

    for mark in marks
        markCid = getMarkCid mark
        if markCid?
            range = mark.find()
            updateConnections markCid, (Cr.editor.getRange range.from, range.to)

updateConnections = (cid, newString) ->
    for mark in connections[cid]
        range = mark.find()
        if (Cr.editor.getRange range.from, range.to) != newString
            Cr.editor.replaceRange newString, range.from, range.to
