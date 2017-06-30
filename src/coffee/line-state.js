let Cr;
window.Cruncher = Cr = window.Cruncher || {};

let makeGutterMarker = (stateClass, iconClass, tooltip) => () =>
  $('<i class="fa"></i>')
    .addClass(stateClass)
    .addClass(iconClass)
    .attr("title", tooltip)
    .tooltip({
      html: true,
      placement: "bottom",
      container: "body"
    })
    .get(0);

let lineStates = {
  parseError: {
    gutterMarker: makeGutterMarker(
      "parse-error-icon",
      "fa-question-circle",
      "I can't understand this line."
    ),
    bgClass: "parse-error-line",
    wrapClass: "parse-error"
  },

  overDetermined: {
    gutterMarker: makeGutterMarker(
      "over-determined-icon",
      "fa-pencil-square",
      'This line is entirely <span class="over-determined-locked">human-controlled numbers <i class="fa fa-pencil-square"></span></i>.<br>I can\'t change anything to make the left and right side equal.'
    ),
    bgClass: "over-determined-line",
    wrapClass: "over-determined"
  },

  underDetermined: {
    gutterMarker: makeGutterMarker(
      "under-determined-icon",
      "fa-cogs",
      'This line has too many <span class="under-determined-free">computer-controlled numbers <i class="fa fa-cogs"></i></span>! ' +
        "I don't know how to solve it."
    ),
    bgClass: "under-determined-line",
    wrapClass: "under-determined"
  }
};

// assumption: only one line state at a time
Cr.setLineState = function(line, stateName) {
  let state = lineStates[stateName];

  Cr.editor.setGutterMarker(line, "lineState", state.gutterMarker());
  Cr.editor.addLineClass(line, "background", state.bgClass);
  Cr.editor.addLineClass(line, "wrap", state.wrapClass);

  return (Cr.editor.getLineHandle(line).state = stateName);
};

Cr.unsetLineState = function(line, stateName) {
  let handle = Cr.editor.getLineHandle(line);
  if (handle.state == null || handle.state !== stateName) {
    return;
  }

  let state = lineStates[stateName];

  Cr.editor.setGutterMarker(line, "lineState", null);

  Cr.editor.removeLineClass(line, "background", state.bgClass);
  Cr.editor.removeLineClass(line, "wrap", state.wrapClass);

  return delete handle.state;
};

Cr.getLineState = line => Cr.editor.getLineHandle(line).state;

Cr.updateSign = function(line, handle) {
  let replacedWith;
  if (handle.equalsMark != null) {
    handle.equalsMark.clear();
  }

  let idx = handle.text.indexOf("=");
  if (!(idx > -1)) {
    return;
  }

  let leftNum = handle.parsed.left.num;
  let rightNum = handle.parsed.right.num;

  if (Math.abs(leftNum - rightNum) < 1e-5) {
    replacedWith = $("<span>&#8776;</span>")[0];
  } else if (leftNum < rightNum) {
    replacedWith = $("<span>&lt;</span>")[0];
  } else if (leftNum > rightNum) {
    replacedWith = $("<span>&gt;</span>")[0];
  }

  return (handle.equalsMark = Cr.editor.markText(
    {
      line,
      ch: idx
    },
    {
      line,
      ch: idx + 1
    },
    { replacedWith }
  ));
};
