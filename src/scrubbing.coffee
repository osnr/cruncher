window.Cruncher = Cr = window.Cruncher || {}

Cr.draggingState = dr = null

Cr.startHover = (enterEvent) ->
    # add hover class, construct number widget
    # when user hovers over a number
    return if dr?

    hoverPos = Cr.editor.coordsChar
        left: enterEvent.pageX
        top: enterEvent.pageY

    hoverValue = Cr.nearestValue hoverPos

    if not hoverValue?
        hoverPos = Cr.editor.coordsChar
            left: enterEvent.pageX
            top: enterEvent.pageY + 2 # ugly hack because coordsChar's hit box doesn't quite line up with the DOM hover hit box

        hoverValue = Cr.nearestValue hoverPos

    console.log hoverValue

    if hoverValue?
        ($ '.hovering-number').removeClass 'hovering-number'

        ($ '.number-widget').stop(true)

        ($ this).addClass('hovering-number')
            .not('.free-number')
                .mousedown startDrag hoverPos, hoverValue

        (new Cr.NumberWidget hoverValue,
            hoverPos,
            (line) -> Cr.evalLine line).show()

startDrag = (origin, value) -> onDragDown = (downEvent) ->
    # initiate and handle dragging/scrubbing behavior

    ($ this).addClass 'dragging-number'
    ($ '.number-widget').remove()

    Cr.draggingState = dr = {}

    dr.origin = origin

    dr.num = value.num
    dr.fixedDigits = value.toString().split('.')[1]?.length ? 0

    dr.from = line: dr.origin.line, ch: value.start
    dr.to = line: dr.origin.line, ch: value.end

    xCenter = downEvent.pageX

    preventSelectionChange = (instance, selection) ->
        selection.anchor = instance.getCursor 'anchor'
        selection.head = instance.getCursor 'head'

    Cr.editor.on 'beforeSelectionChange', preventSelectionChange
    
    onDragMove = (moveEvent) =>
        xOffset = moveEvent.pageX - xCenter
        xCenter = moveEvent.pageX

        delta = if xOffset >= 2 then 1 else if xOffset <= -2 then -1 else 0
        console.log xOffset / (Math.abs xOffset)

        if delta != 0
            dr.num += delta

            numString = dr.num.toFixed dr.fixedDigits
            Cr.editor.replaceRange numString, dr.from, dr.to

            dr.to.ch = dr.from.ch + numString.length
    
    onDragUp = =>
        ($ '.dragging-number').removeClass 'dragging-number'

        ($ this).off 'mousedown', onDragDown

        ($ document).off('mousemove', onDragMove)
            .off 'mouseup', onDragUp

        # TODO avoid this hack to get around selection event firing order
        setTimeout (->
            Cr.editor.off 'beforeSelectionChange', preventSelectionChange),
            100

        Cr.draggingState = dr = null

    ($ document).on('mousemove', onDragMove)
        .on 'mouseup', onDragUp
