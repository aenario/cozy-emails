XHRUtils = require '../utils/xhr_utils'
AppDispatcher = require '../app_dispatcher'
{ActionTypes} = require '../constants/app_constants'

SettingsStore = require '../stores/settings_store'
LayoutActionCreator = require './layout_action_creator'


enableNotifications = ->
    if window.Notification?
        Notification.requestPermission (status) ->
            # This allows to use Notification.permission with Chrome/Safari
            if Notification.permission isnt status
                Notification.permission = status

module.exports = SettingsActionCreator =

    edit: (inputValues) ->
        XHRUtils.changeSettings inputValues, (err, values) ->
            if err
                LayoutActionCreator.alertError t('settings save error') + err

            else
                AppDispatcher.handleViewAction
                    type: ActionTypes.SETTINGS_UPDATED
                    value: values

                if values.desktopNotifications
                    enableNotifications()



