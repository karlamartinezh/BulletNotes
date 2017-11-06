{ Template } = require 'meteor/templating'
{ Notes } = require '/imports/api/notes/notes.coffee'
{ Files } = require '/imports/api/files/files.coffee'
{ ReactiveDict } = require 'meteor/reactive-dict'

require './note.jade'
require '/imports/ui/components/file/file.coffee'
require '/imports/ui/components/share/share.coffee'
require '/imports/ui/components/encrypt/encrypt.coffee'

import {
  favorite,
  setShowContent
} from '/imports/api/notes/methods.coffee'

import {
  upload
} from '/imports/api/files/methods.coffee'

Template.note.previewXOffset = 100
Template.note.previewYOffset = 20

Template.note.encodeImageFileAsURL = (cb,file) ->
  reader = new FileReader

  reader.onloadend = ->
    cb reader.result

  reader.readAsDataURL file

Template.note.isValidImageUrl = (url, callback) ->
  $ '<img>',
    src: url
    error: ->
      callback url, false
    load: ->
      callback url, true

Template.note.onCreated ->
  if @data.showChildren && @data.children && !FlowRouter.getParam 'searchParam'
    Meteor.call 'notes.setChildrenLastShown', {
      noteId: @data._id
    }

  @state = new ReactiveDict()
  @state.setDefault
    showMenu: false
    focused: false

  query = Notes.find({_id:@data._id})

  handle = query.observeChanges(
    changed: (id, fields) ->
      if fields.title != null
        $('#noteItem_'+id).find('.title').first().html(
          Template.notes.formatText fields.title
        )
  )

Template.note.onRendered ->
  noteElement = this
  Tracker.autorun ->
    # console.log noteElement

    if noteElement.data.title
      $(noteElement.firstNode).find('.title').first().html(
        Template.notes.formatText noteElement.data.title
      )
      $(noteElement.firstNode).find('> .noteContainer .encryptedTitle').first().html(
        Template.notes.formatText noteElement.data.title
      )
      if noteElement.data.body
        bodyHtml = Template.notes.formatText noteElement.data.body
        $(noteElement.firstNode).find('.body').first().show().html(
          bodyHtml
        )

    # $('.fileItem').draggable
    #   revert: true
    #
    # $('.note-item').droppable
    #   drop: (event, ui ) ->
    #     event.stopPropagation()
    #     if event.toElement.className.indexOf('fileItem') > -1
    #       Meteor.call 'files.setNote',
    #         fileId: event.toElement.dataset.id
    #         noteId: event.target.dataset.id
    #       , (err, res) ->

Template.note.helpers
  currentShareKey: () ->
    FlowRouter.getParam('shareKey')

  count: () ->
    @rank / 2

  files: () ->
    Meteor.subscribe 'files.note', @_id
    Files.find { noteId: @_id }

  childNotes: () ->
    if ( @showChildren && !FlowRouter.getParam 'searchParam' ) ||
    Session.get 'expand_'+@_id
      Meteor.subscribe 'notes.children',
        @_id,
        FlowRouter.getParam 'shareKey'
    if Session.get 'showComplete'
      Notes.find { parent: @_id }, sort: { complete: 1, rank: 1 }
    else
      Notes.find { parent: @_id, complete: false }, sort: { rank: 1 }

  showComplete: () ->
    Session.get 'showComplete'

  # completedCount: () ->
  #   Notes.find({ parent: @_id, complete: true }).count()

  childCount: () ->
    Notes.find({parent: @_id}).count()

  editingClass: (editing) ->
    editing and 'editing'

  expandClass: () ->
    if Notes.find({parent: @_id}).count() > 0
      if ( @showChildren && !FlowRouter.getParam 'searchParam' ) ||
      Session.get('expand_'+@_id)
        'remove'
      else
        'add'

  hoverInfo: ->
    info = 'Created '+moment(@createdAt).fromNow()+'.'
    if @updatedAt
      info += ' Updated '+moment(@updatedAt).fromNow()+'.'
    if @updateCount
      info += ' Version: '+@updateCount
    if @childrenShownCount
      info += ' Views: '+@childrenShownCount
    info

  className: ->
    className = "note"
    if @title
      tags = @title.match(/#\w+/g)
      if tags
        tags.forEach (tag) ->
          className = className + ' tag-' + tag.substr(1).toLowerCase()
    if !@showChildren && @children > 0
      className = className + ' hasHiddenChildren'
    if @children > 0
      className = className + ' hasChildren'
    if @shared
      className = className + ' shared'
    if Template.instance().state.get 'focused'
      className = className + ' focused'
    if @encrypted
      className = className + ' encrypted'
    if @favorite
      className = className + ' favorite'
    if @encryptedRoot
      className = className + ' encryptedRoot'
    className

  userOwnsNote: ->
    Meteor.userId() == @owner

  progress: ->
    setTimeout ->
      $('[data-toggle="tooltip"]').tooltip()
    , 100
    @progress

  progressClass: ->
    Template.notes.getProgressClass this

  showMenu: ->
    Template.instance().state.get 'showMenu'

  showEncrypt: ->
    Template.instance().state.get 'showEncrypt'

  displayEncrypted: ->
    if @encrypted || @encryptedRoot
      true

  # hasContent: ->
  #   Meteor.subscribe 'files.note', @_id
  #   (@body || Files.find({ noteId: @_id }).count() > 0)

Template.note.events
  'click .encryptLink, click .decryptLink, click .encryptedIcon': (event, instance) ->
    event.preventDefault()
    event.stopImmediatePropagation()
    instance.state.set 'showEncrypt', true
    # Hacky ugly shit to work around MDL modal bs
    that = this
    setTimeout ->
      $('#toggleEncrypt_'+that._id).click()
      setTimeout ->
        $('.modal.in').parent().append($('.modal-backdrop'))
        $('input.cryptPass').focus()
      , 50
    , 50

  'click .share': (event, template) ->
    setTimeout ->
      $('#__blaze-root').append($('.modal.in'))
    , 200

  'click .title a': (event, instance) ->
    event.preventDefault()
    event.stopImmediatePropagation()
    if !$(event.target).hasClass('tagLink') && !$(event.target).hasClass('atLink')
      window.open(event.target.href)
    else
      Template.App_body.playSound 'navigate'
      $(".mdl-layout__content").animate({ scrollTop: 0 }, 500)
      FlowRouter.go(event.target.pathname)

  'click .toggleComplete': (event, instance) ->
    event.preventDefault()
    event.stopImmediatePropagation()
    console.log Session.get 'showComplete'
    Session.set('showComplete',!Session.get('showComplete'))

  'click .favorite, click .unfavorite': (event, instance) ->
    event.preventDefault()
    event.stopImmediatePropagation()
    Template.App_body.playSound 'favorite'
    favorite.call
      noteId: instance.data._id

  'click .showContent': (event, instance) ->
    event.stopImmediatePropagation()
    setShowContent.call
      noteId: instance.data._id
      showContent: true
    , (err, res) ->
      $(event.target).closest('.noteContainer').find('.body')
        .html(emojione.shortnameToUnicode(instance.data.body))

  'click .hideContent': (event, instance) ->
    event.stopImmediatePropagation()
    setShowContent.call
      noteId: instance.data._id
      showContent: false

  'click .duplicate': (event) ->
    event.preventDefault()
    event.stopImmediatePropagation()
    Meteor.call 'notes.duplicate', @_id

  'click .addBody': (event, instance) ->
    setShowContent.call
      noteId: instance.data._id
      showContent: true
    , (err, res) ->
      setTimeout (->
        $(event.target).closest('.noteContainer').find('.body').fadeIn().focus()
      ), 20

  'click a.delete': (event) ->
    event.preventDefault()
    Template.App_body.playSound 'delete'
    $(event.currentTarget).closest('.note').remove()
    Meteor.call 'notes.remove',
      noteId: @_id
      shareKey: FlowRouter.getParam 'shareKey'
    , (err, res) ->
      if err
        window.location = window.location

  'mouseover .tagLink': (event) ->
    if Session.get 'dragging'
      return
    notes = Notes.search event.target.innerHTML, null, 5
    $('#tagSearchPreview').html('')
    notes.forEach (note) ->
      # Only show the note in the preview box if it is not the current note being hovered.
      if note._id != $(event.target).closest('.note-item').data('id')
        $('#tagSearchPreview').append('<li><a class="previewTagLink">'+
        Template.notes.formatText(note.title,false)+'</a></li>')
          .css('top', event.pageY - Template.note.previewYOffset + 'px')
          .css('left', event.pageX + Template.note.previewXOffset + 'px')
          .show()
    $('#tagSearchPreview').append('<li><a class="previewTagViewAll">Click to view all</a></li>')

  'mousemove .tagLink': (event) ->
    $('#tagSearchPreview').css('top', event.pageY - Template.note.previewXOffset + 'px')
      .css 'left', event.pageX + Template.note.previewYOffset + 'px'

  'mouseleave .tagLink': (event) ->
    $('#tagSearchPreview').hide()

  'mouseover .previewLink': (event) ->
    if Session.get 'dragging'
      return
    date = new Date
    url = event.currentTarget.href
    Template.note.isValidImageUrl url, (url, valid) ->
      if valid
        if url.indexOf("?") > -1
          imageUrl = url + "&" + date.getTime()
        else
          imageUrl = url + "?" + date.getTime()
        $('body').append '<p id=\'preview\'><a href=\'' +
          url + '\' target=\'_blank\'><img src=\'' + imageUrl +
          '\' alt=\'Image preview\' /></p>'
        $('#preview').css('top', event.pageY - Template.note.previewYOffset + 'px')
          .css('left', event.pageX + Template.note.previewXOffset + 'px')
          .fadeIn 'fast'
        # This needs to be here
        $('#preview img').mouseleave ->
          $('#preview').remove()

  'mousemove .previewLink': (event) ->
    $('#preview').css('top', event.pageY - Template.note.previewYOffset + 'px')
      .css 'left', event.pageX + Template.note.previewXOffset + 'px'

  'mouseleave .previewLink': (event) ->
    $('#preview').remove()

  'paste .title': (event, instance) ->
    event.preventDefault()
    event.stopImmediatePropagation()

    lines = event.originalEvent.clipboardData.getData('text/plain').split(/\n/g)

    # Add the first line to the current note
    line = lines.shift()
    combinedTitle = event.target.innerHTML + line
    Meteor.call 'notes.updateTitle', {
      noteId: instance.data._id
      title: combinedTitle
      shareKey: FlowRouter.getParam('shareKey')
    }
      
    lines.forEach (line) ->
      if line
        Meteor.call 'notes.insert', {
          title: line
          rank: instance.data.rank + 1
          parent: instance.data.parent
          shareKey: FlowRouter.getParam('shareKey')
        }

  'keydown .title': (event, instance) ->
    note = this
    event.stopImmediatePropagation()
    switch event.keyCode
      # Cmd ] - Zoom in
      when 221
        if event.metaKey
          FlowRouter.go('/note/'+instance.data._id)

      # Cmd [ - Zoom out
      when 219
        if event.metaKey
          FlowRouter.go('/note/'+instance.data.parent)

      # Enter
      when 13
        event.preventDefault()
        if $('.textcomplete-dropdown:visible').length < 1
          if event.shiftKey
            # Edit the body
            setShowContent.call
              noteId: instance.data._id
              showContent: true
            , (err, res) ->
              $(event.target).siblings('.body').fadeIn().focus()
          else if event.ctrlKey
            Template.note.toggleChildren instance
          else
            # Chop the text in half at the cursor
            # put what's on the left in a note on top
            # put what's to the right in a note below
            position = event.target.selectionStart
            text = event.target.innerHTML
            if !position
              range = window.getSelection().getRangeAt(0)
              position = range.startOffset

            topNote = text.substr(0, position)
            bottomNote = text.substr(position)
            if topNote != Template.note.stripTags(note.title)
              Meteor.call 'notes.updateTitle', {
                noteId: note._id
                title: topNote
                shareKey: FlowRouter.getParam('shareKey')
              }
            Template.App_body.playSound 'newNote'
            # Create a new note below the current.
            Meteor.call 'notes.insert', {
              title: bottomNote
              rank: note.rank + 1
              parent: note.parent
              shareKey: FlowRouter.getParam('shareKey')
            }, (err, res) ->
              if err
                Template.App_body.showSnackbar
                  message: err.error
                  actionHandler: ->
                    FlowRouter.go('/account')
                  ,
                  actionText: 'More Info'
            Template.note.focus $(event.target).closest('.note-item').next()[0]

      # Tab
      when 9
        event.preventDefault()
        Session.set 'indenting', true
        # First save the title in case it was changed.
        title = Template.note.stripTags(event.target.innerHTML)
        if title != @title
          Meteor.call 'notes.updateTitle',
            noteId: @_id
            title: title

            # FlowRouter.getParam 'shareKey'
        parent_id = Blaze.getData(
          $(event.currentTarget).closest('.note-item').prev().get(0)
        )._id
        noteId = @_id
        if event.shiftKey
          Meteor.call 'notes.outdent', {
            noteId: noteId
            shareKey: FlowRouter.getParam 'shareKey'
          }
          Template.note.focus $('#noteItem_'+noteId)[0]

        else
          childCount = Notes.find({parent: parent_id}).count()
          Meteor.call 'notes.makeChild', {
            noteId: @_id
            parent: parent_id
            rank: (childCount*2)+1
            shareKey: FlowRouter.getParam 'shareKey'
          }
          Template.note.focus $('#noteItem_'+noteId)[0]

      # Backspace / delete
      when 8
        if $('.textcomplete-dropdown:visible').length
          # We're showing a dropdown, don't do anything.
          return
        
        # If the note is empty and hit delete again, or delete with meta key
        if event.currentTarget.innerText.trim().length == 0 || event.metaKey
          $(event.currentTarget).closest('.note-item').fadeOut()
          Template.App_body.playSound 'delete'
          Meteor.call 'notes.remove',
            noteId: @_id
            shareKey: FlowRouter.getParam 'shareKey'
          Template.note.focus $(event.currentTarget).closest('.note-item').prev()[0]
          return

        # If there is no selection
        if window.getSelection().toString() == ''
          position = event.target.selectionStart
          if !position
            range = window.getSelection().getRangeAt(0)
            position = range.startOffset
          if position == 0
            # We're at the start of the note,
            # add this to the note above, and remove it.
            prev = $(event.currentTarget).closest('.note-item').prev()
            prevNote = Blaze.getData(prev.get(0))
            note = this
            Template.App_body.playSound 'delete'
            Meteor.call 'notes.updateTitle', {
              noteId: prevNote._id
              title: prevNote.title + event.target.innerHTML
              shareKey: FlowRouter.getParam 'shareKey'
            }, (err, res) ->
              if !err
                Meteor.call 'notes.remove',
                  noteId: note._id,
                  shareKey: FlowRouter.getParam 'shareKey',
                  (err, res) ->
                    # Moves the caret to the correct position
                    if !err
                      prev.find('div.title').focus()

      # . Period
      when 190
        if event.metaKey
          Template.note.toggleChildren(instance)

      # Up
      when 38
        if $('.textcomplete-dropdown:visible').length
          # We're showing a dropdown, don't do anything.
          event.preventDefault()
          return false
        if $(event.currentTarget).closest('.note-item').prev().length
          if event.metaKey
            # Move note above the previous note
            item = $(event.currentTarget).closest('.note-item')
            prev = item.prev()
            if prev.length == 0
              return
            prev.css('z-index', 999).css('position', 'relative').animate { top: item.height() }, 250
            item.css('z-index', 1000).css('position', 'relative').animate { top: '-' + prev.height() }, 300, ->
              setTimeout ->
                prev.css('z-index', '').css('top', '').css 'position', ''
                item.css('z-index', '').css('top', '').css 'position', ''
                item.insertBefore prev
                Template.note.focus item[0]
              , 50
          else
            # Focus on the previous note
            Template.note.focus $(event.currentTarget).closest('.note-item').prev()[0]
        else
          # There is no previous note in the current sub list, go up a note.
          Template.note.focus $(event.currentTarget).closest('ol').closest('.note-item')[0]

      # Down
      when 40
        # Command is held
        if event.metaKey
          # Move down
          item = $(event.currentTarget).closest('.note-item')
          next = item.next()
          if next.length == 0
            return
          next.css('z-index', 999).css('position', 'relative').animate { top: '-' + item.height() }, 250
          item.css('z-index', 1000).css('position', 'relative').animate { top: next.height() }, 300, ->
            setTimeout ->
              next.css('z-index', '').css('top', '').css 'position', ''
              item.css('z-index', '').css('top', '').css 'position', ''
              item.insertAfter next
              Template.note.focus item.find('div.title').last()[0]
              upperSibling = item.prev()
              view = Blaze.getView(upperSibling)
              instance = view.templateInstance()
              # console.log instance
              Meteor.call 'notes.makeChild', {
                noteId: @_id
                parent: parent_id
                upperSibling: upperSiblingId
                shareKey: FlowRouter.getParam 'shareKey'
              }
            , 50
        else
          if $('.textcomplete-dropdown:visible').length
            # We're showing a dropdown, don't do anything.
            event.preventDefault()
            return false
          # Go to a child note if available
          note = $(event.currentTarget).closest('.note-item')
            .find('ol .note-item').first()
          if !note.length
            # If not, get the next note on the same level
            note = $(event.currentTarget).closest('.note-item').next()
          if !note.length
            # Nothing there, keep going up levels.
            count = 0
            searchNote = $(event.currentTarget).parent().closest('.note-item')
            while note.length < 1 && count < 10
              note = searchNote.next()
              if !note.length
                searchNote = searchNote.parent().closest('.note-item')
                count++
          if note.length
            Template.note.focus note[0]
          else
            $('#new-note').focus()

      # Escape
      when 27
        if $('.textcomplete-dropdown:visible').length
          # We're showing a dropdown, don't do anything.
          event.preventDefault()
          return false
        $(event.currentTarget).blur()
        window.getSelection().removeAllRanges()

  'keydown .body': (event, instance) ->
    note = this
    event.stopImmediatePropagation()
    switch event.keyCode
      # Escape
      when 27
        if $('.textcomplete-dropdown:visible').length
          # We're showing a dropdown, don't do anything.
          event.preventDefault()
          return false
        $(event.currentTarget).blur()
        window.getSelection().removeAllRanges()


  'click .title': (event, instance) ->
    event.stopImmediatePropagation()
    if instance.state
      instance.state.set 'focused', true
      Session.set 'focused', true

  'focus .title, focus .body': (event, instance) ->
    Session.set 'focused', true
    $('.title,.body').textcomplete [ {
      match: /\B:([\-+\w]*)$/
      search: (term, callback) ->
        results = []
        results2 = []
        results3 = []
        $.each Template.App_body.emojiStrategy, (shortname, data) ->
          if shortname.indexOf(term) > -1
            results.push shortname
          else
            if data.aliases != null and data.aliases.indexOf(term) > -1
              results2.push shortname
            else if data.keywords != null and data.keywords.indexOf(term) > -1
              results3.push shortname
          return
        if term.length >= 3
          results.sort (a, b) ->
            a.length > b.length
          results2.sort (a, b) ->
            a.length > b.length
          results3.sort()
        newResults = results.concat(results2).concat(results3)
        callback newResults
        return
      template: (shortname) ->
        '<img class="emojione" src="//cdn.jsdelivr.net/emojione/assets/png/' +
        Template.App_body.emojiStrategy[shortname].unicode + '.png"> :' + shortname + ':'
      replace: (shortname) ->
        Template.App_body.insertingData = true
        return ':' + shortname + ': '
      index: 1
      maxCount: 10
    } ], footer:
      '<a href="http://www.emoji.codes" target="_blank">'+
      'Browse All<span class="arrow">»</span></a>'

  'blur .title': (event, instance) ->
    Template.instance().state.set 'focused', false
    Session.set 'focused', false
    that = this
    event.stopPropagation()
    # If we blurred because we hit tab and are causing an indent
    # don't save the title here, it was already saved with the
    # indent event.
    if Session.get 'indenting'
      Session.set 'indenting', false
      return

    title = Template.note.stripTags(event.target.innerHTML)
    if !@title || title != Template.note.stripTags emojione.shortnameToUnicode @title
      setTimeout ->
        $(event.target).html Template.notes.formatText title
      , 20
      Meteor.call 'notes.updateTitle', {
        noteId: instance.data._id
        title: title
        shareKey: FlowRouter.getParam 'shareKey'
      }

  'blur .body': (event, instance) ->
    event.stopPropagation()
    that = this
    Session.set 'focused', false
    # console.log event.target
    body = Template.note.stripTags event.target.innerHTML
    if body != Template.note.stripTags(@body)
      Meteor.call 'notes.updateBody', {
        noteId: instance.data._id
        body: body
        shareKey: FlowRouter.getParam 'shareKey'
      }, (err, res) ->
        that.body = body
        $(event.target).html Template.notes.formatText body
    if !body
      $(event.target).fadeOut()

  'click .expand': (event, instance) ->
    event.stopImmediatePropagation()
    event.preventDefault()
    $('.mdl-tooltip').fadeOut().remove()
    if instance.data.showChildren
      Template.App_body.playSound 'collapse'
    else
      Template.App_body.playSound 'expand'

    Template.note.toggleChildren(instance)

  'click .dot': (event, instance) ->
    event.preventDefault()
    event.stopImmediatePropagation()
    if !Session.get 'dragging'
      Template.App_body.playSound 'navigate'
      $(".mdl-layout__content").animate({ scrollTop: 0 }, 500)
      FlowRouter.go '/note/'+instance.data._id+'/'+(FlowRouter.getParam('shareKey')||'')

  'click .menuToggle': (event, instance) ->
    event.stopImmediatePropagation()
    if instance.state.get('showMenu') == true
      document.querySelector('#menu_'+instance.data._id).MaterialMenu.hide()
      instance.state.set 'showMenu', false
    else
      instance.state.set 'showMenu', true
      # Give the menu time to render
      instance.menuTimer = setTimeout ->
        document.querySelector('#menu_'+instance.data._id).MaterialMenu.show()
      , 20

  'dragover .title, dragover .filesContainer': (event, instance) ->
    $(event.currentTarget).closest('.noteContainer').addClass 'dragging'

  'dragleave .title, dragleave .filesContainer': (event, instance) ->
    $(event.currentTarget).closest('.noteContainer').removeClass 'dragging'

  'drop .title, drop .filesContainer, drop .noteContainer': (event, instance) ->
    event.preventDefault()
    event.stopPropagation()


    if event.toElement
      console.log "Move file!"
    else
      for file in event.originalEvent.dataTransfer.files
        name = file.name
        Template.note.encodeImageFileAsURL (res) ->
          upload.call {
            noteId: instance.data._id
            data: res
            name: name
          }, (err, res) ->
            $(event.currentTarget).closest('.noteContainer').removeClass 'dragging'
        , file

Template.note.toggleChildren = (instance) ->
  if Meteor.userId()
    if !instance.showChildren
        Meteor.call 'notes.setChildrenLastShown', {
          noteId: instance.data._id
        }

    Meteor.call 'notes.setShowChildren', {
      noteId: instance.data._id
      show: !instance.data.showChildren
      shareKey: FlowRouter.getParam 'shareKey'
    }
  else
    Session.set 'expand_'+instance.data._id, !Session.get('expand_'+instance.data._id)

Template.note.focus = (noteItem) ->
  view = Blaze.getView(noteItem)
  instance = view.templateInstance()
  $(noteItem).find('.title').first().focus()
  if instance.state
    instance.state.set 'focused', true
    Session.set 'focused', true

Template.note.stripTags = (inputText) ->
  if !inputText
    return
  inputText = inputText.replace(/<\/?span[^>]*>/g, '')
  inputText = inputText.replace(/&nbsp;/g, ' ')
  inputText = inputText.replace(/<\/?a[^>]*>/g, '')
  if inputText
    inputText = inputText.trim()
  inputText

Template.note.setCursorToEnd = (ele) ->
  range = document.createRange()
  sel = window.getSelection()
  range.setStart ele, 1
  range.collapse true
  sel.removeAllRanges()
  sel.addRange range
  ele.focus()

