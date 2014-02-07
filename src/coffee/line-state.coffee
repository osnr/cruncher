window.Cruncher = Cr = window.Cruncher || {}

makeGutterMarker = (stateClass, iconClass, tooltip) ->
    -> ($ '<i class="fa"></i>')
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
                'fa-question-circle',
                'I can\'t understand this line.'
        bgClass: 'parse-error-line'
        wrapClass: 'parse-error'

    overDetermined:
        gutterMarker:
            makeGutterMarker 'over-determined-icon',
                'fa-pencil-square',
                'This line is entirely <span class="over-determined-locked">human-controlled numbers <i class="fa fa-pencil-square"></span></i>.<br>I can\'t change anything to make the left and right side equal.'
        bgClass: 'over-determined-line'
        wrapClass: 'over-determined'

    underDetermined:
        gutterMarker:
            makeGutterMarker 'under-determined-icon',
                'fa-cogs',
                'This line has too many <span class="under-determined-free">computer-controlled numbers <i class="fa fa-cogs"></i></span>! ' +
                'I don\'t know how to solve it.'
        bgClass: 'under-determined-line'
        wrapClass: 'under-determined'

# assumption: only one line state at a time
Cr.setLineState = (line, stateName) ->
    state = lineStates[stateName]

    Cr.editor.setGutterMarker line, 'lineState',
        state.gutterMarker()
    Cr.editor.addLineClass line, 'background', state.bgClass
    Cr.editor.addLineClass line, 'wrap', state.wrapClass

    (Cr.editor.getLineHandle line).state = stateName

Cr.unsetLineState = (line, stateName) ->
    handle = Cr.editor.getLineHandle line
    return unless handle.state? and handle.state == stateName

    state = lineStates[stateName]

    Cr.editor.setGutterMarker line, 'lineState', null

    Cr.editor.removeLineClass line, 'background', state.bgClass
    Cr.editor.removeLineClass line, 'wrap', state.wrapClass

    delete handle.state

Cr.getLineState = (line) ->
    (Cr.editor.getLineHandle line).state

Cr.updateSign = (line, handle) ->
    handle.equalsMark?.clear()

    idx = handle.text.indexOf '='
    return unless idx > -1

    leftNum = handle.parsed.left.num
    rightNum = handle.parsed.right.num

    if Math.abs(leftNum - rightNum) < 1e-5
        replacedWith = ($ '<span>&#8776;</span>')[0]
    else if leftNum < rightNum
        replacedWith = ($ '<span>&lt;</span>')[0]
    else if leftNum > rightNum
        replacedWith = ($ '<span>&gt;</span>')[0]

    handle.equalsMark = Cr.editor.markText {
        line: line
        ch: idx
    }, {
        line: line
        ch: idx + 1
    }, replacedWith: replacedWith
