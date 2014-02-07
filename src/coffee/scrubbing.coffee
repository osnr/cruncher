window.Cruncher = Cr = window.Cruncher || {}

Cr.hover = hover =null
Cr.scr = scr = null

Cr.startHover = (enterEvent) ->
    # add hover class, construct number widget
    # when user hovers over a number
    return if scr?

    hoverPos = Cr.editor.coordsChar
        left: enterEvent.pageX
        top: enterEvent.pageY

    hoverValue = Cr.nearestValue hoverPos

    if not hoverValue?
        hoverPos = Cr.editor.coordsChar
            left: enterEvent.pageX
            # ugly hack because coordsChar's hit box
            # doesn't quite line up with the DOM hover hit box
            top: enterEvent.pageY + 2

        hoverValue = Cr.nearestValue hoverPos

    return if hoverValue == hover?.value or not hoverValue?
    hover?.mark?.clear()

    Cr.hover = hover =
        pos: hoverPos
        value: hoverValue

    ($ '.number-widget').stop true

    hover.mark = Cr.editor.markText (Cr.valueFrom hoverValue),
        (Cr.valueTo hoverValue),
        className: 'hovering-number'
        inclusiveLeft: true # so mark survives replacement of its inside
        inclusiveRight: true

    ($ '.hovering-number')
        .on('mouseleave', ->
            hover.mark.clear() if not scr?
            Cr.hover = hover = null)
        .not('.free-number')
            .on 'mousedown.scrub', (startDrag hover.value, hover.mark)

    if enterEvent.ctrlKey or enterEvent.metaKey
        Cr.addGraph hover.mark, Cr.dependentsOn hover.mark

    (new Cr.NumberWidget hover.value,
        hover.pos,
        (line) -> Cr.evalLine line).show()

startDrag = (value, mark) -> (downEvent) =>
    # initiate and handle dragging/scrubbing behavior

    ($ document).off('mousemove.scrub').off 'mouseup.scrub'
    scr?.mark?.clear()
    ($ '.number-widget').remove()
    Cr.editor.eachLine (handle) ->
       return unless handle.g?
       handle.g.widget.clear()
       delete handle.g

    origin = Cr.editor.coordsChar
        left: downEvent.pageX
        top: downEvent.pageY

    Cr.scr = scr = {}

    scr.origNum = scr.num = value.num
    scr.fixedDigits = value.numString().split('.')[1]?.length ? 0

    scr.mark = mark

    depts = Cr.dependentsOn scr.mark
    fns = Cr.functions value, depts

    charting = downEvent.altKey
    if charting
        chartMarks = Cr.addCharts depts, fns
    # TODO add graph

    xCenter = downEvent.pageX

    replaceDepts = (depts, fns, x) ->
        for dept in depts
            dept.mark.replaceContents (Cr.roundSig fns[dept.mark](x), 1), '*scrubsolve'
            replaceDepts dept.depts, fns, x

    onDragMove = (moveEvent) =>
        xOffset = moveEvent.pageX - xCenter

        scr.delta = Math.round (xOffset / 5)

        if scr.delta != 0 and not isNaN(scr.delta)
            range = scr.mark.find()

            scr.num = scr.origNum + scr.delta

            numString = scr.num.toFixed scr.fixedDigits
            scr.mark.replaceContents numString, '*scrubsolve'
            replaceDepts depts, fns, scr.num

            if charting
                Cr.updateCharts chartMarks

    onDragUp = =>
        scr.mark.clear()

        ($ document).off('mousemove.scrub')
            .off 'mouseup.scrub'

        if charting
            Cr.removeCharts()

        # TODO remove this selection-restoring hack
        setTimeout (->
            Cr.editor.focus()
            Cr.editor.setCursor origin), 100

        Cr.scr = scr = null

        # since scrubbing doesn't use the standard
        # evaluator, we need to eval the line with that
        # to make everything match again afterward
        changedLines = $.unique (dept.line for dept in depts)
        for line in changedLines
            Cr.evalLine line

    ($ document).on('mousemove.scrub', onDragMove)
        .on 'mouseup.scrub', onDragUp
    ($ this).off 'mousedown.scrub'
