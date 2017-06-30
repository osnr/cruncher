let Cr;
window.Cruncher = Cr = window.Cruncher || {};

Cr.VERSION = "2017-02-06";

$(function() {
  let editor, evalLine, markAsFree;
  let onEquals = function(cm) {
    let cursor = cm.getCursor("end");

    return cm.replaceRange(
      "=",
      {
        line: cursor.line,
        ch: cursor.ch
      },
      {
        line: cursor.line,
        ch: cm.getLine(cursor.line).length
      }
    );
  };

  Cr.editor = editor = null;
  Cr.editor = editor = CodeMirror.fromTextArea($("#code")[0], {
    lineNumbers: false,
    lineWrapping: true,
    gutters: ["lineState"],
    theme: "cruncher",
    autofocus: true,
    extraKeys: {
      "=": onEquals
    }
  });

  // There are two extra properties we put on each line handle in CodeMirror.
  //     evaluating: is this line being evaluated?
  //     parsed: parse / evaluation object for the line (Equation or Expression)
  // They're attached to the handle so that they follow the line around if it moves.

  // generate unique ids for text markers
  CodeMirror.TextMarker.prototype.toString = (function() {
    let id = 0;
    return function() {
      return this.id != null ? this.id : (this.id = id++);
    };
  })();

  CodeMirror.TextMarker.prototype.replaceContents = function(text, origin) {
    let { from, to } = this.find();
    let overlapMarks = editor.findMarksAt(from);

    let incLefts = [];
    let incRights = [];
    for (var mark of Array.from(overlapMarks)) {
      incLefts[mark] = mark.inclusiveLeft;
      incRights[mark] = mark.inclusiveRight;
      mark.inclusiveLeft = true;
      mark.inclusiveRight = true;
    }

    Cr.editor.replaceRange(text, from, to, origin);
    for (mark of Array.from(overlapMarks)) {
      mark.inclusiveLeft = incLefts[mark];
      mark.inclusiveRight = incRights[mark];
    }

    return this;
  };

  let reparseLine = function(line) {
    let parsed;
    let text = editor.getLine(line);
    let handle = editor.getLineHandle(line);

    let textToParse = text;

    let spans = Cr.getFreeMarkedSpans(line);
    for (let span of Array.from(spans)) {
      textToParse =
        textToParse.substring(0, span.from) +
        Array(span.to - span.from + 1).join("") + // horrifying hack
        textToParse.substring(span.to);
    }

    try {
      parsed = parser.parse(textToParse);
      if ((parsed != null ? parsed.values : undefined) != null) {
        for (let value of Array.from(parsed.values)) {
          value.line = line;
        }
        handle.parsed = parsed;
      } else {
        handle.parsed = null;
      }

      return Cr.unsetLineState(line, "parseError");
    } catch (e) {
      console.log("parse error", e, line, textToParse);
      handle.parsed = null;
      Cr.setLineState(line, "parseError");

      let i = 0;
      let firstToken = null;
      return (() => {
        let result = [];
        while (!firstToken && i < text.length) {
          firstToken = Cr.editor.getTokenTypeAt({ line, ch: i });
          result.push((i += 1));
        }
        return result;
      })();
    }
  };

  Cr.markAsFree = markAsFree = (from, to) =>
    editor.markText(from, to, {
      className: "free-number",
      inclusiveLeft: false,
      inclusiveRight: false,
      atomic: true
    });

  let oldCursor = null;
  let solveChange = function(instance, changeObj) {
    // runs while evaluating and constraining a line
    // returns weakened version of onChange handler that just makes sure
    // user's cursor stays in a sane position while we evalLine
    //
    // e.g. {2} |+ 3 = 5 -> {20} |+ 3 = 5
    //      we shift the cursor right 1 character
    if (
      changeObj.to.line === oldCursor.line &&
      oldCursor.ch > changeObj.from.ch
    ) {
      let cursorOffset =
        changeObj.text[0].length - (changeObj.to.ch - changeObj.from.ch);
      let newCursor = {
        line: oldCursor.line,
        ch: oldCursor.ch + cursorOffset
      };
      editor.setCursor(newCursor);
      return (oldCursor = newCursor);
    } else {
      return editor.setCursor(oldCursor);
    }
  };

  Cr.evalLine = evalLine = function(line) {
    // runs after a line changes
    // (except, of course, when evalLine is the changer)
    // reconstrain the free number(s) [currently only 1 is supported]
    // so that the equation is true,
    // or make the line an equation

    let from, mark;
    let s;
    reparseLine(line);

    for (let stateName of ["overDetermined", "underDetermined"]) {
      Cr.unsetLineState(line, stateName);
    }

    let handle = editor.getLineHandle(line);

    // intercept change events for this line,
    // but pass other lines (which might be dependencies)
    // through to the normal handler
    // TODO deal with circular dependencies (this makes them undefined behavior)
    handle.evaluating = true;
    oldCursor = editor.getCursor();

    let text = editor.getLine(line);
    let { parsed } = handle;
    if ((parsed != null ? parsed.constructor : undefined) === Cr.Expression) {
      // edited a line without another side (yet)
      if (typeof parsed.num === "function") {
        // we have an expression with a free number in it
        // just lock it
        mark = (() => {
          let result = [];
          for (s of Array.from(Cr.getFreeMarkedSpans(line))) {
            result.push(s.marker);
          }
          return result;
        })()[0];
        mark.clear();

        reparseLine(line);
        evalLine(line);
      } else {
        let freeString = parsed.numString();

        from = {
          line,
          ch: text.length + " = ".length
        };
        let to = {
          line,
          ch: text.length + " = ".length + freeString.length
        };

        editor.replaceRange(` = ${freeString}`, from, null, "+solve");
        markAsFree(from, to);

        reparseLine(line);
      }
    } else if (
      (parsed != null ? parsed.constructor : undefined) === Cr.Equation
    ) {
      try {
        let [freeValue, solution] = Array.from(parsed.solve());

        mark = (() => {
          let result1 = [];
          for (s of Array.from(Cr.getFreeMarkedSpans(line))) {
            result1.push(s.marker);
          }
          return result1;
        })()[0];

        oldCursor = editor.getCursor();

        let sig = Cr.sig(
          text.substring(0, freeValue.start) + text.substring(freeValue.end)
        );
        mark.replaceContents(Cr.roundSig(solution, sig), "+solve");

        editor.setCursor(oldCursor);

        if (handle.equalsMark != null) {
          handle.equalsMark.clear();
        }
        reparseLine(line);
      } catch (e) {
        if (e instanceof Cr.OverDeterminedException) {
          Cr.setLineState(line, "overDetermined");
          Cr.updateSign(line, handle);
        } else if (e instanceof Cr.UnderDeterminedException) {
          Cr.setLineState(line, "underDetermined");
        } else {
          throw e;
        }
      }
    }

    return (handle.evaluating = false);
  };

  editor.on("change", function(instance, changeObj) {
    let handle, lineRange;
    if (Cr.scr != null) {
      return;
    } // don't catch if scrubbing

    setTitle(editor.doc.title); // mark unsaved in title

    for (let adjustment of Array.from(editor.doc.adjustments)) {
      adjustment();
    }
    editor.doc.adjustments = [];

    if (changeObj.origin === "+solve" && editor.doc.history.done.length >= 2) {
      // automatic origin -- merge with last change (hack)
      let { history } = editor.doc;
      let lastChange = history.done.pop();
      let prevChange = history.done.pop();
      $.merge(prevChange.changes, lastChange.changes);
      prevChange.headAfter = lastChange.headAfter;
      prevChange.anchorAfter = lastChange.anchorAfter;
      history.done.push(prevChange);
    }

    // executes on user or cruncher change to text
    // (except during evalLine)
    if (changeObj.removed.length > 1) {
      lineRange = __range__(
        changeObj.from.line,
        Cruncher.editor.lineCount() - 1,
        true
      );
    } else {
      lineRange = __range__(
        changeObj.from.line,
        changeObj.to.line + changeObj.text.length - 1,
        true
      );
    }

    for (var line of Array.from(lineRange)) {
      handle = editor.getLineHandle(line);
      if (!handle) {
        continue;
      }

      if (handle.evaluating) {
        solveChange(instance, changeObj);
      } else {
        evalLine(line);
      }
    }

    // replace all value locations that might be affected by a newline
    if (changeObj.text.length > 1) {
      let asc, end, start;
      for (
        start = changeObj.to.line + 1, line = start, end =
          editor.lineCount() - 1, asc = start <= end;
        asc ? line <= end : line >= end;
        asc ? line++ : line--
      ) {
        handle = editor.getLineHandle(line);
        if (
          (handle.parsed != null ? handle.parsed.values : undefined) == null
        ) {
          continue;
        }

        for (let value of Array.from(handle.parsed.values)) {
          value.line = line;
        }
      }
    }

    return Cr.updateConnectionsForChange(changeObj);
  });

  let includeInMark = function(mark) {
    mark.inclusiveLeft = true;
    mark.inclusiveRight = true;

    return editor.doc.adjustments.push(function() {
      mark.inclusiveLeft = false;
      return (mark.inclusiveRight = false);
    });
  };

  editor.on("beforeSelectionChange", function(instance, selection) {
    if (Cr.scr == null) {
      return;
    }

    selection.head = editor.getCursor("head");
    return (selection.anchor = editor.getCursor("anchor"));
  });

  editor.on("beforeChange", function(instance, changeObj) {
    let endRange, startRange;
    let m;
    if (Cr.settings && !Cr.settings.editable && !Cr.scr) {
      changeObj.cancel();
    }

    if (changeObj.origin === "+delete" || Cr.scr != null) {
      return;
    }

    let startMark = (() => {
      let result = [];
      for (m of Array.from(editor.findMarksAt(changeObj.from))) {
        if (m.cid != null) {
          result.push(m);
        }
      }
      return result;
    })()[0];
    let endMark = (() => {
      let result1 = [];
      for (m of Array.from(editor.findMarksAt(changeObj.to))) {
        if (m.cid != null) {
          result1.push(m);
        }
      }
      return result1;
    })()[0];

    if (startMark != null && endMark == null) {
      startRange = startMark.find();
      if (Cr.inside(startRange.from, changeObj.from, startRange.to)) {
        return changeObj.cancel();
      }
    } else if (endMark != null && startMark == null) {
      endRange = endMark.find();
      if (Cr.inside(endRange.from, changeObj.to, endRange.to)) {
        return changeObj.cancel();
      }
    } else if (startMark != null && endMark != null) {
      startRange = startMark.find();
      endRange = endMark.find();
      if (startMark !== endMark) {
        if (
          Cr.inside(startRange.from, changeObj.from, startRange.to) ||
          Cr.inside(endRange.from, changeObj.to, endRange.to)
        ) {
          return changeObj.cancel();
        }
      } else if (
        Cr.inside(startRange.from, changeObj.from, startRange.to) &&
        (changeObj.text.length > 1 || !/^[\-0-9\.,]+$/.test(changeObj.text[0]))
      ) {
        return changeObj.cancel();
      } else if (
        (changeObj.text.length === 1 &&
          /^[\-0-9\.,]+$/.test(changeObj.text[0])) ||
        (changeObj.origin == null && !/^ = /.test(changeObj.text[0]))
      ) {
        return includeInMark(startMark);
      }
    }
  }); // (== endMark)

  $(document).on(
    "mouseenter.start-hover",
    ".cm-number:not(.locked-number)",
    Cr.startHover
  );

  $(document).on("click", ".lock:not(.in-lock-mode)", function() {
    // go into lock mode
    $(document).off("mouseenter.start-hover", ".cm-number:not(.locked-number)");

    $(document).on("mouseup", ".cm-number:not(.free-number)", function(e) {
      let pos = Cr.editor.coordsChar({
        left: e.pageX,
        top: e.pageY
      });

      let value = Cr.nearestValue(pos);

      if ($(e.target).hasClass("locked-number")) {
        let marks = editor.findMarksAt(pos);
        return (() => {
          let result = [];
          for (let m of Array.from(marks)) {
            if (m.className === "locked-number") {
              result.push(m.clear());
            } else {
              result.push(undefined);
            }
          }
          return result;
        })();
      } else {
        return editor.markText(Cr.valueFrom(value), Cr.valueTo(value), {
          className: "locked-number",
          inclusiveLeft: false,
          inclusiveRight: false,
          atomic: true
        });
      }
    });

    $(this).addClass("in-lock-mode");
    return $(".CodeMirror").addClass("in-lock-mode");
  });

  $(document).on("click", ".lock.in-lock-mode", function() {
    // end lock mode
    $(document).on(
      "mouseenter.start-hover",
      ".cm-number:not(.locked-number)",
      Cr.startHover
    );

    $(this).removeClass("in-lock-mode");
    return $(".CodeMirror").removeClass("in-lock-mode");
  });

  editor.refresh();

  Cr.forceEval = () =>
    __range__(0, editor.lineCount() - 1, true).map(line => evalLine(line));

  var setTitle = function(title) {
    editor.doc.title = title;
    document.title =
      (editor.doc.isClean() ? "" : "(UNSAVED) ") + title + " - Cruncher";
    return $("#file-name").val(title);
  };

  Cr.markClean = function() {
    editor.doc.markClean();
    return setTitle(editor.doc.title);
  };

  Cr.swappedDoc = function(mode, settings) {
    if (mode == null) {
      mode = "edit";
    }
    Cr.settings = settings;
    let { key } = editor.doc;

    if (mode === "edit") {
      $("#toolbar").show();
      $(".edit").show();
      $(".view").hide();

      $("#embed-to-view").hide();

      $("#container").removeClass("embed");
      history.replaceState({}, "", `?/${key}`);
    } else if (mode === "view") {
      $("#toolbar").show();
      $(".edit").hide();
      $(".view").show();

      $("#embed-to-view").hide();

      $("#container").removeClass("embed");
      history.replaceState({}, "", `?/view/${key}`);
    } else if (mode === "embed") {
      $("#toolbar").hide();

      $("#embed-to-view").show();
      $("#embed-to-view").click(() =>
        window.open(document.location.origin + "?/view/" + key)
      );

      $("#container").addClass("embed");
      history.replaceState({}, "", `?/embed/${key}`);
    }

    if (mode === "edit" || mode === "view") {
      window.onbeforeunload = function() {
        if (editor.doc.isClean()) {
          return;
        }

        return (
          "You haven't saved your Cruncher document since changing it. " +
          "If you close this window, you might lose your data."
        );
      };
    } else {
      window.onbeforeunload = function() {};
    }

    if (mode === "view" || mode === "embed") {
      if (!settings.gutter) {
        $(".CodeMirror-gutters").hide();
        $(".CodeMirror-sizer").css("margin-left", "0px");
      }
    }

    // editable handled in onBeforeChange and in scrubbing.coffee
    // scrubbable, hints are handled in scrubbing.coffee

    editor.refresh();

    editor.doc.adjustments = [];
    Cr.forceEval();
    return setTitle(editor.doc.title);
  };

  $("#file-name").on("change keyup paste", function() {
    let title = $(this).val();
    if (title === editor.doc.title) {
      return;
    }

    if (title == null || title.match(/^ *$/)) {
      console.log("Invalid title");
      return;
    }
    // TODO alert

    return setTitle(title);
  });

  (function() {
    let paramKey = window.location.search.substring(2);

    if (paramKey === "") {
      return Cr.newDoc();
    } else if (paramKey.substring(0, "view/".length) === "view/") {
      let viewKey = paramKey.substring("view/".length);
      return Cr.loadView(viewKey);
    } else if (paramKey.substring(0, "embed/".length) === "embed/") {
      $("#toolbar").hide();
      $("#container").addClass("embed");
      let embedKey = paramKey.substring("embed/".length);
      return Cr.loadEmbed(embedKey);
    } else {
      return Cr.loadDoc(paramKey);
    }
  })();

  if (!localStorage["dontIntro"]) {
    $("#about").modal("show");
    localStorage["dontIntro"] = true;
  }

  $(".about").click(() => $("#about").modal("show"));
  return $(".show-plot-example").click(function() {
    if ($(".plot-example:visible").length) {
      return $(".plot-example").slideUp(() =>
        $(".plot-example img").attr("src", "")
      );
    } else {
      $(".plot-example img").attr("src", "res/chart.gif");
      return $(".plot-example").slideDown();
    }
  });
});

function __range__(left, right, inclusive) {
  let range = [];
  let ascending = left < right;
  let end = !inclusive ? right : ascending ? right + 1 : right - 1;
  for (let i = left; ascending ? i < end : i > end; ascending ? i++ : i--) {
    range.push(i);
  }
  return range;
}
