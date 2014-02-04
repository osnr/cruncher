window.Cruncher = Cr = window.Cruncher || {}

dx = 1e-7
derivative = (f) ->
    (x) -> ((f (x + dx)) - (f x)) / dx

Cr.newtonsMethod = newtonsMethod = (f, x, fp, numIters) ->
    fp = fp ? derivative f
    numIters = numIters ? 0

    if -dx < (f x) < dx
        x
    else if numIters > 1000
        NaN
    else
        newtonsMethod f, x - (f x) / (fp x), fp, numIters + 1
