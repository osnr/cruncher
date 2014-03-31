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
            title: Cr.editor.doc.title
            text: Cr.editor.getValue()
            marks: (m for m in (mark.toSerializable() \
                for mark in Cr.editor.getAllMarks()) \
                    when m?)
            , null, 2

    deserializeDoc = (data, uid) ->
        data = JSON.parse data
        uid = uid ? Cr.editor.doc.uid # reuse old UID if necessary
        Cr.editor.swapDoc (CodeMirror.Doc data.text, 'cruncher')

        for mark in data.marks
            newMark = Cr.editor.markText mark.from, mark.to, mark.options
            newMark.cid = mark.cid

        Cr.swappedDoc uid, data.title

    ($ '.new-doc').click ->
        do Cr.newDoc

    ($ '.open-doc').click ->
        ($ '#file-chooser').click()

    ($ '#file-chooser').change (event) ->
        file = event.target.files[0]
        reader = new FileReader()
        reader.onload = ->
            try
                deserializeDoc reader.result
            catch e
                alert 'Error loading file.'

        reader.readAsText file
        this.value = null

    ($ '.save-doc').click ->
        blob = new Blob([serializeDoc()],
            type: 'text/plain; charset=utf-8'
        )
        title = Cr.editor.doc.title
        title = (if title.match(/\.[Cc][Rr]$/) then title else title + '.cr')
        saveAs blob, title

    Cr.loadExample = (tid) ->
        ($ '#loading').fadeIn()
    
        ($.get 'https://cruncher-examples.s3.amazonaws.com/' + tid, (data) ->
            ($ '#loading').fadeOut()
            deserializeDoc data, Cr.generateUid()
        ).fail ->
            ($ '#loading').fadeOut()
            do Cr.newDoc

    Cr.loadDoc = (uid) ->
        ($ '#loading').fadeIn()
    
        ($.get 'https://cruncher-files.s3.amazonaws.com/' + uid, (data) ->
            ($ '#loading').fadeOut()
            deserializeDoc data, uid
        ).fail ->
            ($ '#loading').fadeOut()
            Cr.newDoc uid

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
