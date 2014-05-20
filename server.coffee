
_ = require "underscore"
Backbone = require "backbone"

fs = require "fs"
path = require "path"
url = require "url"
os = require "os"
connect = require "connect"
ssiParser = require "./parser/lib/node-ssi-parser"

class LocalSSIServer extends Backbone.Model
  ROOT: path.join(__dirname, "public")
  # HOSTNAME: _(os.networkInterfaces()["en0"]).find((itf) -> itf.family is "IPv4").address
  HOSTNAME: os.hostname()
  PORT: 8000
  app: null

  initialize: ->
    @app = connect()

    # @app.use @redirectAgent
    @app.use @ssiAgent
    @app.use connect.static(@ROOT)
    @app.listen @PORT, => console.log @HOSTNAME + ":" + @PORT

  # Redirect from localhost to hostname
  redirectAgent: (req, res, next) =>
    if req.headers["host"].indexOf("localhost") != -1
      res.writeHead(301, {
        "Location": "http://#{os.hostname()}:#{@PORT}"
      })
      return res.end()

    next()

  # SSI parser
  ssiAgent: (req, res, next) =>
    filepath = @convertURLtoFilePath req.url

    if ".html" == path.extname(filepath)
      console.log("Server-parsed:", filepath)
      res.setHeader "Content-Type", "text/html"

      html = fs.readFileSync(filepath).toString()
      host = req.headers["host"]

      # SSI
      parsed = ssiParser(filepath, html)
      parsed = @parseBaseTag parsed, host

      # livereload
      parsed = parsed.replace "<!--%livereload-->", "<script src='http://localhost:35729/livereload.js'></script>"
      parsed = parsed.replace "<?php bloginfo('template_url') ?>/", ""

      res.end(parsed)

    else
      next()

  convertURLtoFilePath: (requrl) ->
    pathname = url.parse(requrl).pathname
    pathname += "index.html" if pathname.match(/\/$/)
    filepath = path.join(@ROOT, pathname)

  parseBaseTag: (html, host) ->
    pattern = /<!-- BASE -->\s*.*\s*<!-- \/BASE -->/
    localBase = "<base href='http://#{url.parse("http://"+host).hostname}:#{@PORT}/'>"
    html.replace(pattern, localBase)

new LocalSSIServer()
