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
       return unless handle.graph?
       handle.graph.widget.clear()
       delete handle.graph

    origin = Cr.editor.coordsChar
        left: downEvent.pageX
        top: downEvent.pageY
    
    Cr.scr = scr = {}

    scr.num = value.num
    scr.fixedDigits = value.numString().split('.')[1]?.length ? 0

    scr.mark = Cr.editor.markText (Cr.valueFrom value),
        (Cr.valueTo value),
        className: 'dragging-number'
        inclusiveLeft: true # so mark survives replacement of its inside
        inclusiveRight: true

    depts = Cr.dependentsOn scr.mark
    fns = Cr.functions value, depts
    graphMarks = Cr.addCharts depts, fns
    # TODO add graph

    xCenter = downEvent.pageX

    replaceDepts = (depts, fns, x) ->
        for dept in depts
            sig = 
            dept.mark.deplaceContents 
    onDragMove = (moveEvent) =>
        xOffset = moveEvent.pageX - xCenter
        xCenter = moveEvent.pageX

        scr.delta = xOffset / 5

        if scr.delta != 0
            range = scr.mark.find()

            scr.num += scr.delta

            numString = scr.num.toFixed scr.fixedDigits
            Cr.editor.replaceRange numString, range.from, range.to

            Cr.updateCharts graphMarks

    onDragUp = =>
        scr.mark.clear()

        ($ document).off('mousemove.scrub')
            .off 'mouseup.scrub'

        Cr.removeCharts()

        # TODO remove this selection-restoring hack
        setTimeout (->
            Cr.editor.focus()
            Cr.editor.setCursor origin), 100

        Cr.scr = scr = null

    ($ document).on('mousemove.scrub', onDragMove)
        .on 'mouseup.scrub', onDragUp
    ($ this).off 'mousedown.scrub'
