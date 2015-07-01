// Generated by CoffeeScript 1.9.2
var AccountConfigError, BadRequest, Break, ImapImpossible, NotFound, RefreshError, TimeoutError, UIDValidityChanged, americano, baseHandler, log, utils,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

module.exports = utils = {};

americano = require('americano');

utils.AccountConfigError = AccountConfigError = (function(superClass) {
  extend(AccountConfigError, superClass);

  function AccountConfigError(field, originalErr) {
    this.name = 'AccountConfigError';
    this.field = field;
    this.message = "on field '" + field + "'";
    this.stack = '';
    this.original = originalErr;
    return this;
  }

  return AccountConfigError;

})(Error);

utils.Break = Break = (function(superClass) {
  extend(Break, superClass);

  function Break() {
    this.name = 'Break';
    this.stack = '';
    return this;
  }

  return Break;

})(Error);

utils.ImapImpossible = ImapImpossible = (function(superClass) {
  extend(ImapImpossible, superClass);

  function ImapImpossible(code, originalErr) {
    this.name = 'ImapImpossible';
    this.code = code;
    this.original = originalErr;
    this.message = originalErr.message;
    Error.captureStackTrace(this, arguments.callee);
    return this;
  }

  return ImapImpossible;

})(Error);

utils.UIDValidityChanged = UIDValidityChanged = (function(superClass) {
  extend(UIDValidityChanged, superClass);

  function UIDValidityChanged(uidvalidity) {
    this.name = 'UIDValidityChanged';
    this.newUidvalidity = uidvalidity;
    this.message = "UID Validty has changed";
    Error.captureStackTrace(this, arguments.callee);
    return this;
  }

  return UIDValidityChanged;

})(Error);

utils.NotFound = NotFound = (function(superClass) {
  extend(NotFound, superClass);

  function NotFound(msg) {
    this.name = 'NotFound';
    this.status = 404;
    this.message = "Not Found: " + msg;
    Error.captureStackTrace(this, arguments.callee);
    return this;
  }

  return NotFound;

})(Error);

utils.BadRequest = BadRequest = (function(superClass) {
  extend(BadRequest, superClass);

  function BadRequest(msg) {
    this.name = 'BadRequest';
    this.status = 400;
    this.message = 'Bad request : ' + msg;
    Error.captureStackTrace(this, arguments.callee);
    return this;
  }

  return BadRequest;

})(Error);

utils.TimeoutError = TimeoutError = (function(superClass) {
  extend(TimeoutError, superClass);

  function TimeoutError(msg) {
    this.name = 'Timeout';
    this.status = 400;
    this.message = 'Timeout: ' + msg;
    Error.captureStackTrace(this, arguments.callee);
    return this;
  }

  return TimeoutError;

})(Error);

utils.HttpError = function(status, msg) {
  if (msg instanceof Error) {
    msg.status = status;
    return msg;
  } else {
    Error.call(this);
    Error.captureStackTrace(this, arguments.callee);
    this.status = status;
    this.message = msg;
    return this.name = 'HttpError';
  }
};

utils.RefreshError = RefreshError = (function(superClass) {
  extend(RefreshError, superClass);

  function RefreshError(payload) {
    this.name = 'Refresh';
    this.status = 500;
    this.message = 'Error occured during refresh';
    this.payload = payload;
    Error.captureStackTrace(this, arguments.callee);
    return this;
  }

  return RefreshError;

})(Error);

utils.isMailboxDontExist = function(err) {
  return err.message && ~err.message.indexOf("Mailbox doesn't exist");
};

utils.isFolderForbidden = function(err) {
  return /Folder name (.*) is not allowed./.test(err.message);
};

utils.isFolderDuplicate = function(err) {
  return /Duplicate folder name/.test(err.message);
};

utils.isFolderUndeletable = function(err) {
  return /Internal folder cannot be deleted/.test(err.message);
};

log = require('../utils/logging')({
  prefix: 'errorhandler'
});

baseHandler = americano.errorHandler();

utils.errorHandler = function(err, req, res, next) {
  log.debug("ERROR HANDLER CALLED", err);
  if (err instanceof utils.AccountConfigError || err.textCode === 'AUTHENTICATIONFAILED') {
    return res.status(400).send({
      name: err.name,
      field: err.field,
      stack: err.stack,
      error: true
    });
  } else if (err.message === 'Request aborted') {
    return log.warn("Request aborted");
  } else if (err instanceof utils.RefreshError) {
    return res.status(err.status).send({
      name: err.name,
      message: err.message,
      payload: err.payload
    });
  } else {
    log.error("error handler called with", err.stack);
    return baseHandler(err, req, res);
  }
};
