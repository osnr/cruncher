window.Cruncher = Cr = window.Cruncher || {}

Cr.roundSig = (numStrings, n) ->
    sig = -1

    for numString in numStrings when (numString.indexOf '.') != -1
        if sig == -1
            sig = numString.length - 1
        else
            sig = Math.min(sig, numString.length - 1)

    console.log numStrings, n, sig
    if sig == -1 then rnd = n.toFixed 0
    else rnd = (parseFloat (n.toPrecision sig)).toString()

    if rnd == '-0' then 0
    else rnd

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
    editor.getRange (Cr.valueFrom value), (Cr.valueTo value)
