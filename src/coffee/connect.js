let Cr, getValueCid;
window.Cruncher = Cr = window.Cruncher || {};

let paper = null;
$(() => (paper = Raphael("overlay", "100%", "100%")));

Cr.startConnect = function(cid, value, ox, oy) {
  connect(cid, value);

  let originPath = `M${ox},${oy}`;
  let originCursor = Cr.editor.getCursor();

  let path = paper.path(originPath + "L" + ox + "," + oy).attr({
    stroke: "#003056",
    "stroke-width": 2
  });

  let prevTargetValue = null;
  let prevTargetMark = null;
  let onMoveConnect = function(event) {
    path.attr("path", originPath + "L" + event.pageX + "," + event.pageY);
    let targetValue = Cr.nearestValue(
      Cr.editor.coordsChar({
        left: event.pageX,
        top: event.pageY + 2
      })
    );

    if (targetValue !== prevTargetValue) {
      if (prevTargetMark != null) {
        disconnectMark(cid, prevTargetMark);
      }
      prevTargetMark = null;
      prevTargetValue = null;

      if (targetValue != null && getValueCid(targetValue) == null) {
        prevTargetMark = connect(cid, targetValue);
        prevTargetValue = targetValue;
      }
    }

    return Cr.editor.setCursor(originCursor);
  };

  let onUpConnect = function() {
    $(".CodeMirror").css("pointer-events", "auto");
    $(document).unbind("mousemove.connect").unbind("mouseup.connect");
    path.remove();

    if (prevTargetMark != null) {
      // did we actually connect?
      animateConnect(cid);
      return updateConnections(cid, Cr.valueString(value));
    } else {
      return disconnect(cid, value);
    }
  };

  $(".CodeMirror").css("pointer-events", "none");

  return $(document)
    .on("mousemove.connect", onMoveConnect)
    .on("mouseup.connect", onUpConnect);
};

var connect = function(cid, value) {
  let mark = Cr.editor.markText(Cr.valueFrom(value), Cr.valueTo(value), {
    className: `connected-number-cid-${cid}`,
    inclusiveLeft: false,
    inclusiveRight: false
  });
  mark.cid = cid;

  return mark;
};

var animateConnect = cid =>
  $(`.connected-number-cid-${cid}`)
    .transition({
      fontSize: 20,
      duration: 170
    })
    .transition({
      fontSize: 14
    });

var disconnect = function(cid, value) {
  // only triggers with 'real' disconnect,
  // not mark disconnect (which happens during
  // connection-building, a special case)
  disconnectPos(cid, Cr.valueFrom(value));

  let cidMarks = Array.from(Cr.editor.getAllMarks())
    .filter(mark => mark.cid === cid)
    .map(mark => mark);
  if (cidMarks.length === 1) {
    return disconnectMark(cid, cidMarks[0]);
  }
};

var disconnectPos = function(cid, pos) {
  let marks = Cr.editor.findMarksAt(pos);
  return Array.from(marks).map(mark => disconnectMark(cid, mark));
};

var disconnectMark = function(cid, mark) {
  if (mark.cid === cid) {
    return mark.clear();
  }
};

Cr.newCid = function() {
  // new cid on the block
  let cid = 0;
  while ($(`.connected-number-cid-${cid}`).length > 0) {
    cid++;
  }
  return cid;
};

let findMark = function(from, to) {
  let marks = Cr.editor.findMarksAt(from).concat(Cr.editor.findMarksAt(to));

  for (let mark of Array.from(marks)) {
    if (mark.cid != null) {
      return mark;
    }
  }
};

Cr.getValueCid = getValueCid = function(value) {
  let mark = findMark(Cr.valueFrom(value), Cr.valueTo(value));
  if (mark != null) {
    return mark.cid;
  } else {
    return null;
  }
};

Cr.updateConnectionsForChange = function(changeObj) {
  let mark = findMark(changeObj.from, changeObj.to);
  if (mark != null) {
    let range = mark.find();
    return updateConnections(
      mark.cid,
      Cr.editor.getRange(range.from, range.to)
    );
  }
};

var updateConnections = (cid, newString) =>
  (() => {
    let result = [];
    for (let mark of Array.from(Cr.editor.getAllMarks())) {
      if (mark.cid === cid) {
        let range = mark.find();
        if (
          range != null &&
          Cr.editor.getRange(range.from, range.to) !== newString
        ) {
          result.push(mark.replaceContents(newString, "+solve"));
        } else {
          result.push(undefined);
        }
      }
    }
    return result;
  })();

Cr.dependentsOn = function(mark, seenMarks) {
  if (seenMarks == null) {
    seenMarks = [];
  }
  if (mark == null) {
    return [];
  }

  let pos = mark.find().from;
  if (mark.cid == null) {
    let cidMarks = Array.from(Cr.editor.findMarksAt(pos))
      .filter(m => m.cid != null)
      .map(m => m);
    if (cidMarks.length >= 1) {
      // throw out this base scrub-mark in favor
      // of one w/ connections
      mark = cidMarks[0];
    } else if (cidMarks.length > 1) {
      throw new Error();
    }
  }

  seenMarks.push(mark);
  let depts = [];

  if (mark.cid != null) {
    for (let cMark of Array.from(Cr.editor.getAllMarks())) {
      if (cMark.cid !== mark.cid || seenMarks.indexOf(cMark) !== -1) {
        continue;
      }
      let cPos = cMark.find().from;

      seenMarks.push(cMark);
      depts.push({
        mark: cMark,
        value: Cr.nearestValue(cPos),
        type: "connection",
        line: cPos.line,
        lineParsed: Cr.editor.getLineHandle(cPos.line).parsed,
        depts: Cr.dependentsOn(cMark, seenMarks)
      });
    }
  }

  let { parsed } = Cr.editor.getLineHandle(pos.line);
  let freeSpan = Cr.getFreeMarkedSpans(pos.line)[0];
  if (freeSpan != null) {
    let freeMark = freeSpan.marker;
    let freePos = {
      line: pos.line,
      ch: freeSpan.from
    };

    if (parsed != null && !Cr.eq(freePos, pos)) {
      let freeValue = Cr.nearestValue(freePos);
      let value = Cr.nearestValue(pos);

      let lineText = Cr.editor.getLine(pos.line);

      seenMarks.push(freeMark);
      depts.push({
        mark: freeMark,
        value: freeValue,
        type: "free",
        line: pos.line,
        lineParsed: parsed,
        depts: Cr.dependentsOn(freeMark, seenMarks)
      });
    }
  }

  return depts;
};

Cr.id = x => x;

Cr.functions = function(xValue, depts) {
  let functions = {};

  for (var dept of Array.from(depts)) {
    var f;
    if (dept.type === "connection") {
      f = Cr.id;
    } else if (dept.type === "free") {
      f = x => dept.lineParsed.substitute(xValue, x).solve()[1];
    }
    functions[dept.mark] = f;

    if (!((dept.depts != null ? dept.depts.length : undefined) > 0)) {
      continue;
    }

    let deptFunctions = Cr.functions(dept.value, dept.depts);
    for (let deptMark of Object.keys(deptFunctions || {})) {
      // run adjustment on deptFunctions' functions
      // right now, they're dept.value -> y
      // we want them to be xValue -> y
      let deptF = deptFunctions[deptMark];
      functions[deptMark] = ((f, deptF) => x => deptF(f(x)))(f, deptF);
    }
  }

  return functions;
};
