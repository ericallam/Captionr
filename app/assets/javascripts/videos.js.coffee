
window.toSRTTime = (seconds) ->
  hours = Math.floor ( seconds / 3600 )
  minutes = Math.floor ( seconds / 60 )
  milliseconds = seconds.toString().split('.')[1].slice(0, 3)
  seconds = Math.floor(seconds) % 60

  sprintf "%02d:%02d:%02d,%s", hours, minutes, seconds, milliseconds

# TODO:
# remove chapter markers
# remove all chapter markers
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
  localStorage: new Store("markers")

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
    _.bindAll @, 'render', 'remove'
    @model.bind 'change', @render
    @model.bind 'destroy', @remove

  render: ->
    $(@el).html @template(@model.toJSON())
    @

  remove: ->
    $(@el).remove()

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
  
  handleExport: ->
    srt = @collection.toSRT()
    @output.val(srt)
    @output.show()

  redo: ->
    @collection.destroyAllModels()

Captionr.mainVideo = new Captionr.Models.Video({url: 'http://www.viddler.com/explore/codeschool/videos/201.mp4?vfid=7281015b4829d4d969f2f6f3e554defc'})

Captionr.mainVideoView = new Captionr.Views.Video
  model: Captionr.mainVideo

$ ->
  Captionr.app = new Captionr.Views.App
    collection: new Captionr.Collections.Markers()
    video: Captionr.mainVideoView
