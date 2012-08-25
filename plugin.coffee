fs = require 'fs'
path = require 'path'
async = require 'async'
_ = require 'underscore'


# Borrowed from wintersmith/common.coffee
readJSON = (filename, callback) ->
  ### read and try to parse *filename* as json ###
  async.waterfall [
    (callback) ->
      fs.readFile filename, callback
    (buffer, callback) ->
      try
        rv = JSON.parse buffer.toString()
        callback null, rv
      catch error
        error.filename = filename
        error.message = "parsing #{ path.basename(filename) }: #{ error.message }"
        callback error
  ], callback


module.exports = (wintersmith, callback) ->

  class ArchivePlugin extends wintersmith.ContentPlugin

    constructor: (@_filename, @_text, @_metadata) ->

    getFilename: ->
      @_filename

    render: (locals, contents, templates, callback) ->

      # Reduce the contents of the articles directories to just pointers to the index in each one
      articles = _.chain contents.articles._.directories.map (item) ->
        item.index
      .compact().sortBy (item) ->
        -item.date
      .value()

      # Then map the articles into objects organised by year and month
      articlesByDate = {}

      _.each articles, (article, name) ->
        dateParts = article._metadata.date.split '-'
        articlesByDate[dateParts[0]] ?= {}
        articlesByDate[dateParts[0]][dateParts[1]] ?= {
          monthName: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][dateParts[1]-1]
          articles: []
        }

        articlesByDate[dateParts[0]][dateParts[1]].articles.push article

      cleanedContents =
        locals: locals,
        articlesByDate: articlesByDate,
        sortedArticleDates: (_.chain articlesByDate).keys().reverse().map (year) ->
          return {
            year: year,
            months: (_.chain articlesByDate[year]).keys().reverse().value()
          }
        .value()

      templates[@_metadata.template].render cleanedContents, callback

    ArchivePlugin.fromFile = (filename, base, callback) ->
      async.waterfall [
        async.apply readJSON, path.join(base, filename)
        (metadata, callback) =>
          page = new this metadata.filename ? filename, metadata.content or '', metadata
          callback null, page
      ], callback

  wintersmith.registerContentPlugin 'archives', '**/archive.json', ArchivePlugin
  callback() # tell the plugin manager we are done