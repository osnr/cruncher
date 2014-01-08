window.Cruncher = Cr = window.Cruncher || {}

CodeMirror.TextMarker::toSerializable = ->
    return null unless @className? and
        ((@className.indexOf("connected-number")) is 0 or @className is "free-number")

    {from, to} = @.find()

    from: from
    to: to
    cid: @cid
    options:
        className: @className
        inclusiveLeft: @inclusiveLeft
        inclusiveRight: @inclusiveRight
        atomic: @atomic

$ ->
    serializeDoc = ->
        JSON.stringify
            version: Cr.VERSION
            text: Cr.editor.getValue()
            marks: (m for m in (mark.toSerializable() \
                for mark in Cr.editor.getAllMarks()) \
                    when m?)
            , null, 2

    deserializeDoc = (data, title) ->
        data = JSON.parse data
        Cr.editor.swapDoc (CodeMirror.Doc data.text, 'cruncher')

        for mark in data.marks
            newMark = Cr.editor.markText mark.from, mark.to, mark.options
            newMark.cid = mark.cid

        Cr.swappedDoc title

    ($ '.new-doc').click ->
        Cr.editor.swapDoc (CodeMirror.Doc '', 'cruncher')
        Cr.swappedDoc 'Untitled'

    ($ '.open-doc').click ->
        ($ '#file-chooser').click()

    ($ '#file-chooser').change (event) ->
        file = event.target.files[0]
        reader = new FileReader()
        reader.onload = ->
            try
                deserializeDoc(reader.result, file.name)
            catch e
                alert 'Error loading file.'

        reader.readAsText file

    ($ '.save-doc').click ->
        blob = new Blob([serializeDoc()],
            type: 'text/plain; charset=utf-8'
        )
        title = Cr.editor.doc.title
        title = (if title.match(/\.[Cc][Rr]$/) then title else title + '.cr')
        saveAs blob, title

    # ($ '.collaborate').click ->
    #     TogetherJS @
    #     false

    Cr.loadAutosave = ->
        data = localStorage['autosave']
        title = localStorage['autosave-title']
        return false unless data? and title?
        deserializeDoc data, title
        true

    Cr.autosave = ->
        localStorage['autosave'] = serializeDoc()
        localStorage['autosave-title'] = Cr.editor.doc.title
