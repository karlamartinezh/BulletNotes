// Methods related to links

import { Meteor } from 'meteor/meteor';
import { check } from 'meteor/check';
import { Match } from 'meteor/check'
import { Notes } from './notes.js';

Meteor.methods({
  'notes.insert'(title,rank=null,parent=null) {
    check(title, String);
    check(rank, Match.Maybe(Number));
    check(parent, Match.Maybe(String));

    if (! this.userId) {
      throw new Meteor.Error('not-authorized');
    }

    if (!rank) {
      rank = Notes.find().count() + 1;
    }

    return Notes.insert({
      title,
      createdAt: new Date(),
      rank: rank,
      owner: this.userId,
      parent: parent,
      level: 0
    });
  },
  'notes.updateTitle'(id,title) {
    check(title, String);

    if (! this.userId) {
      throw new Meteor.Error('not-authorized');
    }

    return Notes.update(id,{ $set: {
      title: title
    }});
  },
  'notes.updateRank'(id,rank) {
    check(rank, Number);

    if (! this.userId) {
      throw new Meteor.Error('not-authorized');
    }

    return Notes.update(id,{ $set: {
      rank: rank,
    }});
  },
  'notes.updateBody'(id,body) {
    check(body, String);

    if (! this.userId) {
      throw new Meteor.Error('not-authorized');
    }
    
    return Notes.update(id,{ $set: {
      body: body
    }});
  },
  'notes.makeChild'(id,parent) {
    check(parent, String);

    if (! this.userId) {
      throw new Meteor.Error('not-authorized');
    }

    var note = Notes.findOne(id);
    var parent = Notes.findOne(parent);
    console.log(parent,"---",note);
    if (!note || !parent) {
      return false;
    }
    Notes.update(parent._id,{$inc:{children:1}});
    Notes.update(id,{ $set: {
      parent: parent._id,
      level: parent.level+1
    }});

    var children = Notes.find({parent:id});
    children.forEach(function(child) {
      Meteor.call('notes.makeChild',child._id,id);
    });
    
  },
  'notes.remove'(id) {
    check(id, String);

    if (! this.userId) {
      throw new Meteor.Error('not-authorized');
    }

    var children = Notes.find({parent:id});
    children.forEach(function(child) {
      Meteor.call('notes.remove',child._id);
    });
    Notes.remove(id);
  },
  'notes.outdent'(id) {
    if (! this.userId) {
      throw new Meteor.Error('not-authorized');
    }

    var note = Notes.findOne(id);
    var parent = Notes.findOne(note.parent);
    parent = Notes.findOne(parent.parent);
    if (parent) {
      Meteor.call('notes.makeChild',note._id,parent._id);
    } else {
      // No parent left to go out to, set things to top level.
      var children = Notes.find({parent:note._id});
      children.forEach(function(child) {
        Notes.update(child._id,{$set:{level: 1}});
      });

      return Notes.update(id,{ $set: {
        level: 0,
        parent: null
      }});
    }

  },
  'notes.showChildren'(id,show=true) {
    if (! this.userId) {
      throw new Meteor.Error('not-authorized');
    }

    Notes.update(id, {
      $set: { showChildren: show },
    });
  }
});
