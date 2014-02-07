window.Cruncher = Cr = window.Cruncher || {}

graph = null

Cr.addGraph = (mark, depts) ->
    if graph != null
        Cr.removeGraph()

    graph = {}
    graph.nodes = []
    graph.links = []

    deptGraph mark, depts

    svg = d3.selectAll('#overlay svg')
    svg.append('svg:defs')
        .append('svg:marker')
            .attr('id', 'end-arrow')
            .attr('viewBox', '0 -5 10 10')
            .attr('refX', 10)
            .attr('markerWidth', 10)
            .attr('markerHeight', 10)
            .attr('orient', 'auto')
            .append('svg:path')
                .attr('d', 'M0,-5L10,0L0,5')
                .attr('fill', '#000')

    graph.link = svg.selectAll('.link')
        .data(graph.links).enter()
            .append('line')
                .attr('class', 'link')
                .attr('x1', (d) -> d.source.x)
                .attr('y1', (d) -> d.source.y)
                .attr('x2', (d) -> d.target.x)
                .attr('y2', (d) -> d.target.y)
                .style('marker-end', 'url(#end-arrow)')

    graph.node = svg.selectAll('.node')
        .data(graph.nodes).enter()
            .append('circle')
                .attr('transform', (d) -> 'translate(' + d.x + ',' + d.y + ')')
                .attr('class', 'node')

    graph.node.append('circle').attr('r', 10)

Cr.removeGraph = ->
    graph?.link?.data([]).exit().remove()
    graph?.node?.data([]).exit().remove()
    graph = null

deptGraph = (mark, depts) ->
    addMarkToGraph mark

    for dept in depts
        addLinkToGraph mark, dept.mark
        deptGraph dept.mark, dept.depts

addMarkToGraph = (mark) ->
    coords = markCenter(mark)
    mark.x = coords.left
    mark.y = coords.top
    graph.nodes.push(mark)

addLinkToGraph = (source, target) ->
    graph.links.push
        source: source,
        target: target

markCenter = (mark) ->
    pos = mark.find()
    fromCoords = Cr.editor.charCoords(pos.from)
    toCoords = Cr.editor.charCoords(pos.to)
    {
        left: (fromCoords.left + toCoords.right) / 2
        top: (fromCoords.top + fromCoords.bottom) / 2
    }
