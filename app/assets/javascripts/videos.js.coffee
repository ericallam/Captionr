
Captionr.Models.Video = Backbone.Model.extend {}

Captionr.Models.Marker = Backbone.Model.extend {}

Captionr.Collections.Markers = Backbone.Collection.extend
  model: Captionr.Models.Marker
  localStorage: new Store("markers")

class VideoPlaybackSession
  constructor: (@video) ->
  
  start: ->
    @startTime = @video.played.end(@video.played.length - 1)

  end: ->
    @endTime = @video.played.end(@video.played.length - 1)
  

Captionr.Views.Video = Backbone.View.extend
  template: _.template(
    '''
      <video src="{{ url }}" controls></video> 
    '''
  )

  render: ->
    $(@el).html(@template(@model.toJSON()))
    @

  startCaptionSession: ->
    console.log 'starting caption session'
    @session = new VideoPlaybackSession($('video')[0])
    @session.start()

  endCaptionSession: ->
    console.log 'ending caption session'
    @session.end()

  getLastSessionStartTime: ->
    @session.startTime

  getLastSessionEndTime: ->
    @session.endTime


Captionr.Views.Marker = Backbone.View.extend
  tagName: 'li'
  template: _.template(
    '''
      <span class='start-time'>{{ startTime }}</span> - <span class='end-time'>{{ endTime }}</span>
      <blockquote>{{ caption }}</blockquote>
    '''
  )

  initialize: ->
    _.bindAll @, 'render'
    @model.bind 'change', @render

  render: ->
    $(@el).html @template(@model.toJSON())
    @

Captionr.Views.App = Backbone.View.extend
  el: '#captionr'
  events:
    'keyup #new-marker': 'manageCaptionSession'
    'keypress #new-marker': 'createOnEnter'

  initialize: ->
    _.bindAll @, 'render', 'createOnEnter'

    @input = $('#new-marker')
    @video = @options.video

    @collection.bind 'add', @addOne, @
    @collection.bind 'reset', @addAll, @
    @collection.bind 'all', @render, @
    @collection.fetch()

  render: ->
    if $('video').length == 0
      $('#video-holder').append @options.video.render().el

    @
  
  addOne: (marker) ->
    view  = new Captionr.Views.Marker(model: marker)
    $('#marker-list').prepend view.render().el

  addAll: ->
    @collection.each @addOne

  manageCaptionSession: (e) ->
    text = @input.val()
    
    if text.length == 1
      @video.startCaptionSession()
  
  createOnEnter: (e) ->
    text = @input.val()
    
    return unless text.length > 0 and e.keyCode == 13

    @video.endCaptionSession()

    @collection.create
      caption: text
      startTime: @video.getLastSessionStartTime()
      endTime: @video.getLastSessionEndTime()
    
    @input.val ''

Captionr.mainVideo = new Captionr.Models.Video({url: 'http://www.viddler.com/explore/codeschool/videos/201.mp4?vfid=7281015b4829d4d969f2f6f3e554defc'})

Captionr.mainVideoView = new Captionr.Views.Video
  model: Captionr.mainVideo

$ ->
  Captionr.app = new Captionr.Views.App
    collection: new Captionr.Collections.Markers()
    video: Captionr.mainVideoView
