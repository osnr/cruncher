exports.getLine = (line) ->
    casper.evaluate ((line) -> Cruncher.editor.getLine line), line

exports.getCursor = ->
    casper.evaluate -> Cruncher.editor.getCursor()
