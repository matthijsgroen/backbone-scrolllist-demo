window.fastScrolling =
  Models: {}
  Collections: {}
  Views: {}
  Routers: {}
  init: ->
    'use strict'

    # Simulate a large dataset, using images from lorempixel.com
    #
    # We use images to represente a list of luminaires as closely as possible
    data = []
    for category in [
        'abstract'
        'animals'
        'business'
        'cats'
        'city'
        'food'
        'nightlife'
        'fashion'
        'people'
        'nature'
        'sports'
        'technics'
        'transport'
        ]
        for index in [0..100]
            data.push { index: (index % 10) + 1, category, at: data.length }
    c = new Backbone.Collection(data)

    lv = new @Views.ListView
      collection: c

    # buttons to mimic filtering and width changes
    b = new @Views.FilterView
      collection: c
      listView: lv

    $('body').append b.render().$el
    $('body').append lv.$el
    # Render so we can calculate the dimensions of the li.
    lv.render()

window.loadedImages = []

class fastScrolling.Views.ItemView extends Backbone.View
  tagName: 'li'
  events:
    'click': 'itemClick'

  render: ->
    imageSrc = "http://lorempixel.com/100/100/#{@model.get('category')}/#{@model.get('index')}/i#{@model.get('at')}"
    if _.contains(window.loadedImages, imageSrc)
      @$el.html "<img src='#{imageSrc}' />"
    else
      # Delay loading of image to prevent image fetching backlog on fast scrolling
      @$el.html "<img src='images/pixel.png' data-id='#{@model.cid}' data-src='#{imageSrc}' />"

      modelId = @model.cid
      do(modelId) ->
        setTimeout(
          ->
            $elm = $("li img[data-id=#{modelId}]")
            if $elm.length > 0
              img = new Image()
              img.onload = ->
                $elm = $("li img[data-id=#{modelId}]")
                $elm.attr('src', null)
                $elm.attr('src', $elm.data('src'))
                loadedImages.push($elm.data('src'))
              img.src = $elm.data('src')
          400
        )
    this

  itemClick: ->
    alert("Clicked #{@model.get('at')}")

class fastScrolling.Views.ListView extends Backbone.View
  className: 'scroll-pane'

  events:
    'scroll': 'updateViews'

  initialize: ->
    @models = @collection.models

    @listenTo @collection, 'startFilter', =>
      @models = @collection[0..10].concat(@collection[40..100])
      @render()

    @on 'wide', =>
      @changeWidth(640)

    @on 'narrow', =>
      @changeWidth(335)

    @listenTo @collection, 'stopFilter', =>
      @models = @collection.models
      @render()

  changeWidth: (newWidth) ->
    pr = @perRow
    scrollP = @$el.scrollTop()

    @$el.css('width', newWidth)
    @renderInitialized = no
    v.remove() for v in @views
    @render()
    newScroll = (pr / @perRow) * scrollP
    @$el.scrollTop(newScroll)


  initRender: ->
    return if @renderInitialized
    @renderInitialized = yes

    @views = [new fastScrolling.Views.ItemView(model: @models[0])]
    @$('ul').append(@views[0].render().el)
    maxWidth = @$el.width()
    maxHeight = @$el.height()
    $li = @$('ul li:first')

    @itemHeight = $li.outerHeight()
    @itemWidth = $li.outerWidth()
    @perRow = Math.floor(maxWidth / @itemWidth)
    @amountRows = (Math.ceil(maxHeight / @itemHeight) + 6)

    amountViews = @amountRows * @perRow

    for model in @models[1...amountViews]
      @views.push(new fastScrolling.Views.ItemView(model: model).render())

  render: ->
    @$el.html('<ul></ul>')
    @$el.scrollTop(0)
    @lastScrollTop = 0
    @rowOffset = 0
    @initRender()

    for view, index in @views
      if view.model.cid isnt @models[index].cid
        view.model = @models[index]
        view.render()

    elements = (v.el for v in @views)
    @$('ul').append(elements)
    @$('ul').height(Math.ceil(@models.length / @perRow) * @itemHeight)

    if (@perRow > 1)
      @$("ul li:nth-child(#{@perRow}n)").css(left: (@itemWidth * (@perRow - 1)))
    for i in [1...@perRow - 1]
      @$("ul li:nth-child(#{@perRow}n+#{1 + i})").css(left: (@itemWidth * i))

    for v, index in @views
      row = Math.floor(index / @perRow)
      v.$el.css(top: (row * @itemHeight))
    this

  updateViews: ->
    st = @$el.scrollTop()

    # Scrolling changed at least position with one row
    if Math.abs(@lastScrollTop - st) > @itemHeight
      @updateScroll()

  updateScroll: ->
    st = @$el.scrollTop()
    rowsOutOfView = Math.floor(st / @itemHeight)
    if st > @lastScrollTop # scrolling down
      if rowsOutOfView - @rowOffset > 3 # need buffer update?
        @updateDownBuffer(rowsOutOfView)
    else
      if rowsOutOfView - @rowOffset < 2 # need buffer update?
        @updateUpBuffer(rowsOutOfView)
    @lastScrollTop = st

  updateDownBuffer: (rowsOutOfView) ->
    redrawFrom = rowsOutOfView - 2
    catchUp = redrawFrom - @rowOffset

    # amount of rows still plotted in view
    plotRow = (@rowOffset + @amountRows) - redrawFrom
    plotRow = 0 if plotRow < 0

    viewsToMove = @views.splice(0, catchUp * @perRow)

    for view, index in viewsToMove
      modelIndex = ((redrawFrom + plotRow) * @perRow + index)
      @renderItem(view, modelIndex)

    @views = @views.concat(viewsToMove)
    @rowOffset = redrawFrom

  updateUpBuffer: (rowsOutOfView) ->
    redrawFrom = rowsOutOfView - 2
    catchUp = redrawFrom - @rowOffset
    if catchUp < 0 - @amountRows
      catchUp = -@amountRows

    viewsToMove = @views.splice(@views.length + (catchUp * @perRow), (catchUp * @perRow) * -1)
    for view, index in viewsToMove
      modelIndex =  redrawFrom * @perRow + index
      @renderItem(view, modelIndex)
    @views = viewsToMove.concat(@views)
    @rowOffset += catchUp

  renderItem: (view, modelIndex) ->
    if modelIndex < @models.length and modelIndex >= 0
      newTop = (Math.floor(modelIndex / @perRow)) * @itemHeight
      newLeft = (modelIndex % @perRow) * @itemWidth
      view.$el.css(top: newTop, left: newLeft)
      view.model = @models[modelIndex]
      view.render()

class fastScrolling.Views.FilterView extends Backbone.View

  events:
    'click .filter-on': 'startFilter'
    'click .filter-off': 'stopFilter'
    'click .wide': 'wideView'
    'click .narrow': 'narrowView'

  initialize: ({ @listView }) ->

  render: ->
    @$el.html(
      '<button class="filter-on">Filter On</button>' +
      '<button class="filter-off">Filter Off</button>' +
      '<button class="wide">Wide</button>' +
      '<button class="narrow">Narrow</button>'
    )
    this

  startFilter: ->
    @collection.trigger('startFilter')

  stopFilter: ->
    @collection.trigger('stopFilter')

  wideView: ->
    @listView.trigger('wide')

  narrowView: ->
    @listView.trigger('narrow')


$ ->
  'use strict'
  fastScrolling.init()
