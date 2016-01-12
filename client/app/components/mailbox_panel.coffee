AccountStore = require '../stores/account_store'
SettingsStore = require '../stores/settings_store'
MessageStore = require '../stores/message_store'

RouterMixin = require '../mixins/router_mixin'
StoreWatchMixin      = require '../mixins/store_watch_mixin'
ShouldComponentUpdate = require '../mixins/should_update_mixin'

{MessageFilter} = require '../constants/app_constants'

MessageList = require './message-list'

module.exports = React.createClass
    displayName: 'MailboxPanel'

    mixins: [
        ShouldComponentUpdate.UnderscoreEqualitySlow
        StoreWatchMixin [AccountStore, MessageStore, SettingsStore]
    ]

    getStateFromStores: ->
        nstate =
            accounts              : AccountStore.getAll()
            mailboxes             : AccountStore.getAllMailboxes()
            selectedAccount       : AccountStore.getSelectedOrDefault()
            selectedMailbox       : AccountStore.getSelectedMailbox()
            fetching              : MessageStore.isFetching()
            settings              : SettingsStore.get()
            currentMessageID      : MessageStore.getCurrentID()
            currentConversationID : MessageStore.getCurrentConversationID()
            conversationLengths   : MessageStore.getConversationsLength()
            queryParams           : MessageStore.getQueryParams()
            refresh           : AccountStore.getMailboxRefresh @props.mailboxID

        account = nstate.selectedAccount
        mailboxID = nstate.selectedMailbox.get('id')


        useConv = mailboxID isnt account?.get('trashMailbox') and
        mailboxID isnt account?.get('draftMailbox') and
        mailboxID isnt account?.get('junkMailbox') and
        nstate.settings.get('displayConversation')

        nstate.displayConversations = useConv
        nstate.messages = MessageStore.getMessagesToDisplay mailboxID, useConv

        firstMessage = nstate.messages?.first()
        nstate.currentConversationID ?= firstMessage?.get 'conversationID'

        return nstate

    render: ->
        console.log "mprender"
        mailboxID = @state.selectedMailbox.get('id')
        return MessageList
            messages:             @state.messages
            accountID:            @state.selectedAccount?.get 'id'
            mailboxID:            mailboxID
            messageID:            @state.currentMessageID
            conversationID:       @state.currentConversationID
            login:                @state.selectedAccount?.get 'login'
            accounts:             @state.accounts
            mailboxes:            @state.mailboxes
            settings:             @state.settings
            fetching:             @state.fetching
            refresh:              @state.refresh
            isTrash:              @isTrash mailboxID
            conversationLengths:  @state.conversationLengths
            emptyListMessage:     @emptyListMessage()
            displayConversations: @state.displayConversations
            queryParams:          @state.queryParams
            canLoadMore:          @state.queryParams.hasNextPage
            loadMoreMessage:      @loadMoreMessage

    isTrash: (mailboxID) ->
        mailboxID is @state.selectedAccount?.get('trashMailbox')

    emptyListMessage: ->
        switch @state.queryParams.filter
            when MessageFilter.FLAGGED then t 'no flagged message'
            when MessageFilter.UNSEEN then t 'no unseen message'
            when MessageFilter.ALL then t 'list empty'
            else t 'no filter message'

    loadMoreMessage: ->
        MessageActionCreator.fetchMoreOfCurrentQuery()

