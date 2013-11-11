window.Cruncher = Cr = window.Cruncher || {}

Cr.sig = (text) ->
    sig = -1

    numStrings = text.match /\d+(?:,\d+)*(?:\.\d*)?(?:[eE]-?\d+)?/g
    for numString in numStrings
        if (numString.indexOf '.') != -1
            continue
        numString = numString.replace /,\./g, ''
        if sig == -1
            sig = numString.length
        else
            sig = Math.min sig, numString.length

    sig

Cr.roundSig = (n, sig) ->
    n = Math.round(n * 1e10) / 1e10

    rnd = n.toString()

    if rnd == '-0' then '0'
    else rnd

Cr.inside = (a, b, c) ->
    (a.line <= b.line <= c.line) and (a.ch < b.ch < c.ch)

Cr.lt = (a, b) ->
    a.line < b.line or a.ch < b.ch

Cr.eq = (a, b) ->
    a.line == b.line and a.ch == b.ch

Cr.nearestValue = (pos) ->
    # find nearest number (Value) to pos = { line, ch }
    # used for identifying hover/drag target

    parsed = (Cr.editor.getLineHandle pos.line).parsed
    return unless parsed?

    nearest = null
    for value in parsed.values
        if value.start <= pos.ch <= value.end
            nearest = value
            break

    return nearest

Cr.valueFrom = (value) ->
    { line: value.line, ch: value.start }

Cr.valueTo = (value) ->
    { line: value.line, ch: value.end }

Cr.valueString = (value) ->
    Cr.editor.getRange (Cr.valueFrom value), (Cr.valueTo value)

Cr.getFreeMarkedSpans = (line) ->
    handle = Cr.editor.getLineHandle line
    return [] unless handle?.markedSpans?

    (span for span in handle.markedSpans \
        when span.marker.className == 'free-number')
