window.Cruncher = Cr = window.Cruncher || {}

class Cr.NumberWidget
    constructor: (@value, @pos, @onLockChange) ->
        @$numberWidget = $ '<div class="number-widget"><a id="connect"><i class="icon-link"></i></a><a id="unlock"><i class="icon-lock"></i></a></div>'

        for span in Cr.getFreeMarkedSpans @pos.line
            if span.from == @value.start and span.to == @value.end and
            span.marker.className == 'free-number'
                @mark = span.marker
                break

    show: ->
        ($ '.number-widget').remove()
        
        Cr.editor.addWidget
            line: @pos.line
            ch: @value.start,
            @$numberWidget[0]

        @$number = $ '.hovering-number'
        @$number.mouseleave @endHover

        @$numberWidget #.width(($ this).width())
            .offset (index, coords) ->
                top: coords.top
                left: coords.left
            .mouseenter =>
                @$number.unbind 'mouseleave'

                @$numberWidget
                    .stop(true)
                    .animate(opacity: 100)
                    .mouseleave @endHover
            
            .on 'click', '#unlock', =>
                @setFreeNumber()

                @onLockChange @pos.line
                
            .on 'click', '#lock', =>
                @unsetFreeNumber()

                @onLockChange @pos.line

            .on 'mousedown', '#connect', (event) =>
                fromCoords = Cr.editor.charCoords
                    line: @pos.line
                    ch: @value.start
                toCoords = Cr.editor.charCoords
                    line: @pos.line
                    ch: @value.end

                Cr.startConnect 0, @value,
                    (toCoords.left + fromCoords.left) / 2,
                    (fromCoords.bottom + fromCoords.top) / 2

                @endHover()

        @setFreeNumber ($ '#unlock') if @mark?

    endHover: =>
        @$numberWidget.fadeOut 200, =>
            @$number.removeClass 'hovering-number'
            @$numberWidget.remove()

    setFreeNumber: ($target) =>
        if not @mark?
            @mark = Cr.editor.markText { line: @pos.line, ch: @value.start },
                { line: @pos.line, ch: @value.end },
                { className: 'free-number' }

        ($ '#unlock')
            .attr('id', 'lock')
            .find('i')
                .removeClass('icon-lock')
                .addClass 'icon-unlock'
        @$numberWidget.addClass 'free-number-widget'

    unsetFreeNumber: ($target) =>
        if @mark?
            @mark.clear()
            @mark = null

        ($ '#lock')
            .attr('id', 'unlock')
            .find('i')
                .removeClass('icon-unlock')
                .addClass 'icon-lock'
        @$numberWidget.removeClass 'free-number-widget'
