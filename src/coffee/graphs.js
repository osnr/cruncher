let Cr;
window.Cruncher = Cr = window.Cruncher || {};

let graph = null;

Cr.addGraph = function(mark, depts) {
  if (graph !== null) {
    Cr.removeGraph();
  }

  graph = {};
  graph.nodes = [];
  graph.links = [];

  deptGraph(mark, depts);

  let svg = d3.selectAll("#overlay svg");
  svg
    .append("svg:defs")
    .append("svg:marker")
    .attr("id", "end-arrow")
    .attr("viewBox", "0 -5 10 10")
    .attr("refX", 10)
    .attr("markerWidth", 10)
    .attr("markerHeight", 10)
    .attr("orient", "auto")
    .append("svg:path")
    .attr("d", "M0,-5L10,0L0,5")
    .attr("fill", "#000");

  graph.link = svg
    .selectAll(".link")
    .data(graph.links)
    .enter()
    .append("line")
    .attr("class", "link")
    .attr("x1", d => d.source.x)
    .attr("y1", d => d.source.y)
    .attr("x2", d => d.target.x)
    .attr("y2", d => d.target.y)
    .style("marker-end", "url(#end-arrow)");

  graph.node = svg
    .selectAll(".node")
    .data(graph.nodes)
    .enter()
    .append("circle")
    .attr("transform", d => `translate(${d.x},${d.y})`)
    .attr("class", "node");

  return graph.node.append("circle").attr("r", 10);
};

Cr.removeGraph = function() {
  __guard__(graph != null ? graph.link : undefined, x =>
    x.data([]).exit().remove()
  );
  __guard__(graph != null ? graph.node : undefined, x1 =>
    x1.data([]).exit().remove()
  );
  return (graph = null);
};

var deptGraph = function(mark, depts) {
  addMarkToGraph(mark);

  return (() => {
    let result = [];
    for (let dept of Array.from(depts)) {
      addLinkToGraph(mark, dept.mark);
      result.push(deptGraph(dept.mark, dept.depts));
    }
    return result;
  })();
};

var addMarkToGraph = function(mark) {
  let coords = markCenter(mark);
  mark.x = coords.left;
  mark.y = coords.top;
  return graph.nodes.push(mark);
};

var addLinkToGraph = (source, target) =>
  graph.links.push({
    source,
    target
  });

var markCenter = function(mark) {
  let pos = mark.find();
  let fromCoords = Cr.editor.charCoords(pos.from);
  let toCoords = Cr.editor.charCoords(pos.to);
  return {
    left: (fromCoords.left + toCoords.right) / 2,
    top: (fromCoords.top + fromCoords.bottom) / 2
  };
};

function __guard__(value, transform) {
  return typeof value !== "undefined" && value !== null
    ? transform(value)
    : undefined;
}
