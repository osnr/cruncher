window.Cruncher = Cr = window.Cruncher || {}

scr = null

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
            top: enterEvent.pageY + 2 # ugly hack because coordsChar's hit box doesn't quite line up with the DOM hover hit box

        hoverValue = Cr.nearestValue hoverPos

    if hoverValue?
        ($ '.hovering-number').removeClass 'hovering-number'

        ($ '.number-widget').stop(true)

        ($ this).addClass('hovering-number')
            .not('.free-number')
                .on 'mousedown.scrub', startDrag hoverPos, hoverValue

        (new Cr.NumberWidget hoverValue,
            hoverPos,
            (line) -> Cr.evalLine line).show()

startDrag = (origin, value) -> (downEvent) =>
    # initiate and handle dragging/scrubbing behavior

    ($ document).off('mousemove.scrub').off 'mouseup.scrub'
    scr?.mark?.clear()
    ($ '.number-widget').remove()

    scr = {}

    scr.origin = origin

    scr.num = value.num
    scr.fixedDigits = value.toString().split('.')[1]?.length ? 0

    scr.mark = Cr.editor.markText (Cr.valueFrom value),
        (Cr.valueTo value),
        className: 'dragging-number'
        inclusiveLeft: true # so mark survives replacement of its inside
        inclusiveRight: true

    xCenter = downEvent.pageX

    preventSelectionChange = (instance, selection) ->
        selection.anchor = instance.getCursor 'anchor'
        selection.head = instance.getCursor 'head'

    Cr.editor.on 'beforeSelectionChange', preventSelectionChange
    
    onDragMove = (moveEvent) =>
        xOffset = moveEvent.pageX - xCenter
        xCenter = moveEvent.pageX

        delta = if xOffset >= 2 then 1 else if xOffset <= -2 then -1 else 0

        if delta != 0
            range = scr.mark.find()
            
            scr.num += delta

            numString = scr.num.toFixed scr.fixedDigits
            Cr.editor.replaceRange numString, range.from, range.to
    
    onDragUp = =>
        scr.mark.clear()

        ($ document).off('mousemove.scrub')
            .off 'mouseup.scrub'

        # TODO avoid this hack to get around selection event firing order
        setTimeout (->
            Cr.editor.off 'beforeSelectionChange', preventSelectionChange
            Cr.editor.setCursor origin),
            100

        scr = null

    ($ document).on('mousemove.scrub', onDragMove)
        .on 'mouseup.scrub', onDragUp
    ($ this).off 'mousedown.scrub'
