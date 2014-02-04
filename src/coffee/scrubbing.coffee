window.Cruncher = Cr = window.Cruncher || {}

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

    if hoverValue?
        ($ '.hovering-number').removeClass 'hovering-number'

        ($ '.number-widget').stop true

        ($ this).addClass('hovering-number')
            .not('.free-number')
                .on 'mousedown.scrub', startDrag hoverValue

        (new Cr.NumberWidget hoverValue,
            hoverPos,
            (line) -> Cr.evalLine line).show()

startDrag = (value) -> (downEvent) =>
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

    scr.mark = Cr.editor.markText (Cr.valueFrom value),
        (Cr.valueTo value),
        className: 'dragging-number'
        inclusiveLeft: true # so mark survives replacement of its inside
        inclusiveRight: true

    depts = Cr.dependentsOn scr.mark
    fns = Cr.functions value, depts

    charting = false
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
