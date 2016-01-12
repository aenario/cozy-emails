{div, h3, form, label, input, button, fieldset, legend, ul, li, a, span, i} = React.DOM
classer = React.addons.classSet

LayoutActionCreator   = require '../actions/layout_action_creator'
SettingsActionCreator = require '../actions/settings_action_creator'
PluginUtils    = require '../utils/plugin_utils'
ApiUtils       = require '../utils/api_utils'
{Dispositions} = require '../constants/app_constants'
SettingsStore = require '../stores/settings_store'

AccountActionCreator = require '../actions/account_action_creator'
LayoutActions = require '../actions/layout_action_creator'

RouterMixin = require '../mixins/router_mixin'
StoreWatchMixin      = require '../mixins/store_watch_mixin'
ShouldComponentUpdate = require '../mixins/should_update_mixin'

LAYOUT_OPTIONS = {}
layout_t_key = "settings label layoutStyle "
LAYOUT_OPTIONS[Dispositions.VERTICAL] = t layout_t_key + "vertical"
LAYOUT_OPTIONS[Dispositions.HORIZONTAL] = t layout_t_key + "horizontal"

module.exports = React.createClass
    displayName: 'Settings'

    mixins: [
        ShouldComponentUpdate.UnderscoreEqualitySlow
        StoreWatchMixin [SettingsStore]
    ]

    getStateFromStores: ->
        settings : SettingsStore.get()

    makeLinkState: (field) ->


    render: ->
        classLabel  = 'col-sm-5 col-sm-offset-1 control-label'
        classInput  = 'col-sm-6'
        layoutStyle = @state.settings.layoutStyle or 'vertical'
        listStyle   = @state.settings.listStyle   or 'default'

        div id: 'settings panel',
            h3 null, t "settings title"


            form className: 'form-horizontal',

                AccountInput
                    type: 'dropdown'
                    id: 'settings-layoutStyle'
                    label: t "settings label layoutStyle"
                    valueLink: @makeLinkState 'layoutStyle'
                    options: LAYOUT_OPTIONS

                # SETTINGS
                @_renderOption 'composeInHTML'
                @_renderOption 'composeOnTop'
                @_renderOption 'desktopNotifications'

                FormButton
                    text: t 'register mailto'
                    onClick: @registerMailto

    _renderOption: (option) ->
        AccountInput
            name: 'settings-' + option
            type: 'checkbox'
            valueLink: @makeLinkState option

    handleChange: (event) ->
        event.preventDefault()
        target = event.currentTarget
        switch target.dataset.target
            #when 'messagesPerPage'
            #    settings = @state.settings
            #    settings.messagesPerPage = target.value
            #    @setState({settings: settings})
            #    SettingsActionCreator.edit settings
            # SETTINGS
            when 'autosaveDraft'
            ,    'composeInHTML'
            ,    'composeOnTop'
            ,    'desktopNotifications'
            ,    'displayConversation'
            ,    'displayPreview'
            ,    'messageConfirmDelete'
            ,    'messageDisplayHTML'
            ,    'messageDisplayImages'
                settings = @state.settings
                settings[target.dataset.target] = target.checked
                @setState({settings: settings})
                SettingsActionCreator.edit settings


            when 'layoutStyle'
                settings = @state.settings
                settings.layoutStyle = target.dataset.style
                LayoutActionCreator.setDisposition settings.layoutStyle
                @setState({settings: settings})
                SettingsActionCreator.edit settings
            when 'listStyle'
                settings = @state.settings
                settings.listStyle = target.dataset.style
                @setState({settings: settings})
                SettingsActionCreator.edit settings
            when 'plugin'
                name = target.dataset.plugin
                settings = @state.settings
                if target.checked
                    PluginUtils.activate name
                else
                    PluginUtils.deactivate name
                for own pluginName, pluginConf of settings.plugins
                    pluginConf.active = window.plugins[pluginName].active
                @setState({settings: settings})
                SettingsActionCreator.edit settings


    registerMailto: ->
        loc = window.location
        window.navigator.registerProtocolHandler "mailto",
            "#{loc.origin}#{loc.pathname}#compose?mailto=%s",
            "Cozy"
