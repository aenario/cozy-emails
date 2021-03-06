{div, button, i} = React.DOM
SearchInput = require './search_input'
AccountPicker = require './account_picker'
RouterMixin           = require '../mixins/router_mixin'
LayoutActionCreator = require '../actions/layout_action_creator'
StoreWatchMixin      = require '../mixins/store_watch_mixin'
AccountStore = require '../stores/account_store'
SearchStore = require '../stores/search_store'
AccountActionCreator = require '../actions/account_action_creator'


module.exports = GlobalSearchBar = React.createClass
    displayName: 'GlobalSearchBar'

    mixins: [
        RouterMixin
        StoreWatchMixin [AccountStore, SearchStore]
    ]

    render: ->
        div className: 'search-bar',

            # Drawer toggler
            button
                className: 'drawer-toggle'
                onClick:   LayoutActionCreator.drawerToggle
                title:     t 'menu toggle'

                i className: 'fa fa-navicon'

            AccountPicker
                accounts: @state.accounts
                valueLink:
                    value: @state.accountID or 'all'
                    requestChange: @onAccountChanged

            SearchInput
                value: @state.search or ''
                placeholder: t 'filters search placeholder'
                onSubmit: @onSearchTriggered

    onSearchTriggered: (newvalue) ->
        if newvalue isnt ''
            @redirect
                direction: 'first'
                action: 'search'
                parameters: [ @state.accountID, newvalue ]
        else
            @setState search: ''
            accountID = @state.accountID
            accountID = null if @state.accountID is 'all'

            @redirect
                direction: 'first'
                action: 'account.mailbox.messages'
                parameters: [ accountID ]

    onAccountChanged: (accountID) ->
        if @state.search isnt ''
            @redirect
                direction: 'first'
                action: 'search'
                parameters: [ accountID, @state.search ]

        else if accountID isnt 'all'
            @redirect
                direction: 'first'
                action: 'account.mailbox.messages'
                parameters: [ accountID ]

        else
            @setState {accountID}

    getStateFromStores: ->
        accounts = AccountStore.getAll()
        .map (account) -> t "search in account", account: account.get 'label'
        .toOrderedMap()
        .set 'all', t 'search all accounts'

        accountID = AccountStore.getSelected()?.get('id') or 'all'
        search = SearchStore.getCurrentSearch()

        return {accounts, search, accountID}
