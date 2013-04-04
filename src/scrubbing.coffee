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

    graphMarks = [scr.mark].concat Cr.depsOnValue value
    Cr.addGraph graphMarks

    xCenter = downEvent.pageX

    onDragMove = (moveEvent) =>
        xOffset = moveEvent.pageX - xCenter
        xCenter = moveEvent.pageX

        delta = if xOffset >= 2 then 1 else if xOffset <= -2 then -1 else 0

        if delta != 0
            range = scr.mark.find()
            
            scr.num += delta

            numString = scr.num.toFixed scr.fixedDigits
            Cr.editor.replaceRange numString, range.from, range.to

            Cr.updateGraph graphMarks

    onDragUp = =>
        scr.mark.clear()

        ($ document).off('mousemove.scrub')
            .off 'mouseup.scrub'

        Cr.removeGraph value.line

        # TODO remove this selection-restoring hack
        setTimeout (->
            Cr.editor.focus()
            Cr.editor.setCursor origin), 100

        Cr.scr = scr = null

    ($ document).on('mousemove.scrub', onDragMove)
        .on 'mouseup.scrub', onDragUp
    ($ this).off 'mousedown.scrub'
