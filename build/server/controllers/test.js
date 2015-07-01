// Generated by CoffeeScript 1.9.2
var Account, async, cozydb;

async = require('async');

Account = require('../models/account');

cozydb = require('cozydb');

module.exports.main = function(req, res, next) {
  return async.series([
    function(cb) {
      return cozydb.api.getCozyLocale(cb);
    }, function(cb) {
      return Account.request('all', cb);
    }
  ], function(err, results) {
    var accounts, locale;
    if (err != null) {
      console.log(err);
      return res.render('test.jade', {
        imports: "console.log(\"" + err + "\")\nwindow.locale = \"en\";\nwindow.accounts = {};"
      });
    } else {
      locale = results[0], accounts = results[1];
      return res.render('test.jade', {
        imports: "window.locale   = \"" + locale + "\";\nwindow.accounts = " + (JSON.stringify(accounts)) + ";"
      });
    }
  });
};
