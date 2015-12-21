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
MessageStore  = require '../stores/message_store'
SettingsStore  = require '../stores/settings_store'

LayoutActionCreator  = require '../actions/layout_action_creator'
MessageActionCreator = require '../actions/message_action_creator'

RouterMixin = require '../mixins/router_mixin'
StoreWatchMixin = require '../mixins/store_watch_mixin'
ShouldUpdate = require '../mixins/should_update_mixin'


# Component that allows the user to write emails.
module.exports = Compose = React.createClass
    displayName: 'Compose'

    mixins: [
        StoreWatchMixin [AccountStore, MessageStore, SettingsStore]
        RouterMixin,
        React.addons.LinkedStateMixin # two-way data binding
        ShouldUpdate.UnderscoreEqualitySlow
    ]

    propTypes:
        message    : React.PropTypes.instanceOf(Immutable.Map)
        action     : React.PropTypes.string
        useIntents : React.PropTypes.bool.isRequired

    getStateFromStores: ->
        composeInHTML = false
        message       = @state?.message or @props.message
        accountID     = @state?.accountID or
                        AccountStore.getSelectedOrDefault().get 'id'

        focus = if not message.get('to')?.length
            'to'
        else if message.get('subject') is ''
            'subject'
        else
            'editor'

        return nextState =
            message: message,
            composeInHTML: composeInHTML,
            focus: focus
            accountID: AccountStore.getSelectedOrDefault().get 'id'
            accounts: AccountStore.getAll()
            isNew: not message?
            settings: SettingsStore.get()
            # use "isnt false" to ignore undefined
            ccShown: @state?.ccShown isnt false and message.get('cc')?.length
            bccShown: @state?.bccShown isnt false and message.get('bcc')?.length

    linkMessageState: (field) ->
        currentValue = @state.message.get(field)
        cachedTransform @, '__cacheLS', field, currentValue, =>
            value: currentValue
            requestChange: (value) =>
                message = @state.message.set field, value
                @setState {message}

    render: ->
        section
            ref: 'compose'
            className: 'compose panel'
            'aria-expanded': true,

            form className: 'form-compose', method: 'POST',
                div className: 'form-group account',
                    label
                        htmlFor: 'compose-from',
                        className: 'compose-label',
                        t "compose from"
                    AccountPicker
                        accounts: @state.accounts
                        valueLink: @linkState 'accountID'

                Clearfix null

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
                    html              : @state.composeInHTML
                    signature         : @getSignature()
                    focus             : @state.focus is 'editor'
                    ref               : 'editor'
                    valueLink         : @getContentValueLink()
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
                    onDraft   : @onDraft
                    onCancel  : @finalRedirect
                    canDelete : @props.message?

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


    _initCompose: ->

        if @_saveInterval
            window.clearInterval @_saveInterval

        @_saveInterval = window.setInterval @_autosave, 30000

        # First save of draft
        @_autosave()

        # scroll compose window into view
        @getDOMNode().scrollIntoView()

        # Focus
        if not Array.isArray(@state.to) or @state.to.length is 0
            setTimeout ->
                document.getElementById('compose-to')?.focus()
            , 10
        else if @props.inReplyTo?
            document.getElementById('compose-editor')?.focus()


    componentDidMount: ->
        @_initCompose()


    componentDidUpdate: ->
        switch @state.focus
            when 'cc'
                setTimeout ->
                    document.getElementById('compose-cc').focus()
                , 0
                @setState focus: ''

            when 'bcc'
                setTimeout ->
                    document.getElementById('compose-bcc').focus()
                , 0
                @setState focus: ''

    componentWillUnmount: ->
        # If message has not been sent, ask if we should keep it or not
        #  - if yes, and the draft belongs to a conversation, add the
        #    conversationID and save the draft
        #  - if no, delete the draft
        if not @deleting and not @state.sending and @state.message.get('id')?

            # if draft has not been updated, delete without asking confirmation
            silent = @state.isNew and not @hasChanged()
            if silent
                setTimeout @onDeleteConfirmed, 5
            else
                # display a modal asking if we should keep or delete the draft
                # nexttick because of React's components life cycle
                LayoutActionCreator.displayModalNextTick
                    title       : t 'app confirm delete'
                    subtitle    : t 'compose confirm keep draft'
                    closeLabel  : t 'compose confirm draft keep'
                    actionLabel : t 'compose confirm draft delete'
                    action      : @onExitSave
                    closeModal  : @onDeleteConfirmed

    hasChanged: () ->
        newHtml = @state.message.get('html')
        newContent = MessageUtils.cleanReplyText(newHtml).replace /\s/gim, ''
        oldContent = MessageUtils.cleanReplyText(@state.initHtml).replace /\s/gim, ''
        updated = newContent isnt oldContent

    getMessageObject: () ->
        account = @state.accounts.get @state.accountID
        message = @state.message.toJS()
        message.from = [
            name: account.get('name') or undefined
            address: account.get('login')
        ]
        return message

    getSignature: ->
        account = @state.accounts.get @state.accountID
        return account?.get('signature')

    getContentValueLink: ->
        if @state.composeInHTML then @linkMessageState('html')
        else @linkMessageState('text')

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

    onDraft: (event) ->
        event.preventDefault()
        @_doSend true


    onSend: (event) ->
        event?.preventDefault()
        @_doSend false

    _doSend: (isDraft) ->

        validationError = @validationError isDraft
        if validationError
            return LayoutActionCreator.alertError validationError

        message = @getMessageObject()
        message.isDraft = isDraft
        @_cleanHTML message

        if isDraft
            @setState saving: true
        else
            window.clearInterval @__mountedIntervalRef
            # Add conversationID when sending message
            # we don't add conversationID to draft, otherwise the full
            # conversation would be updated, closing the compose panel
            message.conversationID = @state.originalConversationID
            @setState sending: true

        MessageActionCreator.send message, (error, message) =>
            # Sometime, when user cancel composing, the component has been
            # unmounted before we come back from autosave, and setState fails
            if @isMounted()
                @setState
                    message: message
                    saving: false
                    sending: false
                    message: @state.message.merge message

            if not isDraft and not error? and message?
                @sent = true
                @finalRedirect()

    # set source of attached images
    _cleanHTML: (message) ->

        html = message.html

        parser = new DOMParser()
        doc    = parser.parseFromString html, "text/html"

        if not doc
            doc = document.implementation.createHTMLDocument("")
            doc.documentElement.innerHTML = html

        if doc
            # the contentID of attached images will be in the data-src attribute
            # override image source with this attribute
            images = doc.querySelectorAll 'IMG[data-src]'
            for image in images
                image.setAttribute 'src', "cid:#{image.dataset.src}"

            html = doc.documentElement.innerHTML
        else
            console.error "Unable to parse HTML content of message"
            return html

        message.html = @_cleanHTML @state.html
        message.text = MessageUtils.cleanReplyText message.html
        message.html = MessageUtils.wrapReplyHtml message.html

    onDelete: (e) ->
        e.preventDefault()
        subject = @props.message.get 'subject'
        subtitle = if subject
            t 'mail confirm delete', {subject}
        else t 'mail confirm delete nosubject'

        LayoutActionCreator.displayModal
            title       : t 'mail confirm delete title'
            subtitle    : subtitle
            closeLabel  : t 'mail confirm delete cancel'
            actionLabel : t 'mail confirm delete delete'
            action      : @onDeleteConfirmed

    onDeleteConfirmed: (e) ->
        LayoutActionCreator.hideModal()
        messageID = @props.message.get('id')
        # this will prevent asking a second time when unmounting component
        @deleting = true
        MessageActionCreator.delete {messageID}, (error) =>
            @deleting = false
            unless error?
                @redirect
                    direction: 'first'
                    action: 'account.mailbox.messages'
                    fullWidth: true
                    parameters: [
                        @props.selectedAccountID
                        @props.selectedMailboxID
                    ]

    onExitSave: (e) ->
        # save one last time the draft, adding the conversationID
        message = @getMessageObject()
        MessageActionCreator.send message, (error, message) ->
            if error? or not message?
                msg = "#{t "message action draft ko"} #{error}"
                LayoutActionCreator.alertError msg
            else
                msg = "#{t "message action draft ok"}"
                LayoutActionCreator.notify msg, autoclose: true
                if message.conversationID?
                    # reload conversation to update its length
                    cid = message.conversationID
                    MessageActionCreator.fetchConversation cid

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

