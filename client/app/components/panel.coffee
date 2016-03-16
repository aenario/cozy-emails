React = require 'react'
_     = require 'underscore'

# Components
{Spinner}      = require('./basic_components').factories
AccountConfig  = React.createFactory require './account_config'
Compose        = React.createFactory require './compose'
Conversation   = React.createFactory require './conversation'
MessageList    = React.createFactory require './message-list'
Settings       = React.createFactory require './settings'
SearchResult   = React.createFactory require './search_result'

# Flux stores
AccountStore  = require '../stores/account_store'
MessageStore  = require '../stores/message_store'
SearchStore   = require '../stores/search_store'
SettingsStore = require '../stores/settings_store'

RouterGetter = require '../getters/router'

MessageActionCreator = require '../actions/message_action_creator'

{ComposeActions} = require '../constants/app_constants'


module.exports = Panel = React.createClass
    displayName: 'Panel'

    # Build initial state from store values.
    getInitialState: ->
        @getStateFromStores()

    componentDidMount: ->
        MessageStore.addListener 'change', @fetchMessageComplete

    componentWillUnmount: ->
        MessageStore.removeListener 'change', @fetchMessageComplete

    render: ->
        # -- Generates a list of messages for a given account and mailbox
        if @props.action is 'message.list'
            @renderList()

        else if @props.action is 'search'
            key = encodeURIComponent SearchStore.getCurrentSearch()
            SearchResult
                key: "search-#{key}"

        # -- Generates a configuration window for a given account
        else if -1 < @props.action.indexOf 'account'
            id = @props.accountID or 'new'
            AccountConfig
                key: "account-config-#{id}"
                tab: @props.tab

        # -- Generates a conversation
        else if @props.action is 'message.show'
            Conversation
                messageID: @props.messageID
                key: 'conversation-' + @props.messageID
                ref: 'conversation'

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
                    direction   : 'first'
                    action      : 'default'
            , 1
            return React.DOM.div null, 'redirecting'

        prefix = 'messageList-' + @props.mailboxID
        MessageList
            key         : RouterGetter.getKey prefix
            accountID   : @props.accountID
            mailboxID   : @props.mailboxID
            queryParams : RouterGetter.getQueryParams()

    # Rendering the compose component requires several parameters. The main one
    # are related to the selected account, the selected mailbox and the compose
    # state (classic, draft, reply, reply all or forward).
    renderCompose: ->
        options =
            layout               : 'full'
            action               : null
            inReplyTo            : null
            settings             : @state.settings
            accounts             : @state.accounts
            selectedAccountID    : @state.selectedAccount.get 'id'
            selectedAccountLogin : @state.selectedAccount.get 'login'
            selectedMailboxID    : @props.mailboxID
            useIntents           : @props.useIntents
            ref                  : 'message'
            key                  : @props.action or 'message'

        component = null

        # Generates an empty compose form
        if @props.action is 'message.new'
            message = null
            component = Compose options

        # Generates the edit draft composition form.
        else if @props.action is 'message.edit' or
                @props.action is 'message.show'
            component = Compose _.extend options,
                key: options.key + '-' + @props.messageID
                messageID: @props.messageID

        # Generates the reply composition form.
        else if @props.action is 'message.reply'
            options.action = ComposeActions.REPLY
            component = @getReplyComponent options

        # Generates the reply all composition form.
        else if @props.action is 'message.reply.all'
            options.action = ComposeActions.REPLY_ALL
            component = @getReplyComponent options

        # Generates the forward composition form.
        else if @props.action is 'message.forward'
            options.action = ComposeActions.FORWARD
            component = @getReplyComponent options
        else
            throw new Error "unknown message type : #{@prop.action}"

        return component


    # Configure the component depending on the given action.
    # Returns a spinner if the message is not available.
    getReplyComponent: (options) ->
        options.id = @props.messageID
        options.inReplyTo = @props.messageID
        component = Compose options
        return component

    # Update state with store values.
    fetchMessageComplete: (message) ->
        return unless @isMounted()
        @setState isLoadingReply: false

    # FIXME : use Getters here
    # FIXME : use smaller state
    getStateFromStores: ->
        return {
            accounts              : AccountStore.getAll()
            selectedAccount       : AccountStore.getSelectedOrDefault()
            settings              : SettingsStore.get()
            isLoadingReply        : not MessageStore.getByID(@props.messageID)?
        }
