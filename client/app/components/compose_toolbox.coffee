{div, button, span} = React.DOM

{Spinner} = require './basic_components'

module.exports = ComposeToolbox = React.createClass
    displayName: 'ComposeToolbox'

    render: ->
        if @props.sending
            labelSend = t 'compose action sending'
        else
            labelSend = t 'compose action send'

        div className: 'composeToolbox',
            div className: 'btn-toolbar', role: 'toolbar',
                div className: '',
                    button
                        className: 'btn btn-cozy btn-send',
                        type: 'button',
                        disable: if @props.sending then true else null
                        onClick: @onSend,
                            if @props.sending
                                span null, Spinner(color: 'white')
                            else
                                span className: 'fa fa-send'
                            span null, labelSend
                    button
                        className: 'btn btn-cozy btn-save',
                        disable: if @props.saving then true else null
                        type: 'button', onClick: @onDraft,
                            if @props.saving
                                span null, Spinner(color: 'white')
                            else
                                span className: 'fa fa-save'
                            span null, t 'compose action draft'
                    if @props.canDelete
                        button
                            className: 'btn btn-cozy-non-default btn-delete',
                            type: 'button',
                            onClick: @onDelete,
                                span className: 'fa fa-trash-o'
                                span null, t 'compose action delete'
                    button
                        onClick: @onCancel
                        className: 'btn btn-cozy-non-default btn-cancel',
                        t 'app cancel'

    # @TODO : replace button by a and remove these proxy functions
    onSave: (e) ->
        e.preventDefault()
        @props.onSave()

    onDraft: (e) ->
        e.preventDefault()
        @props.onDraft()

    onDelete: (e) ->
        e.preventDefault()
        @props.onDelete()

    onCancel: (e) ->
        e.preventDefault()
        @props.onCancel()
