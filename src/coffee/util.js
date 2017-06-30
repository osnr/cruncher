window.Cruncher = Cr = window.Cruncher || {};

Cr.generateUid = function() {
  let arr = new Uint32Array(2);
  window.crypto.getRandomValues(arr);

  return arr[0].toString(36) + arr[1].toString(36);
};

Cr.sig = function(text) {
  let left;
  let sig = -1;

  let numStrings = (left = text.match(
    /\d+(?:,\d+)*(?:\.\d*)?(?:[eE]-?\d+)?/g
  )) != null
    ? left
    : [];
  for (let numString of Array.from(numStrings)) {
    if (numString.indexOf(".") !== -1) {
      continue;
    }
    numString = numString.replace(/,\./g, "");
    if (sig === -1) {
      sig = numString.length;
    } else {
      sig = Math.min(sig, numString.length);
    }
  }

  return sig;
};

Cr.commafy = function(num) {
  let str = num.toString().split(".");
  if (str[0].length >= 4) {
    str[0] = str[0].replace(/(\d)(?=(\d{3})+$)/g, "$1,");
  }
  return str.join(".");
};

Cr.roundSig = function(n, sig) {
  n = Math.round(n * 1e5) / 1e5;

  let rnd = n.toString();

  if (rnd === "-0") {
    return "0";
  } else {
    return Cr.commafy(rnd);
  }
};

Cr.inside = (a, b, c) =>
  a.line <= b.line && b.line <= c.line && (a.ch < b.ch && b.ch < c.ch);

Cr.lt = (a, b) => a.line < b.line || a.ch < b.ch;

Cr.eq = (a, b) => a.line === b.line && a.ch === b.ch;

Cr.nearestValue = function(pos) {
  // find nearest number (Value) to pos = { line, ch }
  // used for identifying hover/drag target

  let { parsed } = Cr.editor.getLineHandle(pos.line);
  if (parsed == null) {
    return;
  }

  let nearest = null;
  for (let value of Array.from(parsed.values)) {
    if (value.start <= pos.ch && pos.ch <= value.end) {
      nearest = value;
      break;
    }
  }

  return nearest;
};

Cr.valueFrom = value => ({ line: value.line, ch: value.start });

Cr.valueTo = value => ({ line: value.line, ch: value.end });

Cr.valueString = value =>
  Cr.editor.getRange(Cr.valueFrom(value), Cr.valueTo(value));

Cr.getFreeMarkedSpans = function(line) {
  let handle = Cr.editor.getLineHandle(line);
  if ((handle != null ? handle.markedSpans : undefined) == null) {
    return [];
  }

  return Array.from(handle.markedSpans)
    .filter(span => span.marker.className === "free-number")
    .map(span => span);
};
