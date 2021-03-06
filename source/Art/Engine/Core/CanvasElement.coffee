'use strict';
# This page has a potentially BETTER solution to detecting resizes:
# http://www.backalleycoder.com/2013/03/18/cross-browser-event-based-element-resize-detection/
# require "javascript-detect-element-resize"

# https://developer.mozilla.org/en-US/docs/Web/Reference/Events/mousemove
# http://stackoverflow.com/questions/1685326/responding-to-the-onmousemove-event-outside-of-the-browser-window-in-ie

{
  log, inspect
  nextTick
  currentSecond
  timeout
  durationString
  timeStampToPerformanceSecond
  first
  wordsArray
  select
  merge
  objectDiff
  isPlainObject
  clone
  getEnv
  peek
} = require 'art-standard-lib'

Element = require './Element'
{config} = require '../Config'

{showPartialDrawAreas} = getEnv()
{createWithPostCreate} = require 'art-class-system'
{Bitmap} = require 'art-canvas'

{getOrientationAngle, simpleBrowserInfo} = Browser = require 'art-browser-tools'
HtmlCanvas = Browser.DomElementFactories.Canvas

{
  rgbColor, hslColor, point, Point, rect, Rectangle, matrix, Matrix
} = require 'art-atomic'

{getDevicePixelRatio, domElementOffset} = Browser.Dom
{PointerEventManager, PointerEvent, KeyEvent} = require '../Events'

{globalEpochCycle} = require './GlobalEpochCycle'
{drawEpoch} = (require './Drawing').DrawEpoch

extractPointerEventProps = (domEvent) ->
  {ctrlKey, metaKey, shiftKey, timeStamp} = domEvent
  {ctrlKey, metaKey, shiftKey, time: timeStampToPerformanceSecond timeStamp}

module.exports = createWithPostCreate class CanvasElement extends Element
  @classGetter
    devicePixelsPerPoint: -> getDevicePixelRatio()

  # _updateRegistryFromPendingState OVERIDDEN
  # CanvasElement registry only depends on if they are attached or dettached
  _updateRegistryFromPendingState: -> null

  ###
  IN:
    options:
      for 'real' mode, set one of the following
      for 'test' mode, leave all blank and there will be no HTMLCanvasElement
        canvas:             HTMLCanvasElement instance
        canvasId:           canvas = document.getElementById canvasId
        parentHtmlElement:  parentHtmlElement.appendChild HtmlCanvas(...)

      parentHtmlElement is the preferred option:
        A new HtmlCanvas is generated, and
        it's styles are setup for the best results.
  ###
  constructor: (options = {}) ->
    super

    @_devicePixelsPerPoint = options.pixelsPerPoint ? if options.disableRetina
      1
    else
      getDevicePixelRatio()

    @_domEventListeners = []
    @_drawEpochPreprocessing = []
    @_drawEpochQueued = false

    @_documentToElementMatrix =
    @_elementToDocumentMatrix =
    @_absToDocumentMatrix =
    @_documentToAbsMatrix = null

    @pointerEventManager = new PointerEventManager canvasElement:@

    @_attach @_getOrCreateCanvasElement options

    self.canvasElement ||= @

  @getter "
    documentToElementMatrix
    elementToDocumentMatrix
    absToDocumentMatrix
    documentToAbsMatrix
    "

  _getOrCreateCanvasElement: ({canvas, canvasId, parentHtmlElement, noHtmlCanvasElement}) ->
    unless noHtmlCanvasElement
      @_parentHtmlElement = parentHtmlElement || document.getElementById("artDomConsoleArea") || document.body
      if canvas ||= document.getElementById(canvasId)
        @_parentHtmlElement = canvas.parentElement || @_parentHtmlElement
        canvas
      else
        @_createCanvasElement @_parentHtmlElement

  _createCanvasElement: (parentHtmlElement) ->
    @_createdHtmlCanvasElement = HtmlCanvas
      style: merge @pendingStyle,
        position: "absolute"
        outline: "none"
        top: "0"
        left: "0"
      id: "artCanvas"
    @onNextReady().then =>
      parentHtmlElement.appendChild @_createdHtmlCanvasElement
    @_createdHtmlCanvasElement

  @concreteProperty

    style:
      default: {}
      validate: (v) -> isPlainObject v
      postSetter: (newValue, oldValue, rawNewValue) ->
        # objectDiff (newObj, oldObj, added, removed, changed, noChange, eq = defaultEq, oldObjKeyCount)]
        update = (key, newValue) => @_canvas.style[key] = newValue
        remove = (key) => @_canvas.style[key] = null
        @_canvas && objectDiff newValue, oldValue, update, remove, update


  @virtualProperty
    parentSizeForChildren: (pending) -> @getParentSize pending

    parentSize: (pending) ->
      if @_canvas
        if @_parentHtmlElement && @_parentHtmlElement != global.document.body
          # Even here, shouldn't we just use this inner*?
          #  {innerWidth, innerHeight} = @_parentHtmlElement
          {clientWidth, clientHeight} = @_parentHtmlElement

        {innerWidth, innerHeight} = global
        {width, height} = global.screen

        # Screen sometimes (always?) doesn't take into account rotation.
        # These seems to hold for iOS. How about android?
        if Math.abs(getOrientationAngle()) == 90 && height > width
          [width, height] = [height, width]

        if clientWidth > 0 && clientHeight > 0
          width = clientWidth
          height = clientHeight

        else if innerWidth > 0 && innerHeight > 0
          width = innerWidth
          height = innerHeight

        point width, height

      else point 100

  _domListener: (target, type, listener)->
    target.addEventListener type, listener
    @_domEventListeners.push
      target:target
      type:type
      listener:listener

  # _attach is private and done when the HTMLCanvasElement is set - typically on construction
  detach: ->
    globalEpochCycle.detachCanvasElement @
    if @_createdHtmlCanvasElement
      log "CanvasElement#detach: removing createdHtmlCanvasElement..."
      @_createdHtmlCanvasElement.parentElement?.removeChild @_createdHtmlCanvasElement
      @_createdHtmlCanvasElement = null
      @_canvas = null
      log "CanvasElement#detach: removed createdHtmlCanvasElement."

    @_unregister()

    @_detachDomEventListeners()

  _detachDomEventListeners: ->
    return unless @_eventListenersAttached
    @_eventListenersAttached = false
    for listener in @_domEventListeners
      listener.target.removeEventListener listener.type, listener.listener
    @_domEventListeners = []

  isFocused: (el = @focusedElement) ->
    (!@_canvas || (document.hasFocus() && (document.activeElement == @_canvas || document.activeElement == el?._domElement))) && @pointerEventManager.isFocused el

  # _blur is a noop at the CanvasElement level
  _blur: ->

  _focus: -> @_focusDomElement()

  _focusDomElement: ->
    @_canvas?.focus()

  blur: ->
    @_canvas?.blur()
    @_blur()

  @getter
    focusedElement: -> @pointerEventManager.focusedElement

  blurElement: (el) -> @pointerEventManager.focus null, el?.parent
  focusElement: (el) ->
    @pointerEventManager.focus null, el

  _saveFocus: -> @pointerEventManager.saveFocus()
  _restoreFocus: -> @pointerEventManager.restoreFocus()

  enableFileDrop: ->
    unless window.FileReader
      @log "#{@className}#enableFileDrop failed - browser not supported"
      return false
    @_domListener window, 'dragover',  (domEvent) => @routeFileDropEvent domEvent, 'dragOver'
    @_domListener window, 'dragenter', (domEvent) => @routeFileDropEvent domEvent, 'dragEnter'
    @_domListener window, 'dragleave', (domEvent) => @routeFileDropEvent domEvent, 'dragLeave'
    @_domListener window, 'drop',      (domEvent) => @routeFileDropEvent domEvent, 'drop'

    @log "#{@className}#enableFileDrop enabled"
    true

  routeFileDropEvent: (domEvent, type) ->
    return true if domEvent.dataTransfer.types[0] != "Files"
    domEvent.preventDefault()

    # TODO this isn't currently used anywhere, so I'm not testing it; it won't work; fileDropEvent isn't implemented
    @pointerEventManager.fileDropEvent type,
      locations: [@_domEventLocation domEvent]
      files: domEvent.dataTransfer.files

    false

  # NOTE: For geometry changes, this gets called twice for the same element:
  #   once before and once after it "moves"
  #   As such, if we are invalidating rectangular areas, we need to do it immediately with each call.
  #   Queuing a list of dirty descendants will only give us the final positions, not the before-positions.
  _needsRedrawing: (descendant) ->
    @_addDescendantsDirtyDrawArea descendant

    super
    @queueDrawEpoch()

  _releaseAllCacheBitmaps: ->
    # NOOP

  queueDrawEpoch: ->
    unless @_drawEpochQueued
      @_drawEpochQueued = true
      drawEpoch.queueItem => @processEpoch()

  queueDrawEpochPreprocessor: (f) ->
    @_drawEpochPreprocessing.push f
    @queueDrawEpoch()

  processEpoch: ->
    @_drawEpochQueued = false

    if @_drawEpochPreprocessing.length > 0
      pp = @_drawEpochPreprocessing
      @_drawEpochPreprocessing = []
      f() for f in pp

    @drawOnBitmap()

  @setter
    cssCursor: (cursor) ->
      cursor = null unless cursor?
      if cursor != @_cssCursor
        @_canvas?.style.cursor = cursor
        @_cssCursor = cursor

  @getter
    inspectedObjects: ->
      CanvasElement: {
        @currentSize
        @canvasBitmap
      }

    canvasByteSize: -> @canvasBitmap.byteSize

    htmlCanvasElement: -> @_canvas
    numActivePointers: -> @pointerEventManager.getNumActivePointers()
    focusPath: -> @pointerEventManager.currentFocusPath
    cacheable: -> false
    canvasElement: -> @
    cssCursor: -> @_cssCursor
    windowScrollOffset: -> point window.scrollX, window.scrollY
    geometry: -> {
        @size, @scale,
        @absToElementMatrix,      @elementToAbsMatrix,
        @documentToElementMatrix, @elementToDocumentMatrix
        @documentToAbsMatrix,     @absToDocumentMatrix
        @parentToElementMatrix,   @elementToParentMatrix
      }
    canvasInnerSize: ->
      point(
        if @_fullPageWidth then window.innerWidth else @_canvas.clientWidth
        if @_fullPageHeight then window.innerHeight else @_canvas.clientHeight
      )

  ###############################################
  # INIT and UPDATE
  ###############################################
  _attach: (canvas)->
    globalEpochCycle.attachCanvasElement @
    @onNextReady => @_register()

    @_canvas = canvas

    if canvas
      @_updateCanvasGeometry()

      @_attachDomEventListeners()

  _sizeChanged: (newSize, oldSize) ->
    super
    @_pointSize = newSize
    @_canvas.style.width  = newSize.x + "px"
    @_canvas.style.height = newSize.y + "px"
    @_pixelSize = @_pointSize.mul @_devicePixelsPerPoint
    @_canvas.setAttribute "width",   @_pixelSize.x
    @_canvas.setAttribute "height",  @_pixelSize.y

    @_updateDocumentMatricies()
    @_bitmapFactory = @canvasBitmap = new Bitmap @_canvas, alpha: false
    @queueDrawEpoch()

  _setElementToParentMatrixFromLayoutXY: (x, y) ->
    return if @_locationLayoutDisabled

    e2p = @_getElementToParentMatrixForXY true, x, y, 1

    @_canvas?.style.left = "#{e2p.locationX}px"
    @_canvas?.style.top = "#{e2p.locationY}px"

    e2p = (@_getElementToParentMatrixForXY true, x, y).withLocation 0
    if !@_pendingState._elementToParentMatrix.eq e2p
      @_pendingState._elementToParentMatrix = e2p
      @_elementChanged()


  _updateCanvasGeometry: (retryCount = 3)->
    @_updateDocumentMatricies()
    @_layoutPropertyChanged()
    @_elementChanged()

    # check again when dom is ready, just in case (iOS doesn't update innerHeight immediatly)
    if retryCount > 0
      retryMap =
        1: 1000
        2: 100
        3: 10
      timeout retryMap[retryCount], => @_updateCanvasGeometry retryCount - 1

  _updateDocumentMatricies: ->
    {left, top} = domElementOffset @_canvas
    elementToDocumentMatrix = Matrix.translateXY left, top

    if !elementToDocumentMatrix.eq @_elementToDocumentMatrix

      @_elementToDocumentMatrix = elementToDocumentMatrix
      @_documentToElementMatrix = @_elementToDocumentMatrix.inv

      @_documentToAbsMatrix = @_documentToElementMatrix.scale @_devicePixelsPerPoint
      @_absToDocumentMatrix = @_documentToAbsMatrix.inv

      @_parentToElementMatrix = @_absToElementMatrix = @_absToDocumentMatrix.mul @_documentToElementMatrix
      @_elementToParentMatrix = @_elementToAbsMatrix = @_absToElementMatrix.inv

      @scale = @_devicePixelsPerPoint
      @queueEvent "documentMatriciesChanged"

  ###############################################
  # EVENTS, LISTENERS and POINTERS
  ###############################################

  _domEventLocation: (domEvent) ->
    windowScrollOffset = @getWindowScrollOffset()
    @_documentToAbsMatrix.transformXY(
      domEvent.clientX + windowScrollOffset.x
      domEvent.clientY + windowScrollOffset.y
    )

  _attachResizeListener: ->
    @_domListener window, "resize", (domEvent)=>
      @_updateCanvasGeometry()

      # NOTE: must process immediately to avoid showing a stretched canvas
      globalEpochCycle.processEpoch()

  _attachBlurFocusListeners: ->
    @_domListener @_canvas, "blur", (domEvent) => timeout 100, =>
      unless @isFocused()
        @_saveFocus()
        @blurElement()

    @_domListener @_canvas, "focus", (domEvent) =>
      @_restoreFocus()

  # DOM limitation:
  #   HTMLCanvas mousemove only gets events if the mouse is over the canvas regardless of button status.
  #   "window's" mousemove gets all move events, regardless of button status, INCLUDING events outside
  #     the browser window if buttons were pressed while the cursor was over the browser window.
  # Desired behavior:
  #   a) if a button-press/touch happened in-canvas, we want all move events until all buttons/touches end.
  #   b) if no buttons/touchs are active, we only want move events when the cursor is over the canvas
  # Strategy
  #   listen to canvas mousemove events when no buttons are down
  #   listen to window moustmove events when otherwise
  _attachPointerMoveListeners: ->
    @_domListener @_canvas, "mousemove", (domEvent)=>
      if @numActivePointers == 0
        @mouseMove @_domEventLocation domEvent,
          extractPointerEventProps domEvent

    @_domListener window,  "mousemove", (domEvent)=>
      if @numActivePointers >  0
        @mouseMove @_domEventLocation(domEvent),
          extractPointerEventProps domEvent

  @getter
    numActivePointers: -> @pointerEventManager.numActivePointers
    activePointers: -> @pointerEventManager.activePointers

  mouseDown: (location, props) ->
    @pointerEventManager.mouseMove location, props
    @pointerEventManager.mouseDown location, props

  mouseMove: (location, props) ->
    @pointerEventManager.mouseMove location, props

  mouseUp: (location, props) ->
    @pointerEventManager.mouseMove location, props
    @pointerEventManager.mouseUp props

  mouseWheel: (location, props) ->
    @pointerEventManager.mouseWheel location, props

  touchDown:   (id, location, props) ->
    @pointerEventManager.pointerDown id, location, props

  touchMove:   (id, location, props) ->
    @pointerEventManager.pointerMove id, location, props

  touchUp:     (id, location, props) ->
    @pointerEventManager.pointerMove id, location, props
    @pointerEventManager.pointerUp id, props

  touchCancel: (id, props) ->
    @pointerEventManager.pointerCancel id, props

  capturePointerEvents: (element) ->
    @pointerEventManager.capturePointerEvents element

  pointerEventsCapturedBy: (element) ->
    @pointerEventManager.pointerEventsCapturedBy element

  # DOM limitation:
  #   HTMLCanvas only gets mousedown/up if the mouse is over the canvas
  #   "window's" mousedown/up gets all mouse events
  # Desired behavior:
  #   If mousedown happens on the canvas, we want to get a matching mouseup no matter where the cursor is.
  # Strategy:
  #   Listen to mouseups on window, but ignore any if we didn't get a mousedown on the canvas
  _attachPointerButtonListeners: ->
    @_domListener @_canvas, "mouseover", (domEvent)=>
      @_updateDocumentMatricies()

    @_domListener @_canvas, "mousedown", (domEvent)=>
      @_updateDocumentMatricies()
      @_restoreFocus()
      if domEvent.button == 0
        domEvent.preventDefault()
        @mouseDown @_domEventLocation(domEvent),
          extractPointerEventProps domEvent

    @_domListener window, "mouseup", (domEvent)=>
      if domEvent.button == 0 && @pointerEventManager.getActivePointer "mousePointer"
        domEvent.preventDefault()
        @mouseUp @_domEventLocation(domEvent),
          extractPointerEventProps domEvent

  _handleDomWheelEvent: (domEvent)->
    domEvent.preventDefault()
    @mouseWheel @_domEventLocation(domEvent),
      merge null,
        extractPointerEventProps domEvent
        deltaMode: switch domEvent.deltaMode
          when 0 then "pixel"
          when 1 then "line"
          when 2 then "page"
        select domEvent, "deltaX", "deltaY", "deltaZ"

  _attachPointerWheelListeners: ->
    @_domListener @_canvas, "wheel", (domEvent) => @_handleDomWheelEvent domEvent

  _attachPointerTouchListeners: ->
    @_domListener @_canvas, "touchstart",  (domEvent) =>
      @_updateDocumentMatricies()
      domEvent.preventDefault()
      @_restoreFocus()

      for changedTouch in domEvent.changedTouches
        @touchDown changedTouch.identifier,
          @_domEventLocation changedTouch
          extractPointerEventProps domEvent
      null

    @_domListener @_canvas, "touchmove",   (domEvent) =>
      domEvent.preventDefault()
      @pointerEventManager.startMultitouchMoveEvents()
      for changedTouch in domEvent.changedTouches
        @pointerEventManager.pointerMove changedTouch.identifier,
          @_domEventLocation changedTouch
          extractPointerEventProps domEvent
      @pointerEventManager.endMultitouchMoveEvents()
      null

    @_domListener @_canvas, "touchend",    (domEvent) =>
      domEvent.preventDefault()
      for changedTouch in domEvent.changedTouches
        @touchUp changedTouch.identifier,
          @_domEventLocation changedTouch
          extractPointerEventProps domEvent
      null

    @_domListener @_canvas, "touchcancel", (domEvent) =>
      domEvent.preventDefault()
      for changedTouch in domEvent.changedTouches
        @touchCancel changedTouch.identifier,
          extractPointerEventProps domEvent
      null

    # NOTE: touchleave and touchenter are ignored
    #   Currently, touch events are handled with the assumption that the canvas element is fullscreen, so this definitly can be ignored.
    #   Even if the canvas isn't fullscreen, we want to handle touches like we handle the mouse - if the first one started in the canvas, capture all activity until they are all released, otherwise ignore.
    # @_domListener @_canvas, "touchleave",  (domEvent) =>
    # @_domListener @_canvas, "touchenter",  (domEvent) =>

  queueKeyEvents: (type, keyboardEvent) ->
    @pointerEventManager.queueKeyEvents type, keyboardEvent

  keyDownEvent: (keyboardEvent) ->
    @queueKeyEvents "keyDown",  keyboardEvent
    @queueKeyEvents "keyPress", keyboardEvent

  keyUpEvent: (keyboardEvent) ->
    @queueKeyEvents "keyUp",    keyboardEvent

  _attachKeypressListeners: ->
    @_domListener @_canvas, "keydown", (keyboardEvent) =>
      @keyDownEvent keyboardEvent

      # HACK
      # Our event handlers don't happen immeidately. They are queued.
      # Therefor, they cannot call preventDefault to prevent the default action of the browser.
      # I think ultimately we need a way to ask the focused elements if they consume the key.
      # If so, we call preventDefault.
      if keyboardEvent.key == "Backspace"
        keyboardEvent.preventDefault()

    @_domListener @_canvas, "keyup", (keyboardEvent) =>
      @keyUpEvent keyboardEvent

  _enableHtmlFocusOnCanvas: ->
    unless simpleBrowserInfo.touch
      @_canvas.tabIndex = "-1"
      @_canvas.contentEditable = true

  _attachDomEventListeners: ->
    return if @_eventListenersAttached
    @_eventListenersAttached = true
    @_enableHtmlFocusOnCanvas()
    @_attachBlurFocusListeners()
    @_attachPointerMoveListeners()
    @_attachPointerTouchListeners()
    @_attachPointerButtonListeners()
    @_attachPointerWheelListeners()
    @_attachResizeListener()
    @_attachKeypressListeners()

  ###############################################
  # DRAWING and DRAW STATS
  ###############################################

  getShowPartialDrawAreas = -> showPartialDrawAreas || config.showPartialDrawAreas
  partialRedrawCount = 0
  drawOnBitmap: ->

    Element.resetStats()

    if @canvasBitmap
      if config.partialRedrawEnabled && @_dirtyDrawAreas
        for dirtyDrawArea in @_dirtyDrawAreas
          lastClippingInfo = @canvasBitmap.openClipping dirtyDrawArea.mul @_devicePixelsPerPoint
          super @canvasBitmap, @elementToParentMatrix
          @canvasBitmap.closeClipping lastClippingInfo
      else
        super @canvasBitmap, @elementToParentMatrix

    if getShowPartialDrawAreas()
      @_drawPartialDrawAreas()

    @_redrawAll = false
    @_dirtyDrawAreas = null

  _drawPartialDrawAreas: ->

    spda = getShowPartialDrawAreas()
    for dirtyDrawArea in @_dirtyDrawAreas || [@drawArea]
      partialRedrawCount++
      spdaFull = spda == "full"
      spdaApts = color: hslColor (partialRedrawCount % 36) / 36, 1,
        if spdaFull then 1 else .8,
        if spdaFull then 1/3 else 1

      spdaArea = (dirtyDrawArea.mul @_devicePixelsPerPoint)

      if spda == "log"
        log "#{dirtyDrawArea.toString()} (#{dirtyDrawArea.area} pixels)"

      if spdaFull
        @canvasBitmap?.drawRectangle null, spdaArea, spdaApts
      else
        @canvasBitmap?.drawBorder null, spdaArea, spdaApts
