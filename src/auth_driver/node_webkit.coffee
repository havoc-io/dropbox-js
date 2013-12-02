# OAuth driver that uses a node-webkit Window to complete the flow.
class Dropbox.AuthDriver.NodeWebkit extends Dropbox.AuthDriver.BrowserBase
  # Sets up an OAuth driver for node-webkit applications.
  #
  # @param {Object} options (optional) one of the settings below
  # @option options {String} scope embedded in the localStorage key that holds
  #   the authentication data; useful for having multiple OAuth tokens in a
  #   single application
  # @option options {Boolean} rememberUser if false, the user's OAuth tokens
  #   are not saved in localStorage; true by default
  constructor: (options) ->
    super options

  # URL of the page that the user will be redirected to.
  #
  # @return {String} a page on the Dropbox site that will not redirect; this is
  #   not a new point of failure, because the OAuth flow already depends on
  #   the Dropbox site being up and reachable
  # @see Dropbox.AuthDriver#url
  url: ->
    'https://www.dropbox.com/1/oauth2/redirect_receiver'

  # Shows the authorization URL in a pop-up, waits for it to send a message.
  #
  # @see Dropbox.AuthDriver#doAuthorize
  doAuthorize: (authUrl, stateParam, client, callback) ->
    # Grab the node-webkit GUI module
    gui = require 'nw.gui'

    # Launch the browser window
    browserOptions = 
        focus: true
        toolbar: false
        min_width: 800
        min_height: 600
    browser = gui.Window.open authUrl, browserOptions

    # Track whether or not we've already removed our event handlers
    removed = false

    # Create callback for window location change
    onEvent = () =>
      browserUrl = browser.window.location;
      if browserUrl and @locationStateParam(browserUrl) is stateParam
        return if removed
        browser.removeAllListeners 'loading'
        browser.removeAllListeners 'loaded'
        browser.removeAllListeners 'close'
        removed = true

        # Close the browser window
        browser.close()
        
        # Extract authentication parameters
        callback Dropbox.Util.Oauth.queryParamsFromUrl(browserUrl)
        return

    # Create callback for window close
    onClose = () =>
      return if removed
      browser.removeAllListeners 'loading'
      browser.removeAllListeners 'loaded'
      browser.removeAllListeners 'close'
      removed = true
      callback new AuthError(
          'error=access_denied&error_description=User+closed+browser+window')
      return

    # Register events handlers
    browser.on 'loading', onEvent
    browser.on 'loaded', onEvent
    browser.on 'close', onClose
