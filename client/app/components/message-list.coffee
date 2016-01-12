{div, section, p, ul, li, a, span, i, button, input, img} = React.DOM
{MessageFlags, Tooltips} = require '../constants/app_constants'

RouterMixin           = require '../mixins/router_mixin'
TooltipRefresherMixin = require '../mixins/tooltip_refresher_mixin'
StoreWatchMixin       = require '../mixins/store_watch_mixin'

LayoutStore = require '../stores/layout_store'

classer      = React.addons.classSet
DomUtils     = require '../utils/dom_utils'
MessageUtils = require '../utils/message_utils'
SocketUtils  = require '../utils/socketio_utils'
colorhash    = require '../utils/colorhash'

ContactActionCreator = require '../actions/contact_action_creator'
LayoutActionCreator  = require '../actions/layout_action_creator'
MessageActionCreator = require '../actions/message_action_creator'

Participants        = require './participant'
{Spinner, Progress} = require './basic_components'
ToolbarMessagesList = require './toolbar_messageslist'
MessageListBody = require './message-list-body'
ShouldUpdate = require '../mixins/should_update_mixin'


module.exports = MessageList = React.createClass
    displayName: 'MessageList'

    mixins: [
        RouterMixin,
        TooltipRefresherMixin
        StoreWatchMixin [LayoutStore]
        ShouldUpdate.UnderscoreEqualitySlow
    ]

    getInitialState: ->
        edited: false
        selected: {}
        allSelected: false

    getStateFromStores: ->
        fullscreen: LayoutStore.isPreviewFullscreen()

    componentWillReceiveProps: (props) ->
        selected = _.clone @state.selected
        # remove selected messages that are not in view anymore
        for id, isSelected of selected when not props.messages.get(id)
            delete selected[id]
        @setState selected: selected
        if Object.keys(selected).length is 0
            @setState allSelected: false, edited: false

    render: ->
        console.log "mes list render", @props.messages.length
        section
            key:               "messages-list-#{@props.mailboxID}"
            ref:               'list'
            'data-mailbox-id': @props.mailboxID
            className:         'messages-list panel'
            'aria-expanded':   not @state.fullscreen

            # Toolbar
            ToolbarMessagesList
                settings:             @props.settings
                accountID:            @props.accountID
                mailboxID:            @props.mailboxID
                mailboxes:            @props.mailboxes
                messages:             @props.messages
                edited:               @state.edited
                selected:             @state.selected
                allSelected:          @state.allSelected
                displayConversations: @props.displayConversations
                toggleEdited:         @toggleEdited
                toggleAll:            @toggleAll
                afterAction:          @afterMessageAction
                queryParams:          @props.queryParams
                noFilters:            @props.noFilters

            # Progress
            Progress value: @props.refresh, max: 1

            # Message List
            if @props.messages.count() is 0
                if @props.fetching
                    p className: 'listFetching list-loading', t 'list fetching'
                else
                    p
                        className: 'listEmpty'
                        ref: 'listEmpty'
                        @props.emptyListMessage
            else
                div
                    className: 'main-content'
                    ref: 'scrollable',
                    MessageListBody
                        messages: @props.messages
                        settings: @props.settings
                        accountID: @props.accountID
                        mailboxID: @props.mailboxID
                        messageID: @props.messageID
                        conversationID: @props.conversationID
                        conversationLengths: @props.conversationLengths
                        accounts: @props.accounts
                        mailboxes: @props.mailboxes
                        login: @props.login
                        edited: @state.edited
                        selected: @state.selected
                        allSelected: @state.allSelected
                        displayConversations: @props.displayConversations
                        isTrash: @props.isTrash
                        ref: 'listBody'
                        onSelect: @onMessageSelectionChange

                    @renderFooter()

    renderFooter: ->
        if @props.canLoadMore
            p className: 'text-center list-footer',
                if @props.fetching
                    Spinner()
                else
                    a
                        className: 'more-messages'
                        onClick: @props.loadMoreMessage,
                        ref: 'nextPage',
                        t 'list next page'
        else
            p ref: 'listEnd', t 'list end'


    toggleEdited: ->
        if @state.edited
            @setState allSelected: false, edited: false, selected: {}
        else
            @setState edited: true

    toggleAll: ->
        if Object.keys(@state.selected).length > 0
            @setState allSelected: false, edited: false, selected: {}
        else
            selected = {}
            @props.messages.map (message, key) ->
                selected[key] = true
            .toJS()
            @setState allSelected: true, edited: true, selected: selected

    onMessageSelectionChange: (id, val) ->
        selected = _.clone @state.selected
        if val
            selected[id] = val
        else
            delete selected[id]

        if Object.keys(selected).length > 0
            newState =
                edited: true
                selected: selected
        else
            newState =
                allSelected: false
                edited: false
                selected: {}
        @setState newState


    afterMessageAction: ->
        # ugly setTimeout to wait until localDelete occured
        setTimeout =>
            listEnd = @refs.nextPage or @refs.listEnd or @refs.listEmpty
            if listEnd? and DomUtils.isVisible(listEnd.getDOMNode())
                @props.loadMoreMessage()
        , 100

    _loadNext: ->
        # load next message if last one is displayed (useful when navigating
        # with keyboard)
        lastMessage = @refs.listBody?.getDOMNode().lastElementChild
        if @refs.nextPage? and lastMessage? and DomUtils.isVisible(lastMessage)
            @props.loadMoreMessage()

    _handleRealtimeGrowth: ->
        if @props.pageAfter isnt '-' and
           @refs.listEnd? and
           not DomUtils.isVisible(@refs.listEnd.getDOMNode())
            lastdate = @props.messages.last().get('date')
            SocketUtils.changeRealtimeScope @props.mailboxID, lastdate

    _initScroll: ->
        if not @refs.nextPage?
            return

        # listen to scroll events
        if @refs.scrollable?
            scrollable = @refs.scrollable.getDOMNode()
            setTimeout =>
                scrollable.removeEventListener 'scroll', @_loadNext
                scrollable.addEventListener 'scroll', @_loadNext
                @_loadNext()
                # a lot of event can make the "more messages" label visible,
                # so we check every few seconds
                if not @_checkNextInterval?
                    @_checkNextInterval = window.setInterval @_loadNext, 10000
            , 0

    componentDidMount: ->
        @_initScroll()

    componentDidUpdate: ->
        @_initScroll()
        @_handleRealtimeGrowth()

    componentWillUnmount: ->
        if @refs.scrollable?
            scrollable = @refs.scrollable.getDOMNode()
            scrollable.removeEventListener 'scroll', @_loadNext
            if @_checkNextInterval?
                window.clearInterval @_checkNextInterval
