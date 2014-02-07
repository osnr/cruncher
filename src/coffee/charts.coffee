window.Cruncher = Cr = window.Cruncher || {}

gForLineHandle = (line, handle) ->
    handle = handle ? Cr.editor.getLineHandle line

    if handle.g? then return handle.g

    g = handle.g = {}
    g.$wrapper = ($ '<div class="graph-wrapper"></div>')
        .hide()

    g.widget = Cr.editor.addLineWidget line, g.$wrapper[0],
        coverGutter: true

    g.$wrapper.slideDown 100
    g.charts = {}

    g

width = 100
height = 100
ampl = 10
scaleSide = 0.1
delta = 0.05
getData = (yFn, xMin, xMax) ->
    for x in [xMin..xMax] by delta
        y = yFn(x)
        continue if (isNaN y)
        [x, y]

addChart = (yMark, yFn) ->
    yRange = yMark.find()

    yLine = yRange.from.line
    yHandle = Cr.editor.getLineHandle yLine

    g = gForLineHandle yLine, yHandle

    return if g.charts[yMark]?

    fromCoords = Cr.editor.charCoords yRange.from
    toCoords = Cr.editor.charCoords yRange.to

    centerLeft = (toCoords.left + fromCoords.left) / 2
    left = centerLeft - width / 2
    if left < 20
        left = 20
        centerLeft = 20 + 100 / 2

    g.charts[yMark] = chart = {}

    chart.origX = Cr.scr.num
    console.log yMark, yFn
    chart.yFn = yFn
    y = yFn Cr.scr.num

    chart.xScale = xScale = d3.scale.linear()
        .domain([Cr.scr.num - ampl, Cr.scr.num + ampl])
        .range([0, width])
    chart.yScale = yScale = d3.scale.linear()
        .domain([
            Math.min(yFn(Cr.scr.num - ampl), yFn(Cr.scr.num)),
            Math.max(yFn(Cr.scr.num + ampl), yFn(Cr.scr.num))
        ]).range([height, 0])

    chart.data = getData yFn, Cr.scr.num - ampl, Cr.scr.num + ampl

    $xMark = ($ '.' + Cr.scr.mark.className).last()
    $yMark = ($ '.' + yMark.className).last()
    chart.line = d3.svg.line()
        .x(([x, y], i) -> xScale x)
        .y(([x, y], i) -> yScale y)

    chart.svg = svg = d3.select(g.$wrapper[0]).append('svg')
        .attr('width', width + 40 + 20)
        .attr('height', height + 20 + 20)
        .append('g')
            .attr('transform', 'translate(40,20)')

    clipPathId = 'clip-path-' + new Date().getTime().toString()

    svg.append('defs').append('clipPath')
        .attr('id', clipPathId)
        .append('rect')
            .attr('width', width)
            .attr('height', height)

    chart.xAxis = d3.svg.axis()
        .scale(xScale)
        .orient('bottom')
        .ticks(5)
    xColor = $xMark.css('color')
    chart.xAxisG = svg.append('g')
        .attr('class', 'x axis')
        .style('stroke', xColor)
        .style('fill', xColor)
        .attr('transform', 'translate(0,' + height + ')')
        .call(chart.xAxis)

    chart.yAxis = d3.svg.axis()
        .scale(yScale)
        .orient('left')
        .ticks(5)
    yColor = $yMark.css('color')
    chart.yAxisG = svg.append('g')
        .attr('class', 'y axis')
        .style('stroke', yColor)
        .style('fill', yColor)
        .call(chart.yAxis)

    chart.path = svg.append('g')
        .attr('clip-path', 'url(#' + clipPathId + ')')
        .append('path')
        .datum(chart.data)
        .attr('class', 'line')
        .attr('d', chart.line)

    chart.updateDot = (x, y) ->
        chart.dotG?.remove()
        chart.dotG = svg.append('g')
            .datum({ x: x, y: y })
            .attr('class', 'dot')
            .attr('transform', (d) ->
                'translate(' + (xScale d.x) + ',' +
                    (yScale d.y) + ')' )
        chart.dotG.append('text')
            .text((d) -> '(' + (Cr.roundSig d.x) + ', ' +
                (Cr.roundSig d.y) + ')')
        chart.dotG.append('path')
            .attr('d', d3.svg.symbol())

    chart.updateDot Cr.scr.num, y

updateChart = (mark) ->
    range = mark.find()
    g = gForLineHandle range.from.line

    chart = g.charts[mark]

    return unless chart?

    y = chart.yFn Cr.scr.num

    xDomain = chart.xScale.domain()
    xMin = Math.min xDomain[0], Cr.scr.num - ampl
    xMax = Math.max xDomain[1], Cr.scr.num + ampl
    chart.xScale.domain([xMin, xMax])

    yDomain = chart.yScale.domain()
    yMin = Math.min yDomain[0], (chart.yFn xMin), (chart.yFn xMax)
    yMax = Math.max yDomain[1], (chart.yFn xMax), (chart.yFn xMin)
    chart.yScale.domain([yMin, yMax])

    chart.data = getData chart.yFn, xMin, xMax
    chart.path.datum chart.data

    chart.xAxisG.transition()
        .duration(100)
        .ease('linear')
        .call(chart.xAxis)
    chart.yAxisG.transition()
        .duration(100)
        .ease('linear')
        .call(chart.yAxis)

    chart.updateDot Cr.scr.num, y

    chart.path.attr('d', chart.line)
        .attr('transform', 'translate(' + (chart.xScale xMin) +
            ',' + (chart.yScale yMax) + ')')

deleteChart = (mark) ->
    delete g.charts[mark]

Cr.addCharts = (depts, fns, marks = []) ->
    for dept in depts
        if fns[dept.mark] != Cr.id
            addChart dept.mark, fns[dept.mark]

        marks.push dept.mark

        if dept.depts?.length > 0
            Cr.addCharts dept.depts, fns, marks
    marks

Cr.updateCharts = (marks) ->
    updateChart mark for mark in marks

Cr.removeCharts = ->
    Cr.editor.eachLine (handle) ->
        handle.g?.$wrapper.slideUp 100, ->
            handle.g.widget.clear()
            delete handle.g
        false
