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
      title: 'Dropbox Authentication'
      focus: true
      toolbar: false
      width: 800
      height: 600
    browser = gui.Window.open authUrl, browserOptions

    # Track whether or not we've already removed our event handlers
    removed = false

    # Create a function to hide desktop/register links for App Store
    hideRegister = () =>
      # Get the head element
      head = (browser.window.document.getElementsByTagName 'head')[0]

      # Create CSS eleemnt
      css = browser.window.document.createElement 'style'
      css.type = 'text/css'
      css.appendChild browser.window.document.createTextNode '.footer{visibility:hidden;}#register-link{visibility:hidden;}'

      # Add it
      head.appendChild css

    # Create callback for window location change
    onEvent = () =>
      browserUrl = browser.window.location
      do hideRegister if browserUrl.href.match(/login/)
      if browserUrl and @locationStateParam(browserUrl) is stateParam
        return if removed
        browser.removeListener 'loading', onEvent
        browser.removeListener 'loaded', onEvent
        browser.removeListener 'close', onClose
        removed = true

        # Close the browser window
        browser.close()
        
        # Extract authentication parameters
        callback Dropbox.Util.Oauth.queryParamsFromUrl(browserUrl)
        return

    # Create callback for window close
    onClose = () =>
      return if removed
      browser.removeListener 'loading', onEvent
      browser.removeListener 'loaded', onEvent
      browser.removeListener 'close', onClose
      removed = true
      callback new AuthError(
          'error=access_denied&error_description=User+closed+browser+window')
      return

    # Register events handlers
    browser.on 'loading', onEvent
    browser.on 'loaded', onEvent
    browser.on 'close', onClose
