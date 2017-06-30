let hover, scr;
window.Cruncher = Cr = window.Cruncher || {};

Cr.hover = hover = null;
Cr.scr = scr = null;

Cr.startHover = function(enterEvent) {
  // add hover class, construct number widget
  // when user hovers over a number
  if (scr != null) {
    return;
  }

  let hoverPos = Cr.editor.coordsChar({
    left: enterEvent.pageX,
    top: enterEvent.pageY
  });

  let hoverValue = Cr.nearestValue(hoverPos);

  if (hoverValue == null) {
    hoverPos = Cr.editor.coordsChar({
      left: enterEvent.pageX,
      // ugly hack because coordsChar's hit box
      // doesn't quite line up with the DOM hover hit box
      top: enterEvent.pageY + 2
    });

    hoverValue = Cr.nearestValue(hoverPos);
  }

  if (
    hoverValue === (hover != null ? hover.value : undefined) ||
    hoverValue == null
  ) {
    return;
  }
  endHover();

  Cr.hover = hover = {
    pos: hoverPos,
    value: hoverValue
  };

  hover.mark = Cr.editor.markText(
    Cr.valueFrom(hoverValue),
    Cr.valueTo(hoverValue),
    {
      className: "hovering-number",
      inclusiveLeft: true, // so mark survives replacement of its inside
      inclusiveRight: true
    }
  );

  if (!Cr.settings || Cr.settings.scrubbable) {
    $(".CodeMirror-code .hovering-number")
      .not(".free-number")
      .on("mousedown.scrub", startDrag(hover.value, hover.mark));
  }

  if (!Cr.settings || Cr.settings.hints) {
    $("#keys").stop(true, true).show();
  }

  if (enterEvent.ctrlKey || enterEvent.metaKey) {
    Cr.addGraph(hover.mark, Cr.dependentsOn(hover.mark));
  }
  $(document)
    .on("mousemove.hover", function(event) {
      if (
        !$(event.target).is(".hovering-number") &&
        !($(event.target).closest(".number-widget").length > 0)
      ) {
        return endHover();
      }
    })
    .on("mousedown", function(event) {
      if ($(event.target).closest(".number-widget").length > 0) {
        return;
      }
      return endHover();
    })
    .on("keydown.deps", function(event) {
      if (!event.ctrlKey && !event.metaKey) {
        return;
      }
      return Cr.addGraph(hover.mark, Cr.dependentsOn(hover.mark));
    })
    .on("keyup.deps", function(event) {
      if (event.which !== 17 && event.which !== 91 && event.which !== 93) {
        return;
      } // ctrl, cmd key
      return Cr.removeGraph();
    });

  if (!Cr.settings || Cr.settings.editable) {
    return new Cr.NumberWidget(hover.value, hover.pos, function(line) {
      return Cr.evalLine(line);
    }).show();
  }
};

var endHover = function() {
  if (scr == null) {
    __guard__(hover != null ? hover.mark : undefined, x => x.clear());
  }
  Cr.hover = hover = null;

  $(document).off("mousemove.hover keydown.deps keyup.deps");
  Cr.removeGraph();

  $(".number-widget").remove();

  return $("#keys").hide();
};

var startDrag = function(value, mark) {
  return downEvent => {
    // initiate and handle dragging/scrubbing behavior

    let chartMarks, left;
    $(document).off("mousemove.scrub").off("mouseup.scrub");
    __guard__(scr != null ? scr.mark : undefined, x => x.clear());
    $(".number-widget").remove();
    Cr.editor.eachLine(function(handle) {
      if (handle.g == null) {
        return;
      }
      handle.g.widget.clear();
      return delete handle.g;
    });

    let origin = Cr.editor.coordsChar({
      left: downEvent.pageX,
      top: downEvent.pageY
    });

    Cr.scr = scr = {};

    scr.origNum = scr.num = value.num;
    scr.origNumString = value.numString();
    scr.fixedDigits = (left = __guard__(
      value.numString().split(".")[1],
      x1 => x1.length
    )) != null
      ? left
      : 0;

    scr.mark = mark;

    let depts = Cr.dependentsOn(scr.mark);
    let fns = Cr.functions(value, depts);

    let charting = downEvent.altKey;
    if (charting) {
      chartMarks = Cr.addCharts(depts, fns);
    }
    // TODO add graph

    let xCenter = downEvent.pageX;

    var replaceDepts = (depts, fns, x) =>
      (() => {
        let result = [];
        for (let dept of Array.from(depts)) {
          dept.mark.replaceContents(
            Cr.roundSig(fns[dept.mark](x), 1),
            "*scrubsolve"
          );
          result.push(replaceDepts(dept.depts, fns, x));
        }
        return result;
      })();

    let onDragMove = moveEvent => {
      let xOffset = moveEvent.pageX - xCenter;

      if (scr.origNumString.startsWith("0.")) {
        scr.delta = Math.round(xOffset / 5) / Math.pow(10, scr.fixedDigits);
        console.log(scr.delta, scr.fixedDigits);
      } else {
        scr.delta = Math.round(xOffset / 5);
      }

      if (scr.delta !== 0 && !isNaN(scr.delta)) {
        let range = scr.mark.find();

        scr.num = scr.origNum + scr.delta;

        let numString = scr.num.toFixed(scr.fixedDigits);
        scr.mark.replaceContents(numString, "*scrubsolve");
        replaceDepts(depts, fns, scr.num);

        if (charting) {
          return Cr.updateCharts(chartMarks);
        }
      }
    };

    let onDragUp = () => {
      scr.mark.clear();

      $(document).off("mousemove.scrub").off("mouseup.scrub");

      if (charting) {
        Cr.removeCharts();
      }

      // TODO remove this selection-restoring hack
      setTimeout(function() {
        Cr.editor.focus();
        return Cr.editor.setCursor(origin);
      }, 100);

      Cr.scr = scr = null;

      // since scrubbing doesn't use the standard
      // evaluator, we need to eval the line with that
      // to make everything match again afterward
      let changedLines = $.unique(Array.from(depts).map(dept => dept.line));
      return (() => {
        let result = [];
        for (let line of Array.from(changedLines)) {
          result.push(Cr.evalLine(line));
        }
        return result;
      })();
    };

    $(document).on("mousemove.scrub", onDragMove).on("mouseup.scrub", onDragUp);
    return $(this).off("mousedown.scrub");
  };
};

function __guard__(value, transform) {
  return typeof value !== "undefined" && value !== null
    ? transform(value)
    : undefined;
}
