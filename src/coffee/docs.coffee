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
            uid: Cr.editor.doc.uid
            title: Cr.editor.doc.title
            text: Cr.editor.getValue()
            marks: (m for m in (mark.toSerializable() \
                for mark in Cr.editor.getAllMarks()) \
                    when m?)
            , null, 2

    deserializeDoc = (data) ->
        data = JSON.parse data
        Cr.editor.swapDoc (CodeMirror.Doc data.text, 'cruncher')

        for mark in data.marks
            newMark = Cr.editor.markText mark.from, mark.to, mark.options
            newMark.cid = mark.cid

        Cr.swappedDoc data.uid, data.title

    ($ '.new-doc').click ->
        do Cr.newDoc

    ($ '.open-doc').click ->
        ($ '#file-chooser').click()

    ($ '#file-chooser').change (event) ->
        file = event.target.files[0]
        reader = new FileReader()
        reader.onload = ->
            try
                deserializeDoc reader.result, file.name
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

    Cr.loadDoc = (uid) ->
        ($ '#loading').fadeIn()
    
        ($.get 'https://cruncher-files.s3.amazonaws.com/' + uid, (data) ->
            ($ '#loading').fadeOut()
            deserializeDoc data
        ).fail ->
            ($ '#loading').fadeOut()
            do Cr.newDoc

    Cr.saveDoc = (uid) ->
        do Cr.editor.doc.markClean
        $.ajax 'https://cruncher-files.s3.amazonaws.com/' + uid,
            type: 'PUT'
            data: serializeDoc()
            success: (data, status) -> console.log 'success', data, status
            error: (xhr, status, error) -> console.log 'error', status, error

    Cr.autosave = ->
        if not Cr.editor.doc.isClean()
            Cr.saveDoc Cr.editor.doc.uid
