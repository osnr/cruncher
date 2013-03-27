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

    onMoveConnect = moveConnect cid, originPath, originCursor, path
    onUpConnect = endConnect cid, value, onMoveConnect, path

    ($ '.CodeMirror').css 'pointer-events', 'none'

    ($ document)
        .mousemove(onMoveConnect)
        .mouseup onUpConnect
        # .css 'cursor', 'pointer'

moveConnect = (cid, originPath, originCursor, path) ->
    prevTargetValue = null
    prevTargetMark = null
    (event) ->
        path.attr 'path', originPath + 'L'+event.pageX+','+event.pageY
        targetValue = Cr.nearestValue Cr.editor.coordsChar
            left: event.pageX
            top: event.pageY + 2

        if targetValue != prevTargetValue
            prevTargetMark?.clear()
            prevTargetMark = null
            prevTargetValue = null

            if targetValue?
                prevTargetMark = connect cid, targetValue
                prevTargetValue = targetValue

        Cr.editor.setCursor originCursor

endConnect = (cid, value, onMoveConnect, path) -> onUpConnect = ->
    ($ '.CodeMirror').css 'pointer-events', 'auto'
    ($ document)
        .unbind('mousemove', onMoveConnect)
        .unbind 'mouseup', onUpConnect
    path.remove()

    updateConnections cid, Cr.valueString value

connect = (cid, value) ->
    from = { line: value.line, ch: value.start }
    to = { line: value.line, ch: value.end }

    Cr.editor.markText from, to,
        className: 'connected-number-cid-' + cid
        inclusiveLeft: true
        inclusiveRight: true
        cid: cid

getMarkCid = (mark) -> # hack
    className = mark.getOptions()['className']
    if className.match /^connected-number-cid-\d+/
        parseFloat className.substring ((className.lastIndexOf '-') + 1)
    else
        null

Cr.updateConnectionsForChange = (changeObj) ->
    marks = (Cr.editor.findMarksAt changeObj.from).concat \
        Cr.editor.findMarksAt changeObj.to

    for mark in marks
        markCid = getMarkCid mark
        if markCid?
            range = mark.find()
            updateConnections markCid, (Cr.editor.getRange range.from, range.to)

updateConnections = (cid, newString) ->
    for mark in Cr.editor.getAllMarks()
        if (getMarkCid mark) == cid
            range = mark.find()
            if (Cr.editor.getRange range.from, range.to) != newString
                Cr.editor.replaceRange newString, range.from, range.to

# FIXME make value do something
# disconnect = (cid, value) ->
#     for mark in Cr.editor.getAllMarks()
#         className = mark.getOptions()['className']
#         markCid = className.substring ((className.lastIndexOf '-') + 1)

#         mark.clear() if (parseFloat markCid) == cid