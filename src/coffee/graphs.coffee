window.Cruncher = Cr = window.Cruncher || {}

graphForLineHandle = (line, handle) ->
    handle = handle ? Cr.editor.getLineHandle line

    if handle.graph? then return handle.graph

    g = handle.graph = {}
    g.$wrapper = ($ '<div class="graph-wrapper"></div>')
        .hide()

    g.widget = Cr.editor.addLineWidget line, g.$wrapper[0],
        coverGutter: true

    g.$wrapper.slideDown 100
    g.charts = {}

    g

width = 10
delta = 0.05
getData = (chart, indepValue) ->
    [ ([Cr.scr.num + (dx * delta),
        chart.markF Cr.scr.num + (dx * delta), indepValue] \
        for dx in [(-(width + 2) / delta)..((width + 2) / delta)]) ]

addChart = (mark) ->
    range = mark.find()

    line = range.from.line
    handle = Cr.editor.getLineHandle line
    g = graphForLineHandle line, handle

    # marks are keys thanks to the toString() in cruncher.coffee
    return if g.charts[mark]?

    fromCoords = Cr.editor.charCoords range.from
    toCoords = Cr.editor.charCoords range.to

    centerX = (toCoords.left + fromCoords.left) / 2
    x = centerX - 100 / 2
    if x < 20
        x = 20
        centerX = 20 + 100 / 2

    indepValue = Cr.nearestValue Cr.scr.mark.find().from

    g.charts[mark] = chart = {}

    markNum = parseFloat Cr.editor.getRange range.from, range.to
    if mark.className == 'free-number'
        chart.markF = (x, indepValue) ->
            handle.parsed.substitute(indepValue, x).solve()[1]

    else
        chart.markF = (x, indepValue) ->
            x

    chart.$chart = ($ '<div class="chart"></div>')
        .offset
            top: 0
            left: x
        .appendTo g.$wrapper
    chart.plot = $.plot chart.$chart,
        (getData chart, indepValue),
        grid:
            markings: [{
                color: '#003056'
                lineWidth: 1
                xaxis:
                    from: indepValue.num
                    to: indepValue.num
            }, {
                color: '#003056'
                lineWidth: 1
                yaxis:
                    from: markNum
                    to: markNum
            }]
        xaxis:
            min: indepValue.num - width
            max: indepValue.num + width
        yaxis:
            min: markNum - width
            max: markNum + width

setAxisBounds = (chart, curY) ->
    axes = chart.plot.getAxes()
    xaxis = axes.xaxis
    xaxis.options.min = xaxis.min + Cr.scr.delta
    xaxis.options.max = xaxis.max + Cr.scr.delta

    yaxis = axes.yaxis
    yaxis.options.min = curY - width
    yaxis.options.max = curY + width

updateChart = (mark) ->
    range = mark.find()
    g = graphForLineHandle range.from.line

    chart = g.charts[mark]

    markNum = parseFloat Cr.editor.getRange range.from, range.to
    indepValue = Cr.nearestValue Cr.scr.mark.find().from

    chart.plot.setData getData chart, indepValue

    markings = chart.plot.getOptions().grid.markings
    markings[2] =
        color: '#00A1D9'
        lineWidth: 1
        xaxis:
            from: indepValue.num
            to: indepValue.num
    markings[3] =
        color: '#00A1D9'
        lineWidth: 1
        yaxis:
            from: markNum
            to: markNum

    setAxisBounds chart, markNum

    chart.plot.setupGrid()
    chart.plot.draw()

shiftCharts = ->
    Cr.editor.eachLine (handle) ->
        return unless handle.graph?
        # for mark, chart of handle.graph.charts
            #chart.$chart.offset
            #    left: 100

deleteChart = (mark) ->
    delete g.charts[mark]

Cr.addGraph = (marks) ->
    addChart mark for mark in marks
    shiftCharts()

Cr.updateGraph = (marks) ->
    updateChart mark for mark in marks

Cr.removeGraph = ->
    Cr.editor.eachLine (handle) ->
        handle.graph?.$wrapper.slideUp 100, ->
            handle.graph.widget.clear()
            delete handle.graph
        false
