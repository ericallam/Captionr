
window.toSRTTime = (seconds) ->
  hours = Math.floor ( seconds / 3600 )
  minutes = Math.floor ( seconds / 60 )
  milliseconds = seconds.toString().split('.')[1].slice(0, 3)
  seconds = Math.floor(seconds) % 60

  sprintf "%02d:%02d:%02d,%s", hours, minutes, seconds, milliseconds

# TODO:
# change start/end times on markers
# Enter video url
# highlight chapter markers as the are active

Captionr.Models.Video = Backbone.Model.extend {}

Captionr.Models.Marker = Backbone.Model.extend
  toSRT: (num) ->
    """
      #{num}
      #{toSRTTime(@get('startTime'))} --> #{toSRTTime(@get('endTime'))}
      #{@get('caption')}\n\n
    """

Captionr.Collections.Markers = Backbone.Collection.extend
  model: Captionr.Models.Marker

  initializeStore: (videoId) ->
    @localStorage = new Store "markers-video-#{videoId}"

  toSRT: ->
    @reduce(
      (srt, marker, index) ->
        srt += marker.toSRT(index+1)
      ""
    )

  destroyAllModels: ->
    _.each _.clone(@models), (model) ->
      model.destroy()

class VideoPlaybackSession
  offset: 0.5

  constructor: (@video) ->
  
  start: ->
    startTime = @video.played.end(@video.played.length - 1) - @offset
    @startTime = startTime

  currentTime: ->
    @video.played.end(@video.played.length - 1) - @offset
  

Captionr.Views.Video = Backbone.View.extend
  template: _.template(
    '''
      <video src="{{ url }}" controls></video> 
    '''
  )

  render: ->
    $(@el).html(@template(@model.toJSON()))
    @

  startedCaptionSession: ->
    @session?

  startCaptionSession: ->
    @session = new VideoPlaybackSession($('video')[0])
    @session.start()

  endCaptionSession: ->
    @session = null

  getLastSessionStartTime: ->
    @session.startTime

  getCurrentSessionTime: ->
    @session.currentTime()


Captionr.Views.Marker = Backbone.View.extend
  tagName: 'li'
  template: _.template(
    '''
      <a href='#' class=remove>X</a>
      <span class='start-time'>{{ startTime }}</span> - <span class='end-time'>{{ endTime }}</span>
      <blockquote>{{ caption }}</blockquote>
    '''
  )

  events:
    'click .remove': 'clear'

  initialize: ->
    _.bindAll @, 'render', 'remove', 'clear'
    @model.bind 'change', @render
    @model.bind 'destroy', @remove

  render: ->
    $(@el).html @template(@model.toJSON())
    @

  remove: ->
    $(@el).remove()

  clear: ->
    @model.destroy()

Captionr.Views.App = Backbone.View.extend
  el: '#captionr'
  events:
    'keyup #new-marker': 'manageCaptionSession'
    'keypress #new-marker': 'createOnEnter'
    'click #export': 'handleExport'
    'click #redo': 'redo'

  initialize: ->
    _.bindAll @, 'render', 'createOnEnter', 'handleExport', 'redo'

    @input = $('#new-marker')
    @output = $('#output')
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
    return if e.keyCode == 13 # they pressed enter, let createOnEnter handle this

    @video.startCaptionSession() unless @video.startedCaptionSession()
  
  createOnEnter: (e) ->
    text = @input.val()
    
    return unless text.length > 0 and e.keyCode == 13

    @collection.create
      caption: text
      startTime: @video.getLastSessionStartTime()
      endTime: @video.getCurrentSessionTime()

    @video.endCaptionSession()
    @input.val ''
  
  handleExport: ->
    srt = @collection.toSRT()
    @output.val(srt)
    @output.show()

  redo: ->
    @collection.destroyAllModels()

Captionr.mainVideo = new Captionr.Models.Video({url: 'http://www.viddler.com/explore/codeschool/videos/201.mp4?vfid=7281015b4829d4d969f2f6f3e554defc', id: 1})

Captionr.mainVideoView = new Captionr.Views.Video
  model: Captionr.mainVideo

$ ->
  Captionr.markers = new Captionr.Collections.Markers()
  Captionr.markers.initializeStore(Captionr.mainVideo.id)

  Captionr.app = new Captionr.Views.App
    collection: Captionr.markers
    video: Captionr.mainVideoView
