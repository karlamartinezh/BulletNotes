{ Template } = require 'meteor/templating'
Dropbox = require('dropbox')
require './settings.jade'
require '../../components/importer/importer.coffee'
require '../../components/exporter/exporter.coffee'

Template.settings.events
  'click #deauthlink': (event) ->
    event.preventDefault()
    Meteor.call 'users.clearDropboxOauth'

Template.settings.helpers
  dropbox_token: ->
    setTimeout ->
      dbx = new Dropbox(clientId: Meteor.settings.public.dropbox_client_id)
      authUrl = dbx.getAuthenticationUrl(Meteor.absoluteUrl() + 'dropboxAuth')
      authLink = document.getElementById('authlink')
      if authLink
        authLink.href = authUrl
    , 100
    if Meteor.user() && Meteor.user().profile
      return Meteor.user().profile.dropbox_token
