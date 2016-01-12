# React components
{div, section, main, p, span, a, i, strong, form, input, button} = React.DOM
Alert          = require './alert'
Menu           = require './menu'
Modal          = require './modal'
AccountConfig  = require './account_config'
ComposePanel   = require './compose_panel'
Conversation   = require './conversation'
MessageList    = require './message-list'
Settings       = require './settings'
SearchResult   = require './search_result'
{Spinner}      = require './basic_components'
MailboxPanel   = require './mailbox_panel'
ToastContainer = require './toast_container'
Tooltips       = require './tooltips-manager'

# React Mixins
RouterMixin          = require '../mixins/router_mixin'
StoreWatchMixin      = require '../mixins/store_watch_mixin'
TooltipRefesherMixin = require '../mixins/tooltip_refresher_mixin'

# Flux stores
AccountStore  = require '../stores/account_store'
MessageStore  = require '../stores/message_store'
LayoutStore   = require '../stores/layout_store'
SearchStore   = require '../stores/search_store'
Stores        = [AccountStore, MessageStore, LayoutStore, SearchStore]

# Flux actions
LayoutActionCreator  = require '../actions/layout_action_creator'
MessageActionCreator = require '../actions/message_action_creator'
ShouldUpdate = require '../mixins/should_update_mixin'

###
    This component is the root of the React tree.

    It has two functions:
        - building the layout based on the router
        - listening for changes in  the model (Flux stores)
          and re-render accordingly

    About routing: it uses Backbone.Router as a source of truth for the layout.
    (based on:
        https://medium.com/react-tutorials/react-backbone-router-c00be0cf1592)
###
module.exports = Application = React.createClass
    displayName: 'Application'

    mixins: [
        StoreWatchMixin Stores
        RouterMixin
        TooltipRefesherMixin
        ShouldUpdate.UnderscoreEqualitySlow
    ]

    render: ->
        console.log "render"
        # Shortcut
        # TODO: Improve the way we display a loader when app isn't ready
        layout = @props.router.current
        return div null, t "app loading" unless layout?

        disposition = LayoutStore.getDisposition()
        isCompact   = LayoutStore.getListModeCompact()
        fullscreen  = LayoutStore.isPreviewFullscreen()
        previewSize = LayoutStore.getPreviewSize()

        modal = @state.modal

        layoutClasses = ['layout'
            "layout-#{disposition}"
            if isCompact then "layout-compact"
            if fullscreen then "layout-preview-fullscreen"
            "layout-preview-#{previewSize}"].join(' ')

        div className: layoutClasses,
            # Actual layout
            div className: 'app',
                # Menu is self-managed because this part of the layout
                # is always the same.
                Menu ref: 'menu', layout: @props.router.current

                main
                    className: if layout.secondPanel? then null else 'full',

                    div
                        className: 'panels'

                        @getPanel layout.firstPanel
                        if layout.secondPanel?
                            @getPanel layout.secondPanel
                        else
                            section
                                key:             'placeholder'
                                'aria-expanded': false

            # Display feedback
            if modal?
                Modal modal
            ToastContainer()

            # Tooltips' content is declared once at the application level.
            # It's hidden so it doesn't break the layout. Other components
            # can then reference the tooltips by their ID to trigger them.
            Tooltips(key: "tooltips")


    getPanel: (panel, ref) ->
        # -- Generates a list of messages for a given account and mailbox
        if panel.action is 'account.mailbox.messages'
            MailboxPanel
                key: 'messageList-' + panel.parameters.mailboxID

        else if panel.action is 'search'
            SearchResult
                key: "search-results"

        # -- Generates a configuration window for a given account
        else if panel.action in ['account.config','account.new']
            AccountConfig
                key: "account-config-#{panel.parameters.accountID or 'new'}"
                tab: panel.parameters.tab

        # -- Generates a conversation
        else if panel.action in ['message','conversation']
            Conversation
                key: 'conversation-' + panel.parameters.messageID
                messageID: panel.parameters.messageID
                ref: 'conversation'

        # -- Generates the new message composition form
        else if panel.action is 'compose' or
                panel.action is 'edit' or
                panel.action is 'compose.reply' or
                panel.action is 'compose.reply-all' or
                panel.action is 'compose.forward'

            ComposePanel
                action: panel.action
                messageID: panel.parameters.messageID
                useIntents: @state.useIntents

        # -- Display the settings form
        else if panel.action is 'settings'
            Settings
                key     : 'settings'
                ref     : 'settings'

        # -- Error case, shouldn't happen. Might be worth to make it pretty.
        else
            console.error "Unknown action #{panel.action}"
            window.cozyMails.logInfo "Unknown action #{panel.action}"
            return React.DOM.div null, "Unknown component #{panel.action}"

    getStateFromStores: ->
        selectedAccount = AccountStore.getSelectedOrDefault()

        return {
            selectedAccount       : selectedAccount
            modal                 : LayoutStore.getModal()
            useIntents            : LayoutStore.intentAvailable()
        }


    # Listens to router changes. Renders the component on changes.
    componentWillMount: ->
        # Uses `forceUpdate` with the proper scope because React doesn't allow
        # to rebind its scope on the fly
        @onRoute = (params) =>
            {firstPanel, secondPanel} = params
            if firstPanel?
                @checkAccount firstPanel.action
            if secondPanel?
                @checkAccount secondPanel.action

            # Store current message ID if selected
            if secondPanel? and secondPanel.parameters.messageID?
                isConv = secondPanel.parameters.conversationID?
                messageID = secondPanel.parameters.messageID
                MessageActionCreator.setCurrent messageID, isConv
            else
                if firstPanel isnt 'compose'
                    MessageActionCreator.setCurrent null

            @forceUpdate()

        @props.router.on 'fluxRoute', @onRoute

    checkAccount: (action) ->
        # "special" mailboxes must be set before accessing to the account
        # otherwise, redirect to account config
        account = AccountStore.getSelectedOrDefault()

        noSpecialFolder = not account?.get('draftMailbox')? or
               not account?.get('sentMailbox')? or
               not account?.get('trashMailbox')?

        needSpecialFolder = action in [
            'account.mailbox.messages'
            'message'
            'conversation'
            'compose'
            'edit'
        ]

        if account? and noSpecialFolder and needSpecialFolder
            @redirect
                direction: 'first'
                action: 'account.config'
                parameters: [ account.get('id'), 'mailboxes']
                fullWidth: true
            LayoutActionCreator.alertError t 'account no special mailboxes'


    componentWillUnmount: ->
        # Stops listening to router changes
        @props.router.off 'fluxRoute', @onRoute
