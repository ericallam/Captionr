
window.toSRTTime = (seconds) ->
  hours = Math.floor ( seconds / 3600 )
  minutes = Math.floor ( seconds / 60 )
  milliseconds = seconds.toString().split('.')[1].slice(0, 3)
  seconds = Math.floor(seconds) % 60

  sprintf "%02d:%02d:%02d,%s", hours, minutes, seconds, milliseconds

window.prettifyTime = (seconds) ->
  hours = Math.floor ( seconds / 3600 )
  minutes = Math.floor ( seconds / 60 )
  milliseconds = seconds.toString().split('.')[1].slice(0, 2)
  seconds = Math.floor(seconds) % 60

  if hours > 0
    sprintf "%02d:%02d:%02d,%s", hours, minutes, seconds, milliseconds
  else
    sprintf "%02d:%02d.%s", minutes, seconds, milliseconds



# TODO:
# change start/end times on markers
# Enter video url
class VideoPlaybackSession
  offset: 0.5

  constructor: (@video) ->
  
  start: ->
    startTime = @video.currentTime - @offset
    @startTime = startTime

  currentTime: ->
    @video.currentTime - @offset

Captionr.Models.Video = Backbone.Model.extend
  localStorage: new Store("videos")
  initialize: ->
    @markers = new Captionr.Collections.Markers()
    @markers.initializeStore @id


Captionr.Collections.VideoList = Backbone.Collection.extend
  model: Captionr.Models.Video
  localStorage: new Store("videos")

Captionr.Views.VideoListItem = Backbone.View.extend
  tagName: 'li'
  template: _.template '''
    <span class=url>{{ url }}</span>
    <button class='show btn small'>caption</button>
  '''

  events:
    'click .show': 'show'

  initialize: ->
    _.bindAll @, 'show'
    @model.on 'change', @render, @

  render: ->
    @$el.html @template(@model.toJSON())
    @

  show: ->
    Captionr.router.navigate "videos/#{@model.id}", trigger: true

Captionr.Views.VideoList = Backbone.View.extend
  tagName: 'ul'
  template: _.template '''
    <fieldset>
      <input class=span8 type=text id=new-video placeholder='Enter new video mp4 url'></input>
      <br />
    </fieldset>
  '''

  events:
    'keypress #new-video': 'createOnEnter'

  initialize: ->
    _.bindAll @, 'createOnEnter'
    @collection.on 'reset', @render, @
    @collection.on 'add', @addOne, @
  
  render: ->
    if @$('input').length == 0
      @$el.append @template()
    @collection.forEach @addOne, @
    @

  createOnEnter: ->
    url = @$('input').val()

    return if url.length == 0

    @collection.create url: url

  addOne: (model) ->
    videoListItem = new Captionr.Views.VideoListItem(model: model)
    @$el.append videoListItem.render().el

Captionr.Models.Marker = Backbone.Model.extend
  toSRT: (num) ->
    """
      #{num}
      #{toSRTTime(@get('startTime'))} --> #{toSRTTime(@get('endTime'))}
      #{@get('caption')}\n\n
    """

  toJSON: ->
    _.extend _.clone(@attributes), 
      prettyStartTime: prettifyTime(@get('startTime'))
      prettyEndTime: prettifyTime(@get('endTime')) 

  wrapsTime: (time) ->
    @get('startTime') <= time <= @get('endTime')
    

Captionr.Collections.Markers = Backbone.Collection.extend
  model: Captionr.Models.Marker
  comparator: (marker) -> marker.get('startTime')

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

  highlightFor: (time) ->
    markers = @groupBy (marker) -> marker.wrapsTime(time)

    _.each markers[true], (m) -> m.set highlighted: true
    _.each markers[false], (m) -> m.set highlighted: false

Captionr.Views.Video = Backbone.View.extend
  template: _.template(
    '''
      <video src="{{ url }}" controls width=460></video> 
    '''
  )

  render: ->
    $(@el).html(@template(@model.toJSON()))
    @

  jumpBack: ->
    @setCurrentTime @getCurrentTime() - 5

  jumpForward: ->
    @setCurrentTime @getCurrentTime() + 5

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

  setCurrentTime: (newCurrentTime) ->
    $('video')[0].currentTime = newCurrentTime

  getCurrentTime: ->
    $('video')[0].currentTime

  seekTo: (time) ->
    @setCurrentTime time


Captionr.Views.Marker = Backbone.View.extend
  tagName: 'li'
  template: _.template(
    '''
      <button class='remove btn danger small'>X</button>
      <button class='goto btn small'>-></button>
      <span class='start-time'>{{ prettyStartTime }}</span> -> <span class='end-time'>{{ prettyEndTime }}</span>
      <blockquote><p>{{ caption }}</p></blockquote>
    '''
  )

  events:
    'click .remove': 'clear'
    'click .goto': 'goto'

  initialize: ->
    _.bindAll @, 'render', 'remove', 'clear', 'goto'
    @model.bind 'change', @render, @
    @model.bind 'change:highlighted', @toggleHighlight, @
    @model.bind 'destroy', @remove, @

  render: ->
    $(@el).html @template(@model.toJSON())
    @

  remove: ->
    $(@el).remove()

  goto: ->
    Captionr.app.seekTo @model.get('startTime')

  clear: ->
    @model.destroy()

  toggleHighlight: ->
    if @model.get('highlighted')
      $(@el).addClass 'highlighted'
    else
      $(@el).removeClass 'highlighted'

Captionr.Views.App = Backbone.View.extend
  el: '#captionr'
  template: _.template '''
    <div class=page-header>
      Caption Video
    </div>

    <div class=row>
      <div class=span8>
        <div id=video-holder></div>

        <fieldset>
          <input class=span8 type=text id=new-marker placeholder='Enter caption'></input>
          <br />
        </fieldset>
      </div>

      <div class=span8>
        <ul id=marker-list class=unstyled></ul>
        <button class='btn primary' id=export>Export</button>
        <button class='btn danger' id=redo>Clear All</button>
        <textarea id=output cols=50 rows=5 style='display: none; margin-top: 10px' class=span8></textarea>
      </div>
    </div>
  '''
  events:
    'keyup #new-marker': 'manageCaptionSession'
    'keypress #new-marker': 'createOnEnter'
    'keydown #new-marker': 'seekVideo'
    'click #export': 'handleExport'
    'click #redo': 'redo'

  initialize: ->
    _.bindAll @, 'render', 'createOnEnter', 
                  'handleExport', 'redo', 'handleTimeUpdate', 'seekVideo'

    @input = $('#new-marker')
    @output = $('#output')
    @video = @options.video

    @collection.bind 'add', @addOne, @
    @collection.bind 'reset', @addAll, @
    @collection.bind 'all', @render, @
    @collection.fetch()

  render: ->
    if @$('video').length == 0
      @$el.html @template()
      @$('#video-holder').append @options.video.render().el

      @$('video').on 'timeupdate', @handleTimeUpdate
      @input = @$('#new-marker')
      @output = @$('#output')

    @
  
  addOne: (marker) ->
    view  = new Captionr.Views.Marker(model: marker)
    $('#marker-list').prepend view.render().el

  addAll: ->
    @collection.each @addOne

  manageCaptionSession: (e) ->
    return if e.keyCode == 13 or e.keyCode == 37 or e.keyCode == 39 # they pressed enter, let createOnEnter handle this

    @video.startCaptionSession() unless @video.startedCaptionSession()

  seekTo: (time) ->
    @video.seekTo time

  seekVideo: (e) ->
    text = @input.val()

    return if text.length > 0

    if e.originalEvent.keyIdentifier == "Left"
      @video.jumpBack()
    else if e.originalEvent.keyIdentifier == "Right"
      @video.jumpForward()
  
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

  handleTimeUpdate: (e) ->
    @collection.highlightFor @video.getCurrentTime()


Captionr.router = new (Backbone.Router.extend(
  routes:
    'videos/:id': 'show'
    '': 'index'

  show: (id) ->
    video = new Captionr.Models.Video(id: id)
    video.fetch()

    videoView = new Captionr.Views.Video(model: video)
    app = new Captionr.Views.App(collection: video.markers, video: videoView)
    video.markers.fetch()

  index: ->
    $('#captionr').empty()

    videoList = new Captionr.Collections.VideoList()
    videoListView = new Captionr.Views.VideoList collection: videoList
    $('#captionr').append videoListView.render().el
    videoList.fetch()

  start: ->
    Backbone.history.start()

))

$ ->
  Captionr.router.start()
