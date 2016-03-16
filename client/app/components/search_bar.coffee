React = require 'react'

{div, button, i} = React.DOM

SearchInput = React.createFactory require './search_input'
AccountPicker = React.createFactory require './account_picker'

RouterGetter = require '../getters/router'

AccountStore = require '../stores/account_store'
SearchStore = require '../stores/search_store'

module.exports = GlobalSearchBar = React.createClass
    displayName: 'GlobalSearchBar'

    # FIXME : use getters instead
    # such as : SearchBar.getState()
    getInitialState: ->
        @getStateFromStores()

    # FIXME : use getters instead
    # such as : SearchBar.getState()
    componentWillReceiveProps: (nextProps={}) ->
        @setState @getStateFromStores()
        nextProps

    render: ->
        div className: 'search-bar',

            i className: 'fa fa-search'

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
        unless _.isEmpty newvalue
            window.location.href = RouterGetter.getURL
                action: 'search'
                value: newvalue
            return

        @setState search: ''

        accountID = null if @state.accountID is 'all'
        window.location.href = RouterGetter.getURL
            action: 'message.list'
            accountID: accountID

    onAccountChanged: (accountID) ->
        currentAccountId = AccountStore.getSelected()?.get('id')

        if @state.search isnt ''
            Router.redirect
                action: 'search'
                value: @state.search

        else if accountID not in ['all', currentAccountId]
            Router.redirect
                action: 'message.list'

        else
            @setState {accountID}

    getStateFromStores: ->
        accounts = AccountStore.getAll()
        .map (account) -> account.get 'label'
        .toOrderedMap()
        .set 'all', t 'search all accounts'

        accountID = AccountStore.getSelected()?.get('id') or 'all'
        search = SearchStore.getCurrentSearch()

        return {accounts, search, accountID}
