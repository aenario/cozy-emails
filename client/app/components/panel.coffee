# Components
AccountConfig  = require './account_config'
Compose        = require './compose'
Conversation   = require './conversation'
MessageList    = require './message-list'
Settings       = require './settings'
SearchResult   = require './search_result'
{Spinner}       = require './basic_components'

# React Mixins
RouterMixin          = require '../mixins/router_mixin'
StoreWatchMixin      = require '../mixins/store_watch_mixin'
TooltipRefesherMixin = require '../mixins/tooltip_refresher_mixin'

# Flux stores
AccountStore  = require '../stores/account_store'
MessageStore  = require '../stores/message_store'
SearchStore   = require '../stores/search_store'
SettingsStore = require '../stores/settings_store'

MessageActionCreator = require '../actions/message_action_creator'
MessageUtils = require '../utils/message_utils'

{ComposeActions} = require '../constants/app_constants'

PANEL_ACTION_TO_COMPOSE_ACTION =
    'compose.reply'     : ComposeActions.REPLY
    'compose.forward'   : ComposeActions.FORWARD
    'compose.reply-all' : ComposeActions.REPLY_ALL

module.exports = Panel = React.createClass
    displayName: 'Panel'

    mixins: [
        StoreWatchMixin [AccountStore, MessageStore, SettingsStore, SearchStore]
        TooltipRefesherMixin
        RouterMixin
    ]

    shouldComponentUpdate: (nextProps, nextState) ->
        should = not(_.isEqual(nextState, @state)) or
                 not (_.isEqual(nextProps, @props))

        return should

    render: ->
        # -- Generates a list of messages for a given account and mailbox
        if @props.action is 'account.mailbox.messages'
            @renderList()

        else if @props.action is 'search'

            key = encodeURIComponent SearchStore.getCurrentSearch()

            SearchResult
                key: "search-#{key}"

        # -- Generates a configuration window for a given account
        else if @props.action is 'account.config' or
                @props.action is 'account.new'

            id = @props.accountID or 'new'

            AccountConfig
                key: "account-config-#{id}"
                tab: @props.tab

        # -- Generates a conversation
        else if @props.action is 'message' or
                @props.action is 'conversation'

            Conversation
                messageID: @props.messageID
                key: 'conversation-' + @props.messageID
                ref: 'conversation'

        # -- Generates the new message composition form
        else if @props.action is 'compose'

            account = AccountStore.getSelectedOrDefault()
            return Spinner() unless account

            signature = account.get('signature')

            Compose
                key               : 'compose-new'
                selectedMailboxID : @props.selectedMailboxID
                useIntents        : @props.useIntents
                message           : MessageUtils.makeNewMessage signature

        else if @props.action is 'edit'

            message = MessageStore.getByID @props.messageID
            return Spinner() unless message

            Compose
                key: "compose-edit-#{message.get 'id'}"
                message: message

        else if @props.action is 'compose.reply' or
                @props.action is 'compose.reply-all' or
                @props.action is 'compose.forward'

            message = MessageStore.getByID @props.messageID
            return Spinner() unless message

            account = AccountStore.getByID message.get('accountID')
            return Spinner() unless account

            composeAction = PANEL_ACTION_TO_COMPOSE_ACTION[@props.action]
            unless composeAction
                throw new Error "unknown compose type : #{@prop.action}"

            Compose
                key: "compose-#{composeAction}-#{message.get('id')}"
                message: MessageUtils.makeReplyMessage(
                    account.get('login'),
                    message,
                    composeAction,
                    true,
                    account.get('signature')
                )

        # -- Display the settings form
        else if @props.action is 'settings'
            Settings
                key     : 'settings'
                ref     : 'settings'
                settings: @state.settings

        # -- Error case, shouldn't happen. Might be worth to make it pretty.
        else
            console.error "Unknown action #{@props.action}"
            window.cozyMails.logInfo "Unknown action #{@props.action}"
            return React.DOM.div null, "Unknown component #{@props.action}"


    renderList: ->

        unless @state.accounts.get @props.accountID
            setTimeout =>
                @redirect
                    direction: "first"
                    action: "default"
            , 1
            return React.DOM.div null, 'redirecting'

        MessageList
            key: 'messageList-' + @props.mailboxID
            accountID: @props.accountID
            mailboxID: @props.mailboxID

    # Rendering the compose component requires several parameters. The main one
    # are related to the selected account, the selected mailbox and the compose
    # state (classic, draft, reply, reply all or forward).



    getStateFromStores: ->
        return {
            accounts              : AccountStore.getAll()
            settings              : SettingsStore.get()
            isLoadingReply        : not MessageStore.getByID(@props.messageID)?
        }
