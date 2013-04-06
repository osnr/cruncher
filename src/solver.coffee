window.Cruncher = Cr = window.Cruncher || {}

dx = 0.00001
derivative = (f) ->
    (x) -> ((f (x + dx)) - (f x)) / dx

Cr.newtonsMethod = newtonsMethod = (f, x, fp) ->
    fp = fp ? derivative f
    if -dx < (f x) < dx
        x
    else
        newtonsMethod f, x - (f x) / (fp x), fp
