_         = require 'lodash'
Immutable = require 'immutable'

Store = require '../libs/flux/store/store'
AccountStore = require '../stores/account_store'

AppDispatcher = require '../app_dispatcher'

{ActionTypes, MessageActions, AccountActions} = require '../constants/app_constants'

class RouterStore extends Store

    ###
        Initialization.
        Defines private variables here.
    ###
    _router = null

    _action = null

    _nextURL = null
    _lastDate = null

    _currentFilter = _defaultFilter =
        sort: '-date'

        flags: null

        value: null
        before: null
        after: null
        pageAfter: null

    getRouter: ->
        return _router

    getAction: ->
        return _action

    # If filters are default
    # Nothing should appear in URL
    getQueryParams: ->
         if _currentFilter isnt _defaultFilter then _currentFilter else null


    getFilter: ->
        _currentFilter


    getURL: (params={}) ->
        action = _getRouteAction params

        filter = unless params.resetFilter
        then _getURIQueryParams params
        else ''

        isMessage = !!params.messageID or _.contains action, 'message'
        if isMessage and not params.mailboxID
            params.mailboxID = AccountStore.getMailboxID()

        isMailbox = _.contains action, 'mailbox'
        if isMailbox and not params.mailboxID
            params.mailboxID = AccountStore.getMailboxID()

        isAccount = _.contains action, 'account'
        if isAccount and not params.accountID
            params.accountID = AccountStore.getAccountID()
        if isAccount and not params.tab
            params.tab = 'account'

        if (route = _getRoute action)
            isValid = true
            prefix = unless params.isServer then '#' else ''
            filter = '/' + filter if params.isServer
            url = route.replace /\:\w*/gi, (match) =>
                # Get Route pattern of action
                # Replace param name by its value
                param = match.substring 1, match.length
                params[param] or match
            return prefix + url.replace(/\(\?:query\)$/, filter)

    getNextURL: (params={}) ->
        pageAfter = params.messages?.last()?.get 'date'
        delete params.messages
        params.filter = {} unless params.filter?
        params.filter.pageAfter = pageAfter
        return @getCurrentURL params

    getCurrentURL: (options={}) ->
        params = _.extend {isServer: true}, options
        params.action = @getAction() unless params.action
        params.mailboxID = AccountStore.getMailboxID()
        return @getURL params

    _getRouteAction = (params) ->
        unless (action = params.action)
            return MessageActions.SHOW if params.messageID
            return MessageActions.SHOW_ALL
        action

    _getRoute = (action) ->
        routes = _router.routes
        name = _toCamelCase action
        index = _.values(routes).indexOf(name)
        _.keys(routes)[index]

    _getURLparams = (query) ->
        # Get data from URL
        if _.isString query
            params = query.match /([\w]+=[-+\w,:.]+)+/gi
            return unless params?.length
            result = {}

            _.each params, (param) ->
                param = param.split '='
                if -1 < (value = param[1]).indexOf ','
                    value = value.split ','
                else
                    result[param[0]] = value

            return result

        # Get data from Views
        switch query.type
            when 'from', 'dest'
                result = {}
                result.before = query.value
                result.after = "#{query.value}\uFFFF"

            when 'flag'
                # Keep previous filters
                flags = _currentFilter.flags or []
                flags = [flags] if _.isString flags

                # Toggle value
                if -1 < flags.indexOf query.value
                    _.pull flags, query.value
                else
                    flags.push query.value
                (result = {}).flags = flags
        return result

    _getURIQueryParams = (params={}) ->
        filters = _.extend {}, _self.getFilter()
        _.extend filters, params.filter if params.filter

        query = _.compact _.map filters, (value, key) ->
            if value? and _defaultFilter[key] isnt value
                return key + '=' + encodeURIComponent(value)

        if query.length then "?#{query.join '&'}" else ""



    _setFilter = (query) ->
        # Update Filter
        _currentFilter = _.clone _defaultFilter
        _.extend _currentFilter, query
        return _currentFilter


    _resetFilter = ->
        _currentFilter = _defaultFilter


    # Useless for MessageStore
    # to clean messages
    isResetFilter: (filter) ->
        filter = _self.getFilter() unless filter
        filter.type in ['from', 'dest']

    ###
        Defines here the action handlers.
    ###
    __bindHandlers: (handle) ->

        handle ActionTypes.ROUTE_CHANGE, (params={}) ->
            {action, query} = params

            # We cant display any informations
            # without accounts
            if AccountStore.getAll()?.size
                _action = action
            else
                _action = AccountActions.CREATE

            # Save current filters
            _setFilter query

            @emit 'change'

        handle ActionTypes.ROUTES_INITIALIZE, (router) ->
            _router = router
            @emit 'change'

        handle ActionTypes.REMOVE_ACCOUNT_SUCCESS, ->
            _router?.navigate url: ''

        handle ActionTypes.ADD_ACCOUNT_SUCCESS, ({account, areMailboxesConfigured}) ->
            accountID = account.id
            action = if areMailboxesConfigured then MessageActions.SHOW_ALL else AccountActions.EDIT
            _router?.navigate {accountID, action}
            @emit 'change'

        handle ActionTypes.MESSAGE_FETCH_SUCCESS, ->
            @emit 'change'

_toCamelCase = (value) ->
    return value.replace /\.(\w)*/gi, (match) ->
        part1 = match.substring 1, 2
        part2 = match.substring 2, match.length
        return part1.toUpperCase() + part2


module.exports = (_self = new RouterStore())