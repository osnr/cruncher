window.Cruncher = Cr = window.Cruncher || {};

let gForLineHandle = function(line, handle) {
  handle = handle != null ? handle : Cr.editor.getLineHandle(line);

  if (handle.g != null) {
    return handle.g;
  }

  let g = (handle.g = {});
  g.$wrapper = $('<div class="graph-wrapper"></div>').hide();

  g.widget = Cr.editor.addLineWidget(line, g.$wrapper[0], {
    coverGutter: true
  });

  g.$wrapper.slideDown(100);
  g.charts = {};

  return g;
};

let width = 100;
let height = 100;
let ampl = function() {
  // FIXME special case for 0.0x scrubbing
  if (Cr.scr.origNumString.startsWith("0.")) {
    return 10 / Math.pow(10, Cr.scr.fixedDigits);
  } else {
    return 10;
  }
};

let scaleSide = 0.1;
let delta = 0.1;
let getData = function(yFn, xMin, xMax) {
  let data = [];
  let yMin = Number.MAX_VALUE;
  let yMax = Number.MIN_VALUE;

  for (
    let x = xMin, end = xMax, step = delta, asc = step > 0;
    asc ? x <= end : x >= end;
    x += step
  ) {
    let y = yFn(x);
    if (isNaN(y)) {
      continue;
    }

    if (y < yMin) {
      yMin = y;
    }
    if (y > yMax) {
      yMax = y;
    }
    data.push([x, y]);
  }

  return {
    data,
    yMin,
    yMax
  };
};

let addChart = function(yMark, yFn) {
  let chart, svg, xScale, yScale;
  let yRange = yMark.find();

  let yLine = yRange.from.line;
  let yHandle = Cr.editor.getLineHandle(yLine);

  let g = gForLineHandle(yLine, yHandle);

  if (g.charts[yMark] != null) {
    return;
  }

  let fromCoords = Cr.editor.charCoords(yRange.from);
  let toCoords = Cr.editor.charCoords(yRange.to);

  let centerLeft = (toCoords.left + fromCoords.left) / 2;
  let left = centerLeft - width / 2;
  if (left < 20) {
    left = 20;
    centerLeft = 20 + 100 / 2;
  }

  g.charts[yMark] = chart = {};

  chart.origX = Cr.scr.num;
  chart.yFn = yFn;
  let y = yFn(Cr.scr.num);

  let xMin = Cr.scr.num - ampl();
  let xMax = Cr.scr.num + ampl();

  let { data, yMin, yMax } = getData(yFn, xMin, xMax);
  chart.data = data;

  chart.xScale = xScale = d3.scale
    .linear()
    .domain([xMin, xMax])
    .range([0, width]);
  chart.yScale = yScale = d3.scale
    .linear()
    .domain([yMin, yMax])
    .range([height, 0]);

  let $xMark = $(`.${Cr.scr.mark.className}`).last();
  let $yMark = $(`.${yMark.className}`).last();
  chart.line = d3.svg
    .line()
    .x(function(...args) {
      let i, x;
      let y;
      ([x, y] = Array.from(args[0])), (i = args[1]);
      return xScale(x);
    })
    .y(function(...args) {
      let i, x;
      let y;
      ([x, y] = Array.from(args[0])), (i = args[1]);
      return yScale(y);
    });

  chart.svg = svg = d3
    .select(g.$wrapper[0])
    .append("svg")
    .attr("width", width + 40 + 20)
    .attr("height", height + 20 + 20)
    .append("g")
    .attr("transform", "translate(40,20)");

  let clipPathId = `clip-path-${new Date().getTime().toString()}`;

  svg
    .append("defs")
    .append("clipPath")
    .attr("id", clipPathId)
    .append("rect")
    .attr("width", width)
    .attr("height", height);

  chart.xAxis = d3.svg.axis().scale(xScale).orient("bottom").ticks(5);
  let xColor = $xMark.css("color");
  chart.xAxisG = svg
    .append("g")
    .attr("class", "x axis")
    .style("stroke", xColor)
    .style("fill", xColor)
    .attr("transform", `translate(0,${height})`)
    .call(chart.xAxis);

  chart.yAxis = d3.svg.axis().scale(yScale).orient("left").ticks(5);
  let yColor = $yMark.css("color");
  chart.yAxisG = svg
    .append("g")
    .attr("class", "y axis")
    .style("stroke", yColor)
    .style("fill", yColor)
    .call(chart.yAxis);

  chart.path = svg
    .append("g")
    .attr("clip-path", `url(#${clipPathId})`)
    .append("path")
    .datum(chart.data)
    .attr("class", "line")
    .attr("d", chart.line);

  chart.updateDot = function(x, y) {
    if (chart.dotG != null) {
      chart.dotG.remove();
    }
    chart.dotG = svg
      .append("g")
      .datum({ x, y })
      .attr("class", "dot")
      .attr("transform", d => `translate(${xScale(d.x)},` + yScale(d.y) + ")");
    chart.dotG
      .append("text")
      .text(d => `(${Cr.roundSig(d.x)}, ` + Cr.roundSig(d.y) + ")");
    return chart.dotG.append("path").attr("d", d3.svg.symbol());
  };

  return chart.updateDot(Cr.scr.num, y);
};

let updateChart = function(mark) {
  let range = mark.find();
  let g = gForLineHandle(range.from.line);

  let chart = g.charts[mark];

  if (chart == null) {
    return;
  }

  let y = chart.yFn(Cr.scr.num);

  let xDomain = chart.xScale.domain();
  let xMin = Math.min(xDomain[0], Cr.scr.num - ampl());
  let xMax = Math.max(xDomain[1], Cr.scr.num + ampl());
  chart.xScale.domain([xMin, xMax]);

  let { data, yMin, yMax } = getData(chart.yFn, xMin, xMax);
  chart.data = data;
  chart.path.datum(chart.data);

  let yDomain = chart.yScale.domain();
  yMin = Math.min(yDomain[0], yMin);
  yMax = Math.max(yDomain[1], yMax);
  chart.yScale.domain([yMin, yMax]);

  chart.xAxisG.transition().duration(100).ease("linear").call(chart.xAxis);
  chart.yAxisG.transition().duration(100).ease("linear").call(chart.yAxis);

  chart.updateDot(Cr.scr.num, y);

  return chart.path
    .attr("d", chart.line)
    .attr(
      "transform",
      `translate(${chart.xScale(xMin)}` + "," + chart.yScale(yMax) + ")"
    );
};

let deleteChart = mark => delete g.charts[mark];

Cr.addCharts = function(depts, fns, marks) {
  if (marks == null) {
    marks = [];
  }
  for (let dept of Array.from(depts)) {
    if (fns[dept.mark] !== Cr.id) {
      addChart(dept.mark, fns[dept.mark]);
    }

    marks.push(dept.mark);

    if ((dept.depts != null ? dept.depts.length : undefined) > 0) {
      Cr.addCharts(dept.depts, fns, marks);
    }
  }
  return marks;
};

Cr.updateCharts = marks => Array.from(marks).map(mark => updateChart(mark));

Cr.removeCharts = () =>
  Cr.editor.eachLine(function(handle) {
    if (handle.g != null) {
      handle.g.$wrapper.slideUp(100, function() {
        handle.g.widget.clear();
        return delete handle.g;
      });
    }
    return false;
  });
