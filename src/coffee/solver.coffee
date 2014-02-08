window.Cruncher = Cr = window.Cruncher || {}

eps = 1e-7

# from Numerical Recipes, 9.1
bracket = (f, x1, x2) ->
    ntry = 50
    factor = 1.6
    throw "Bad initial range in bracket" if x1 == x2

    f1 = f(x1)
    f2 = f(x2)
    for j in [1..ntry]
        return [x1, x2] if f1 * f2 < 0.0
        if Math.abs(f1) < Math.abs(f2)
            x1 += factor * (x1 - x2)
            f1 = f(x1)
        else
            x2 += factor * (x2 - x1)
            f2 = f(x2)
    return false

dx = 1e-7
derivative = (f) ->
    (x) -> ((f (x + dx)) - (f x)) / dx

secantMethod = (f, x, fp, numIters) ->
    fp = fp ? derivative f
    numIters = numIters ? 0

    if -eps < (f x) < eps
        x
    else if numIters > 50
        NaN
    else
        secantMethod f, x - (f x) / (fp x), fp, numIters + 1

Cr.findRoot = (f, x1, x2) ->
    [lowerLimit, upperLimit] = bracket(f, x1, x2)
    if lowerLimit? and upperLimit?
        # use Brent's method if we can bracket a root
        root = uniroot(f, lowerLimit, upperLimit, eps)

    # return if it actually is a root (could be a singularity)
    return root if Math.abs(f(root)) < eps

    # not working? throw it at secant method, why not
    root = secantMethod(f, x1)
    return root if !isNaN(root) and Math.abs(f(root)) < eps

    root = secantMethod(f, x2)
    return root if Math.abs(f(root)) < eps

    return NaN
