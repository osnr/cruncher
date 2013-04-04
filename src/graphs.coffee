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

getData = (chart, curY, indepValue) ->
    [ ([Cr.scr.num + (dx * 0.05),
        chart.markF Cr.scr.num + (dx * 0.05), curY, indepValue] for dx in [-500..500]) ]

addChart = (mark) ->
    range = mark.find()

    line = range.from.line
    handle = Cr.editor.getLineHandle line
    g = graphForLineHandle line, handle

    console.log line, g.charts
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
        chart.markF = (x, curY, indepValue) ->
            handle.parsed.substitute(indepValue, x).solve()[1]

    else
        chart.markF = (x, curY, indepValue) ->
            (curY - Cr.scr.num) + x
    window.markF = chart.markF

    chart.$chart = ($ '<div class="chart"></div>')
        .offset
            top: 0
            left: x
        .appendTo g.$wrapper
    chart.plot = $.plot chart.$chart,
        (getData chart, markNum, indepValue),
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
        zoom:
            interactive: true
        pan:
            interactive: true
 #,
#        yaxis:
#            max: 1

    # g.charts[mark] = g.paper.linechart x, 0, 100, 80,
    #     (Cr.scr.num + (dx * 0.05) for dx in [-100..100])
    #     ((markF Cr.scr.num + (dx * 0.05)) for dx in [-100..100]),
    #     shade: true
    #     axis: '0 0 1 1'
    #     axisxstep: 3

updateChart = (mark) ->
    range = mark.find()
    g = graphForLineHandle range.from.line

    chart = g.charts[mark]

    markNum = parseFloat Cr.editor.getRange range.from, range.to
    indepValue = Cr.nearestValue Cr.scr.mark.find().from

    data = getData chart, markNum, indepValue
    chart.plot.setData getData chart, markNum, indepValue

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

    chart.plot.setupGrid();
    chart.plot.draw()

    # chart.plot.pan chart.plot.pointOffset
    #     x: data[0][0][0]
    #     y: data[0][0][1]

deleteChart = (mark) ->
    delete g.charts[mark]

Cr.addGraph = (marks) ->
    addChart mark for mark in marks

Cr.updateGraph = (marks) ->
    updateChart mark for mark in marks

numRange = (num) ->
    (num + i * 0.01 for i in [-50..50])

Cr.removeGraph = (line) ->
    return
    graphs[line].$wrapper.slideUp 100, ->
        graphs[line].widget.clear()
        graphs[line] = null
