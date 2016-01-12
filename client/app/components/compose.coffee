{div, section, h3, a, i, textarea, form, label} = React.DOM
{span, ul, li, input} = React.DOM

classer = React.addons.classSet

{Spinner, Clearfix} = require './basic_components'
Editor  = require './compose_prosemirror'
ComposeToolbox = require './compose_toolbox'
FilePicker     = require './file_picker'
MailsInput     = require './mails_input'


AccountPicker = require './account_picker'

{ComposeActions, Tooltips} = require '../constants/app_constants'

MessageUtils = require '../utils/message_utils'
cachedTransform = require '../libs/cached_transform'

AccountStore  = require '../stores/account_store'

LayoutActionCreator  = require '../actions/layout_action_creator'
MessageActionCreator = require '../actions/message_action_creator'

RouterMixin = require '../mixins/router_mixin'
StoreWatchMixin = require '../mixins/store_watch_mixin'
ShouldUpdate = require '../mixins/should_update_mixin'


# Component that allows the user to write emails.
module.exports = Compose = React.createClass
    displayName: 'Compose'

    mixins: [
        RouterMixin,
        React.addons.LinkedStateMixin # two-way data binding
        ShouldUpdate.UnderscoreEqualitySlow
    ]

    propTypes:
        message    : React.PropTypes.instanceOf(Immutable.Map)
        action     : React.PropTypes.string
        useIntents : React.PropTypes.bool.isRequired

    getInitialState: ->
        message = @props.initialMessage

        focus = if not message.get('to')?.length then 'to'
        else if message.get('subject') is '' then 'subject'
        else 'editor'

        return nextState =
            message: message
            focus: focus
            accountID: @props.defaultAccountID
            ccShown: message?.get('cc')?.length
            bccShown: message?.get('bcc')?.length

    linkMessageState: (field) ->
        currentValue = @state.message.get(field)
        cachedTransform @, '__cacheLS', field, currentValue, =>
            value: currentValue
            requestChange: (value) =>
                message = @state.message.set field, value
                @setState {message}

    render: ->
        selectedAccount = @props.accounts.get @state.accountID
        content = if @props.composeInHTML then @linkMessageState('html')
        else @linkMessageState('text')

        form className: 'form-compose', method: 'POST',
            div className: 'form-group account',
                label
                    htmlFor: 'compose-from',
                    className: 'compose-label',
                    t "compose from"
                AccountPicker
                    accounts: @props.accounts
                    valueLink: @linkState 'accountID'

            div
                className: 'btn-toolbar compose-toggle',
                role: 'toolbar',
                    div null
                        a
                            className: 'compose-toggle-cc',
                            onClick: @onToggleCc,
                            t 'compose toggle cc'
                        a
                            className: 'compose-toggle-bcc',
                            onClick: @onToggleBcc,
                            t 'compose toggle bcc'

            MailsInput
                id: 'compose-to'
                valueLink: @linkMessageState 'to'
                label: t 'compose to'
                focus: @state.focus is 'to'
                ref: 'to'

            MailsInput
                id: 'compose-cc'
                className: 'compose-cc'
                classShown: @state.ccShown
                valueLink: @linkMessageState 'cc'
                label: t 'compose cc'
                focus: @state.focus is 'cc'
                placeholder: t 'compose cc help'
                ref: 'cc'

            MailsInput
                id: 'compose-bcc'
                className: 'compose-bcc'
                classShown: @state.bccShown
                valueLink: @linkMessageState 'bcc'
                label: t 'compose bcc'
                focus: @state.focus is 'bcc'
                placeholder: t 'compose bcc help'
                ref: 'bcc'

            div className: 'form-group',
                input
                    id: 'compose-subject'
                    name: 'compose-subject'
                    ref: 'subject'
                    valueLink: @linkMessageState('subject')
                    type: 'text'
                    autoFocus: @state.focus is 'subject'
                    className: 'form-control compose-subject'
                    placeholder: t "compose subject help"

            Editor
                html              : @props.composeInHTML
                signature         : selectedAccount?.get('signature')
                focus             : @state.focus is 'editor'
                ref               : 'editor'
                valueLink         : content
                onFiles           : @onFilesInEditor
                useIntents        : @props.useIntents

            div className: 'attachements',
                FilePicker
                    className: ''
                    editable: true
                    valueLink: @linkMessageState 'attachments'
                    ref: 'attachments'

            ComposeToolbox
                saving    : @state.saving
                sending   : @state.sending
                onSend    : @onSend
                onDelete  : @onDelete
                onDraft   : @onSaveDraft
                onCancel  : @onCancel
                canDelete : @state.message?.get("id")

            Clearfix null


    # If we are answering to a message, canceling should bring back to
    # this message.
    # The message URL requires many information: account ID, mailbox ID,
    # conversation ID and message ID. These infor are collected via current
    # selection and message information.
    finalRedirect: (event) ->
        event?.preventDefault?()
        if @props.inReplyTo?
            conversationID = @props.inReplyTo.get('conversationID')
            accountID = @props.inReplyTo.get('accountID')
            messageID = @props.inReplyTo.get('id')
            mailboxes = Object.keys @props.inReplyTo.get 'mailboxIDs'
            mailboxID = AccountStore.pickBestBox accountID, mailboxes

            @redirect
                firstPanel:
                    action: 'account.mailbox.messages'
                    parameters: {accountID, mailboxID}

                secondPanel:
                    action: 'conversation'
                    parameters: {conversationID, messageID}

        # Else it should bring to the default view
        else
            @redirect
                direction: 'first'
                action: 'default'
                fullWidth: true

    # Cancel brings back to default view. If it's while replying to a message,
    # it brings back to this message.
    onCancel: (event) ->
        event.preventDefault()

        # Action after cancelation: call @props.onCancel
        # or navigate to message list.
        if @props.onCancel?
            @props.onCancel()
        else
            @finalRedirect()


    componentDidMount: ->
        window.addEventListener 'beforeunload', @onWindowBeforeUnload
        window.rootComponent.props.router.beforeNavigate = @onCancel

    componentWillUnmount: ->
        window.removeEventListner 'beforeunload', @onWindowBeforeUnload
        window.rootComponent.props.router.beforeNavigate = null

    validationError: (isDraft) ->
        # no validation for drafts
        if isDraft
            return null

        if @state.message.get('to').length is 0 and
          @state.message.get('cc').length is 0 and
          @state.message.get('bcc').length is 0
            @setState focus: 'to'
            return t "compose error no dest"

        if @state.message.get('subject') is ''
            @setState focus: 'subject'
            return t "compose error no subject"

    onSaveDraft: ->
        @_doSend true

    onSend: ->
        @_doSend false

    _displayConfirmModal: ->
        # display a modal asking if we should keep or delete the draft
        # nexttick because of React's components life cycle
        LayoutActionCreator.displayModalNextTick
            title       : t 'app confirm delete'
            subtitle    : t 'compose confirm keep draft'
            closeLabel  : t 'compose confirm draft keep'
            actionLabel : t 'compose confirm draft delete'
            action      : @onSaveDraft
            closeModal  : @_doDelete

    _doSend: (isDraft) ->

        validationError = @validationError isDraft
        if validationError
            return LayoutActionCreator.alertError validationError

        account = @props.accounts.get @state.accountID
        message = @state.message.toJS()
        # keep attachments as an imutable structure
        message.attachments = @state.message.get('attachments')
        message.from = [
            name: account.get('name') or undefined
            address: account.get('login')
        ]
        message.isDraft = isDraft
        MessageUtils.cleanHTML message

        @setState if isDraft then saving: true else sending: true

        MessageActionCreator.send message, (error, updated) =>
            # Sometime, when user cancel composing, the component has been
            # unmounted before we come back from autosave, and setState fails
            @setState
                saving: false
                sending: false
                message: @state.message.merge updated

            if not isDraft and not error? and updated?
                @redirect @props.backURL unless error?

    getConfirmMessage: ->
        subject = @state.message.get 'subject'
        subtitle = if subject
            t 'mail confirm delete', {subject}
        else t 'mail confirm delete nosubject'

    # if the user close the browser
    onWindowBeforeUnload: (e) ->
        if @needSaving()
            confirm = getConfirmMessage()
            e.returnValue = confirm
            return confirm
        else
            return null

    # when the user navigate away or click the cancel button
    # the return value block the navigation in lib/panel_router
    onCancel: ->
        if @needSaving()
            @_displayConfirmModal()
            return false
        else
            return true

    # when the user click the DELETE button
    onDelete: -> @_doDelete()

    needSaving: ->
        @state.message isnt @props.message

    _doDelete: ->
        messageID = @state.message.get('id')
        # this will prevent asking a second time when unmounting component
        @deleting = true
        MessageActionCreator.delete {messageID}, (error) =>
            @deleting = false
            @redirect @props.backURL unless error?

    onToggleCc: (e) ->
        @setState
            ccShown: not @state.ccShown
            focus: if not @state.ccShown then 'cc' else ''


    onToggleBcc: (e) ->
        @setState
            bccShown: not @state.bccShown
            focus: if not @state.bccShown then 'bcc' else ''


    # When files are added in the editor, pass them to the picker
    # @TODO : should just change @state.messages instead of using
    # the subcomponent function
    onFilesInEditor: (files) ->
        return @refs.attachments.addFiles files

