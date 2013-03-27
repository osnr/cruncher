window.Cruncher = Cr = window.Cruncher || {}

class Cr.NumberWidget
    constructor: (@value, @pos, @onLockChange) ->
        @$numberWidget = $ '<div class="number-widget"><a id="link"><i class="icon-link"></i></a><a id="unlock"><i class="icon-lock"></i></a></div>'

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

        ($ '.hovering-number').mouseleave endHover

        @$numberWidget #.width(($ this).width())
            .offset (index, coords) ->
                top: coords.top
                left: coords.left
            .mouseenter ->
                ($ '.hovering-number').unbind('mouseleave')

                ($ '.number-widget')
                    .stop(true)
                    .animate(opacity: 100)
                    .mouseleave endHover
            
            .on 'click', '#unlock', =>
                @setFreeNumber()

                @onLockChange @pos.line
                
            .on 'click', '#lock', =>
                @unsetFreeNumber()

                @onLockChange @pos.line

        @setFreeNumber ($ '#unlock') if @mark?

    endHover = ->
        ($ '.number-widget').fadeOut 200, ->
            ($ '.hovering-number').removeClass('hovering-number')
            ($ this).remove()

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