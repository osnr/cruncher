let Cr;
window.Cruncher = Cr = window.Cruncher || {};

let eps = 1e-7;

// from Numerical Recipes, 9.1
let bracket = function(f, x1, x2) {
  let ntry = 50;
  let factor = 1.6;
  if (x1 === x2) {
    throw "Bad initial range in bracket";
  }

  let f1 = f(x1);
  let f2 = f(x2);
  for (
    let j = 1, end = ntry, asc = 1 <= end;
    asc ? j <= end : j >= end;
    asc ? j++ : j--
  ) {
    if (f1 * f2 < 0.0) {
      return [x1, x2];
    }
    if (Math.abs(f1) < Math.abs(f2)) {
      x1 += factor * (x1 - x2);
      f1 = f(x1);
    } else {
      x2 += factor * (x2 - x1);
      f2 = f(x2);
    }
  }
  return false;
};

let dx = 1e-7;
let derivative = f => x => (f(x + dx) - f(x)) / dx;

var secantMethod = function(f, x, fp, numIters) {
  let middle;
  fp = fp != null ? fp : derivative(f);
  numIters = numIters != null ? numIters : 0;

  if (-eps < (middle = f(x)) && middle < eps) {
    return x;
  } else if (numIters > 500) {
    return NaN;
  } else {
    return secantMethod(f, x - f(x) / fp(x), fp, numIters + 1);
  }
};

Cr.findRoot = function(f, x1, x2) {
  // FIXME: hack reverting to pure secant method

  // return if it actually is a root (could be a singularity)
  if (Math.abs(f(root)) < eps) {
    return root;
  }

  // not working? throw it at secant method, why not
  var root = secantMethod(f, 1);
  if (!isNaN(root) && Math.abs(f(root)) < eps) {
    return root;
  }

  return NaN;
};
