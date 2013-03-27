window.Cruncher = Cr = window.Cruncher || {}

makeGutterMarker = (stateClass, iconClass, tooltip) ->
    -> ($ '<i></i>')
        .addClass(stateClass)
        .addClass(iconClass)
        .attr('title', tooltip)
        .tooltip(
            html: true
            placement: 'bottom'
            container: 'body'
        )
        .get 0

lineStates =
    parseError:
        gutterMarker:
            makeGutterMarker 'parse-error-icon',
                'icon-remove-circle',
                'I can\'t understand this line.'
        lineClass: 'parse-error-line'

    overDetermined:
        gutterMarker:
            makeGutterMarker 'over-determined-icon',
                'icon-lock',
                'This line doesn\'t have enough <span class="over-determined-free">free numbers</span> for me to change.'
        lineClass: 'over-determined-line'

    underDetermined:
        gutterMarker:
            makeGutterMarker 'under-determined-icon',
                'icon-unlock',
                'This line has too many <span class="over-determined-free">free numbers</span>!'
        lineClass: 'under-determined-line'

stateNameLines = []

# assumption: only one line state at a time
Cr.setLineState = (line, stateName) ->
    state = lineStates[stateName]

    Cr.editor.setGutterMarker line, 'lineState',
        state.gutterMarker()
    Cr.editor.markText { line: line, ch: 0 },
        { line: line, ch: (Cr.editor.getLine line).length },
        { className: state.lineClass }

    stateNameLines[line] = stateName

Cr.unsetLineState = (line, stateName) ->
    return unless stateNameLines[line] == stateName

    state = lineStates[stateName]

    Cr.editor.setGutterMarker line, 'lineState', null

    handle = Cr.editor.getLineHandle line
    if handle.markedSpans?
        for span in handle.markedSpans
            if span.marker.className == state.lineClass
                span.marker.clear()

    stateNameLines[line] = null