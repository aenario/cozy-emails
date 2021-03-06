Store = require '../libs/flux/store/store'

{ActionTypes} = require '../constants/app_constants'

AccountTranslator = require '../utils/translators/account_translator'


class AccountStore extends Store

    ###
        Initialization.
        Defines private variables here.
    ###

    _accountsUnread = Immutable.Map()
    # Creates an OrderedMap of accounts
    # this map will contains the base information for an account
    _accounts = Immutable.Sequence window.accounts

        # sort first
        .sort (mb1, mb2) ->
            if mb1.label > mb2.label then return 1
            else if mb1.label < mb2.label then return -1
            else return 0

        # sets account ID as index
        .mapKeys (_, account) -> return account.id

        # makes account object an immutable Map
        .map (account) ->
            _accountsUnread.set account.id, account.totalUnread
            return AccountTranslator.toImmutable account

        .toOrderedMap()

    _mailboxesCounters = Immutable.Map()

    _selectedAccount   = null
    _selectedMailbox   = null
    _newAccountWaiting = false
    _newAccountError   = null
    _mailboxRefreshing = {}

    _refreshSelected = ->
        if selectedAccountID = _selectedAccount?.get 'id'
            _selectedAccount = _accounts.get selectedAccountID
            if selectedMailboxID = _selectedMailbox?.get 'id'
                _selectedMailbox = _selectedAccount
                    ?.get('mailboxes')
                    ?.get(selectedMailboxID)

    setMailbox = (accountID, boxID, boxData) ->

        account = _accounts.get(accountID)
        # on account creation, sometime socket send mailboxes updates
        # before the account has been saved locally
        return true unless account

        mailboxes = account.get('mailboxes')
        mailbox = mailboxes.get(boxID) or Immutable.Map()
        more = _mailboxesCounters.get(boxID) or Immutable.Map()

        boxData.weight = mailbox.get 'weight' if mailbox.get 'weight'

        STATICFIELDS = ['id', 'accountID', 'label', 'tree', 'weight']
        CHANGEFIELDS = ['lastSync', 'nbTotal', 'nbUnread', 'nbRecent']

        for field of STATICFIELDS when mailbox.get(field) isnt boxData[field]
            mailbox = mailbox.set field, boxData[field]

        for field of CHANGEFIELDS when more.get(field) isnt boxData[field]
            more = more.set field, boxData[field]

        if more isnt _mailboxesCounters.get boxID
            _mailboxesCounters.set boxID, more

        if mailbox isnt mailboxes.get boxID
            mailboxes = mailboxes.set boxID, mailbox
            account = account.set 'mailboxes', mailboxes
            _accounts = _accounts.set accountID, account

        _refreshSelected()

    _mailboxSort = (mb1, mb2) ->
        w1 = mb1.get 'weight'
        w2 = mb2.get 'weight'
        if w1 < w2 then return 1
        else if w1 > w2 then return -1
        else
            if mb1.get 'label' < mb2.get 'label' then return 1
            else if mb1.get 'label' > mb2.get 'label' then return -1
            else return 0


    _applyMailboxDiff: (accountID, diff) ->
        for boxID, deltas of diff when deltas.nbTotal + deltas.nbUnread
            counters = _mailboxesCounters.get(boxID) or Immutable.Map()
            _mailboxesCounters.set boxID, counters.merge
                nbTotal: counters.get('nbTotal') + deltas.nbTotal
                nbUnread: counters.get('nbUnread') + deltas.nbUnread

        diffTotalUnread = diff[accountID]?.nbUnread or 0
        if diffTotalUnread

            total = _accountsUnread.get(accountID) + diffTotalUnread
            _accountsUnread = _accountsUnread.set accountID, total

        @emit 'change'


    _setCurrentAccount: (account) ->
        _selectedAccount = account


    _setCurrentMailbox: (mailbox) ->
        _selectedMailbox = mailbox

    _onAccountUpdated: (rawAccount) ->
        account = AccountTranslator.toImmutable rawAccount
        _accounts = _accounts.set account.get('id'), account
        @_setCurrentAccount account
        _newAccountWaiting = false
        _newAccountError   = null
        @emit 'change'


    ###
        Defines here the action handlers.
    ###
    __bindHandlers: (handle) ->

        handle ActionTypes.ADD_ACCOUNT, (rawAccount) ->
            @_onAccountUpdated rawAccount

        handle ActionTypes.SELECT_ACCOUNT, (value) ->
            if value.accountID?
                @_setCurrentAccount(_accounts.get(value.accountID) or null)
            else
                @_setCurrentAccount(null)
            if value.mailboxID?
                mailbox = _selectedAccount
                    ?.get('mailboxes')
                    ?.get(value.mailboxID) or null
                @_setCurrentMailbox mailbox
            else
                _newAccountError = null
                @_setCurrentMailbox null
            @emit 'change'

        handle ActionTypes.NEW_ACCOUNT_WAITING, (payload) ->
            _newAccountWaiting = payload
            @emit 'change'

        handle ActionTypes.NEW_ACCOUNT_ERROR, (error) ->
            _newAccountWaiting = false
            # This is to force Panel.shouldComponentUpdate to rerender
            error.uniq = Math.random()
            _newAccountError = error
            @emit 'change'

        handle ActionTypes.EDIT_ACCOUNT, (rawAccount) ->
            @_onAccountUpdated rawAccount

        handle ActionTypes.MAILBOX_CREATE, (rawAccount) ->
            @_onAccountUpdated rawAccount

        handle ActionTypes.MAILBOX_UPDATE, (rawAccount) ->
            @_onAccountUpdated rawAccount

        handle ActionTypes.MAILBOX_DELETE, (rawAccount) ->
            @_onAccountUpdated rawAccount

        handle ActionTypes.REMOVE_ACCOUNT, (accountID) ->
            _accounts = _accounts.delete accountID
            @_setCurrentAccount @getDefault()
            @emit 'change'

        handle ActionTypes.RECEIVE_MAILBOX_UPDATE, (boxData) ->
            setMailbox boxData.accountID, boxData.id, boxData
            @emit 'change'

        handle ActionTypes.RECEIVE_REFRESH_NOTIF, (data) ->
            _accountsUnread.set data.accountID, data.totalUnread
            @emit 'change'

        handle ActionTypes.REFRESH_REQUEST, ({mailboxID}) ->
            _mailboxRefreshing[mailboxID] ?= 0
            _mailboxRefreshing[mailboxID]++
            @emit 'change'

        handle ActionTypes.REFRESH_FAILURE, ({mailboxID}) ->
            _mailboxRefreshing[mailboxID]--
            @emit 'change'

        handle ActionTypes.REFRESH_SUCCESS, ({mailboxID, updated}) ->
            _mailboxRefreshing[mailboxID]--
            if updated?
                setMailbox updated.accountID, updated.id, updated
            @emit 'change'


    ###
        Public API
    ###
    getAll: ->
        return _accounts


    getAllMailboxes: ->
        return _accounts.flatMap (account) -> account.get 'mailboxes'

    getMailboxCounters: ->
        return _mailboxesCounters


    getByID: (accountID) ->
        return _accounts.get accountID


    getByLabel: (label) ->
        _accounts.find (account) -> account.get('label') is label


    getDefault: ->
        return _accounts.first() or null


    getDefaultMailbox: (accountID) ->

        account = _accounts.get(accountID) or @getDefault()
        return null unless account

        mailboxes = account.get('mailboxes')
        mailbox = mailboxes.filter (mailbox) ->
            return mailbox.get('label').toLowerCase() is 'inbox'
        if mailbox.count() isnt 0
            return mailbox.first()
        else
            favorites = account.get('favorites')
            defaultID = if favorites? then favorites[0]

            return if defaultID then mailboxes.get defaultID
            else mailboxes.first()


    getSelected: ->
        return _selectedAccount

    getSelectedOrDefault: ->
        @getSelected() or @getDefault()

    getSelectedMailboxes: (sorted) ->

        return Immutable.OrderedMap.empty() unless _selectedAccount?

        result = _selectedAccount.get('mailboxes')

        if sorted
            result = result.sort _mailboxSort

        return result


    selectedIsDifferentThan: (accountID, mailboxID) ->
        differentSelected = _selectedAccount?.get('id') isnt accountID or
        _selectedMailbox?.get('id') isnt mailboxID

        return differentSelected


    getSelectedMailbox: (selectedID) ->
        mailboxes = @getSelectedMailboxes()

        if selectedID?
            return mailboxes.get selectedID

        else if _selectedMailbox?
            return _selectedMailbox

        else
            return mailboxes.first()


    getSelectedFavorites: (sorted) ->

        mailboxes = @getSelectedMailboxes()
        ids = _selectedAccount?.get 'favorites'

        if ids?
            mb = mailboxes
                .filter (box, key) -> key in ids
                .toOrderedMap()
        else
            mb = mailboxes
                .toOrderedMap()

        if sorted
            mb = mb.sort _mailboxSort

        return mb


    getError: ->
        return _newAccountError


    isWaiting: ->
        return _newAccountWaiting


    isMailboxRefreshing: (mailboxID)->
        _mailboxRefreshing[mailboxID] > 0


    getMailboxRefresh: (mailboxID) ->
        if _mailboxRefreshing[mailboxID] > 0 then 0.9 else 0

    # Returns corresponding mailbox for given message and account.
    getMailbox: (message, account) ->
        boxID = null
        for boxID of message.get('mailboxIds') when boxID in account.favorites
            boxID = boxID

        if not boxID? and Object.keys(message.get 'mailboxIds').length >= 0
            return Object.keys(message.get 'mailboxIds')[0]

        return boxID




module.exports = new AccountStore()

