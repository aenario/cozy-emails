AccountStore = require '../stores/account_store'
SettingsStore = require '../stores/settings_store'
MessageStore = require '../stores/message_store'

RouterMixin = require '../mixins/router_mixin'
StoreWatchMixin      = require '../mixins/store_watch_mixin'
ShouldComponentUpdate = require '../mixins/should_update_mixin'

MessageUtils = require '../utils/message_utils'

{ComposeActions, MessageFilter} = require '../constants/app_constants'
{div, section} = React.DOM

{Spinner} = require './basic_components'
Compose = require './compose'

PANEL_ACTION_TO_COMPOSE_ACTION =
    'compose.reply'     : ComposeActions.REPLY
    'compose.forward'   : ComposeActions.FORWARD
    'compose.reply-all' : ComposeActions.REPLY_ALL

module.exports = React.createClass
    displayName: 'ComposePanel'

    mixins: [
        RouterMixin
        ShouldComponentUpdate.Logging
        StoreWatchMixin [AccountStore, MessageStore, SettingsStore]
    ]

    getStateFromStores: ->
        console.log "GSFS"

        loading = false
        composeInHTML = SettingsStore.get('composeInHTML')

        if @props.action is 'compose'
            account = AccountStore.getSelectedOrDefault()
            if account
                key = 'compose-new'
                message = MessageUtils.makeNewMessage account.get('signature')
            else
                loading = true

        else if @props.action is 'edit'
            message = MessageStore.getByID @props.messageID
            account = AccountStore.getByID message?.get('accountID')
            if message and account
                key = "compose-edit-#{message.get 'id'}"
            else
                loading = true

        else if @props.action is 'compose.reply' or
                @props.action is 'compose.reply-all' or
                @props.action is 'compose.forward'

            inReplyTo = MessageStore.getByID @props.messageID
            account = AccountStore.getByID inReplyTo?.get('accountID')
            composeAction = PANEL_ACTION_TO_COMPOSE_ACTION[@props.action]

            if inReplyTo and account and composeAction
                key = "compose-#{composeAction}-#{inReplyTo.get('id')}"
                message = MessageUtils.makeReplyMessage(
                    account.get('login'),
                    inReplyTo,
                    composeAction,
                    composeInHTML,
                    account.get('signature')
                )
            else if not composeAction
                throw new Error "unknown compose type : #{@prop.action}"
            else
                loading = true

        account ?= AccountStore.getSelectedOrDefault()

        return nextState =
            loading          : loading
            message          : message
            key              : key
            backURL          : @getBackUrl(inReplyTo or message)
            defaultAccountID : account?.get('id')
            accounts         : AccountStore.getAll()
            composeInHTML    : composeInHTML

    getBackUrl: (message) ->
        # If we are answering to a message, canceling should bring back to
        # this message.
        # The message URL requires many information: account ID, mailbox ID,
        # conversation ID and message ID. These infor are collected via current
        # selection and message information.
        if message.get('id')?
            messageID = message.get 'id'
            accountID = message.get 'accountID'
            conversationID = message.get('conversationID')

            account = AccountStore.getByID accountID
            if account is AccountStore.getSelectedOrDefault()
                mailboxID = AccountStore.getSelectedMailbox().get('id')

            mailboxID ?= AccountStore.getMailbox @props.inReplyTo, account

            return @buildUrl
                firstPanel:
                    action: "account.mailbox.messages",
                    parameters: {accountID, mailboxID}

                secondPanel:
                    action: "conversation",
                    parameters: {conversationID, messageID}

        # Else it should bring to the default view
        else
            return @buildUrl
                direction: 'first'
                action: 'default'
                fullWidth: true

    render: ->
        section
            className: 'compose panel'
            'aria-expanded': true,

            if @state.loading
                Spinner null
            else
                Compose
                    key               : @state.key
                    initialMessage    : @state.message
                    accounts          : @state.accounts
                    composeInHTML     : @state.composeInHTML
                    backURL           : @state.backURL
                    defaultAccountID  : @state.defaultAccountID
                    useIntents        : @props.useIntents
