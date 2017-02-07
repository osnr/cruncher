window.Cruncher = Cr = window.Cruncher || {}

Cr.hover = hover = null
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
    endHover()

    Cr.hover = hover =
        pos: hoverPos
        value: hoverValue

    hover.mark = Cr.editor.markText (Cr.valueFrom hoverValue),
        (Cr.valueTo hoverValue),
        className: 'hovering-number'
        inclusiveLeft: true # so mark survives replacement of its inside
        inclusiveRight: true

    if (not Cr.settings) or Cr.settings.scrubbable
        ($ '.CodeMirror-code .hovering-number')
            .not('.free-number')
                .on 'mousedown.scrub', (startDrag hover.value, hover.mark)

    if (not Cr.settings) or Cr.settings.hints
        ($ '#keys').stop(true, true).show()

    if enterEvent.ctrlKey or enterEvent.metaKey
        Cr.addGraph hover.mark, Cr.dependentsOn hover.mark
    ($ document)
        .on('mousemove.hover', (event) ->
            endHover() unless ($ event.target).is('.hovering-number') \
                or ($ event.target).closest('.number-widget').length > 0
        ).on('mousedown', (event) ->
            return if ($ event.target).closest('.number-widget').length > 0
            endHover()
        ).on('keydown.deps', (event) ->
            return unless event.ctrlKey or event.metaKey
            Cr.addGraph hover.mark, Cr.dependentsOn hover.mark
        ).on('keyup.deps', (event) ->
            return unless event.which == 17 or event.which == 91 or event.which == 93 # ctrl, cmd key
            Cr.removeGraph()
        )

    if (not Cr.settings) or Cr.settings.editable
        (new Cr.NumberWidget hover.value,
            hover.pos,
            (line) -> Cr.evalLine line).show()

endHover = ->
    hover?.mark?.clear() if not scr?
    Cr.hover = hover = null

    ($ document).off('mousemove.hover keydown.deps keyup.deps')
    Cr.removeGraph()

    ($ '.number-widget').remove()

    ($ '#keys').hide()

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
    scr.origNumString = value.numString()
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

        if scr.origNumString.startsWith('0.')
            scr.delta = Math.round(xOffset / 5) / Math.pow(10, scr.fixedDigits)
            console.log scr.delta, scr.fixedDigits
        else
            scr.delta = Math.round(xOffset / 5)

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
