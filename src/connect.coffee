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
    onUpConnect = endConnect onMoveConnect, path

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
            console.log 'CLEAR!'
            prevTargetMark?.clear()
            prevTargetMark = null
            prevTargetValue = null

            if targetValue?
                prevTargetMark = connect cid, targetValue
                prevTargetValue = targetValue

        Cr.editor.setCursor originCursor

endConnect = (onMoveConnect, path) -> onUpConnect = ->
    ($ '.CodeMirror').css 'pointer-events', 'auto'
    ($ document)
        .unbind('mousemove', onMoveConnect)
        .unbind 'mouseup', onUpConnect
    path.remove()

connect = (cid, value) ->
    from = { line: value.line, ch: value.start }
    to = { line: value.line, ch: value.end }

    Cr.editor.markText from, to,
        className: 'connected-number-cid-' + cid
        cid: cid

# FIXME make value do something
disconnect = (cid, value) ->
    for mark in Cr.editor.getAllMarks()
        className = mark.getOptions()['className']
        markCid = className.substring ((className.lastIndexOf '-') + 1)

        mark.clear() if (parseFloat markCid) == cid