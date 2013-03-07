class window.NumberWidget
    constructor: (@token, @pos, @onUnlock) ->
        @$numberWidget = $ '<div class="number-widget"><a id="link"><i class="icon-link"></i></a><a id="unlock"><i class="icon-lock"></i></a></div>'

        @mark = editor.findMarksAt(@pos)[0]

    show: ->
        ($ '.number-widget').remove()
        
        editor.addWidget
            line: @pos.line
            ch: @token.start,
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

                @onUnlock @pos.line
                
            .on 'click', '#lock', =>
                @unsetFreeNumber()

        @setFreeNumber ($ '#unlock') if @mark?

    endHover = ->
        ($ '.number-widget').fadeOut 200, ->
            ($ '.hovering-number').removeClass('hovering-number')
            ($ this).remove()

    setFreeNumber: ($target) =>
        if not @mark?
            @mark = editor.markText { line: @pos.line, ch: @token.start },
                { line: @pos.line, ch: @token.end },
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