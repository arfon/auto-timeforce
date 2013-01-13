utils = require 'utils'
casper = require('casper').create
  verbose: true
  logLevel: 'debug'
  waitTimeout: 15000

if casper.cli.has(0)
  startDate = casper.cli.get(0)
else
  startDate = new Date()
  startDate = startDate.toLocaleDateString()

USERNAME = ''
PASSWORD = ''
COMPANY_CODE = ''
HOURS_PER_DAY = 7

BACK_LINK = 'img[name="Head_B"]'
FORWARD_LINK = 'img[name="Head_F"]'
VERIFY_LINK = 'img[onclick^="empVerify"]'
DATE_CHANGE_LINK = 'img[name="TCGo"]'
TIME_INT_POPUP_LINK = '.submitsmallstyle'
TIME_SUBMIT_LINK = 'input[name="submit1"]'
LOGIN_WINDOW = '#LoginWindow'

###
This isn't internal grant/job numbers, but the value that timeforce
assgins to the options element of a particular job. Here are some common
ones to use:
  CDI: 5757
  CI Team: 1122
  Zooniverse: 4455
  Zooniverse PH: 13766
  Zooniverse SETI: 5773
  Zooniverse Sloan: 11583
  Zooniverse SOCS: 13524
###
JOB = 5757
 
links = []
currentLink = 0
attempts = 0

getLinks = (startDate) ->
  links = document.querySelectorAll '.TCDayNormalBold'

  filterLinks = (link) =>
    if link.textContent != '0.00'
      return false

    date = new Date(link.getAttribute('href').split('\'')[1])
    startDate = new Date(startDate)

    if startDate.getTime() < date.getTime()
      return false

    if 0 < date.getDay() < 6
      return true
    else
      return false

  parseLink = (link) ->
    return link.href

  (parseLink link for link, i in links when filterLinks link)

parse = ->
  utils.dump links
  if links is null
    if attempts is 1
      @echo '# No hours left to fill.', 'COMMENT'
      @exit()
    else
      # For the case where you select a start date that results in no links
      # being selected on that page.
      @echo '# Retry once.', 'COMMENT'
      attempts += 1
      @click BACK_LINK
      @then parsePage
  else
    if currentLink < links.length
      link = links[currentLink]
      link = link.charAt(0).toUpperCase() + link.slice(1) # Sigh

      currentLink += 1

      @echo '# Clicking link.', 'COMMENT'

      @click 'a[href="' + link + '"]'
      @wait 500

      @waitForPopup /timeHRSelect/, ->
        @echo '# Popup exists.', 'COMMENT'

      @withPopup /timeHRSelect/, ->
        @echo '# Within intermediate popup.', 'COMMENT'
        @waitForSelector TIME_INT_POPUP_LINK, ->
          @click TIME_INT_POPUP_LINK 

      @waitForPopup /timeHRChange\.asp/, ->
        @echo '# Time input popup exists.', 'COMMENT'

      @withPopup /timeHRChange\.asp/, ->
        @echo '# Within timecard popup.', 'COMMENT'
        @waitForSelector TIME_SUBMIT_LINK, ->
          elements =
            'thetotalhr': HOURS_PER_DAY
            'job': JOB
          @fill 'body', elements, false
          @click TIME_SUBMIT_LINK

      @then parse

    else 
      @echo '# Verifying time is correct.', 'COMMENT'

      @test.assertExists VERIFY_LINK, 'Verify link found.'
      if @exists VERIFY_LINK
        @click VERIFY_LINK
        @wait 5000, ->
          @then goBack
      else
        @then goBack

parsePage = ->
  @echo '# Parsing new timecard page.', 'COMMENT'
  currentLink = 0
  links = @evaluate getLinks, startDate
  @then parse

goBack = ->
  @test.assertExists BACK_LINK, 'Back link found.'
  @click BACK_LINK
  @then parsePage


casper.start 'https://www.gotimeforce.com', ->
  elements =
    'username': USERNAME
    'Password': PASSWORD
    'CompanyCode': COMPANY_CODE

  @test.assertExists LOGIN_WINDOW, 'found login form'
  @fill LOGIN_WINDOW, elements, false

  @click '#Image1'

casper.then ->
  @echo '# Filling in hours.', 'COMMENT'
  elements =
    'datechange': startDate
  @fill '.TimeRow1', elements, false

  @click DATE_CHANGE_LINK

  @on 'popup.loaded', (page) ->
    @echo 'Popup loaded.', 'INFO'
    utils.dump page.title

  @on 'popup.closed', (page) ->
    @echo 'Popup closed.', 'INFO'

  @then parsePage

casper.run()