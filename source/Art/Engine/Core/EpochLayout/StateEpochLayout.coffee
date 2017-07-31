ArtEngineCore = require '../namespace'
CoreLayout = require './namespace'

FlexLayout = require './FlexLayout'
LayoutTools = require './LayoutTools'

###
TODO:

  I'd like to move away from my isInfiniteResult tests.
  I'd rather just use circular tests.
  The problem is if we have a "max" test in layout, infinite results get masked and appear finite.
  Circular tests are not 100% reliable though!
    Perhaps we can let you specific relitivity in the PointLayout Props, if needed:
      w: (ps, cs) -> blah
      parentRelative: false # blah isn't actually parent relative
###

{layoutChildrenFlex} = FlexLayout
{
  nearInfiniteSize, nearInfinity, nearInfinityResult
  layoutMargin
  sizeWithPadding
  layoutPadding
  deinfinitize
  isInfiniteResult
} = LayoutTools

{point, Point, perimeter} = require 'art-atomic'
{

  log, max, min
  shallowEq
  longestCommonSubsequence, select, Unique, peek, inspect, isFunction,
  eachRunAsCharCodes
  floatEq
  isNumber
} = require 'art-standard-lib'
{BaseObject} = require 'art-class-system'

{point0} = Point
{abs} = Math

getGlobalEpochCycle = ->
  ArtEngineCore.GlobalEpochCycle.globalEpochCycle

module.exports = class StateEpochLayout extends BaseObject

  @markLayoutPropertiesChanged: (changingElements) =>

    for element in changingElements
      if (
        (element.getParentChanged() && element.getPendingParent()) ||
        (element.getChildrenChanged() && element.getPendingLayoutMovesChildren())
      )
        unless element.__layoutPropertiesChanged
          element.__layoutPropertiesChanged = true
          element._elementChanged()

      markParentLayoutPropertiesChanged element

  @updateLayouts: (layoutChangedElements) =>
    process = =>

      # @_elementsLayedOut = {}

      for element in layoutChangedElements when element.__layoutPropertiesChanged
        layoutElement element, element.getPendingParentSizeForChildren()

      # apply layouts for sortedLayoutDirtyElements
      # if a layout changes the element's size, recurse on children.
      # We need to process all "parent" layouts before "child" layouts,
      # so sortedLayoutDirtyElements is sorted by depth ascending.
    if getGlobalEpochCycle() # loaded
      getGlobalEpochCycle().timePerformance "aimLayout", process
    else
      process()
    null

  ####################
  # PRIVATE
  ####################
  markParentLayoutPropertiesChanged = (element) ->
    while (element = element.getPendingParent()) && (
        element.getPendingSize().getChildrenRelative() ||
        element.getPendingLayoutMovesChildren()
      ) && !element.__layoutPropertiesChanged
      element.__layoutPropertiesChanged = true
      element._elementChanged()


  layoutChildrenComputeMaxSize = (parentSize, children) ->
    childrenHeight = 0
    childrenWidth  = 0

    for child in children when children
      size = layoutElement child, parentSize
      childrenWidth  = max childrenWidth,  size.x
      childrenHeight = max childrenHeight, size.y

    point childrenWidth, childrenHeight

  layoutChildren = (
    element
    currentPadding
    parentSize
    children
    secondPassChildren
    secondPassLocation
  ) ->
    return point0 unless children
    maxXInfinite = maxYInfinite = false

    for child in children

      if child.getPendingLayoutSizeParentCircular()
        ###
        If size is circular:
          - this element is automatically not "inFlow"
          - this element is not included in child-size calcs
          - this element is only laid out after the parent-size is final.
        ###
        secondPassChildren.push child
      else
        ###
        If location is circular (but size is not):
          - this element's location is assumed to be point0 for child-size calc purposes
          - this element's location layout is done in the second pass.
        ###

        if layoutLocationInSecondPass = child.getPendingLayoutLocationParentCircular()
          child._setElementToParentMatrixFromLayout point0, parentSize
          secondPassLocation.push child

        layoutElement child, parentSize, layoutLocationInSecondPass

        maxXInfinite = isInfiniteResult child.getPendingMaxXInParentSpace()
        maxYInfinite = isInfiniteResult child.getPendingMaxYInParentSpace()

        if maxXInfinite || maxYInfinite
          secondPassChildren.push child
        else if layoutLocationInSecondPass
          secondPassLocation.push child

  computeChildrenSizeWithPadding = (
    element
    children
    currentPadding
  ) ->
    return point0 unless children?.length > 0

    tMin = lMin = bMax = rMax = 0
    l = r = t = b = 0
    tFirst = lFirst = bFirst = rFirst = true

    if customComputeChildArea = element.getPendingChildArea()
      for child in children when !child.getPendingLayoutSizeParentCircular()

        area = customComputeChildArea child
        l = area.getLeft()
        t = area.getTop()
        r = area.getRight()
        b = area.getBottom()

        lMin = min l, if lFirst then lFirst = false; l else lMin unless isInfiniteResult l
        tMin = min t, if tFirst then tFirst = false; t else tMin unless isInfiniteResult t
        rMax = max r, if rFirst then rFirst = false; r else rMax unless isInfiniteResult r
        bMax = max b, if bFirst then bFirst = false; b else bMax unless isInfiniteResult b

    else
      for child in children when !child.getPendingLayoutSizeParentCircular()

        r = child.getPendingMaxXInParentSpace()
        b = child.getPendingMaxYInParentSpace()

        rMax = max r, if rFirst then rFirst = false; r else rMax unless isInfiniteResult r
        bMax = max b, if bFirst then bFirst = false; b else bMax unless isInfiniteResult b

    sizeWithPadding (rMax - lMin), (bMax - tMin), currentPadding

  layoutChildrenFlowLine = (children, rightEdge, state) ->
    {y, firstChildOnLine, lastLineMarginBottom, maxWidth} = state

    childrenLength = children.length

    # compute lastChildOnLine, lineHeight and maxLineMarginBottom
    maxLineMarginBottom = 0
    maxLineMarginTop = 0
    lineHeight = 0
    lastMarginRight = 0
    lastChildOnLine = firstChildOnLine
    x = 0
    for childI in [firstChildOnLine...childrenLength] by 1
      lastChildOnLine = childI
      child = children[lastChildOnLine]

      currentMargin = child.getPendingCurrentMargin()
      childSize = child.getPendingCurrentSize()
      x += max currentMargin.left, lastMarginRight unless lastChildOnLine == firstChildOnLine
      x += childSize.x
      lastMarginRight = currentMargin.right

      lineFull = x >= rightEdge

      # size-parent-circular, width-parent-relative children get the whole line to themselves
      if child.getPendingLayoutSizeParentCircular() && child.getPendingSize().getXParentRelative()
        unless lastChildOnLine == firstChildOnLine
          lastChildOnLine--
        lineFull = true

      if !lineFull || lastChildOnLine == firstChildOnLine
        # include child in line
        maxLineMarginTop = max currentMargin.top, maxLineMarginTop
        maxLineMarginBottom = max currentMargin.bottom, maxLineMarginBottom
        lineHeight = max lineHeight, childSize.y

        break if lineFull
      else
        # don't include child on line, line is done
        lastChildOnLine--
        break

    # _setElementToParentMatrixFromLayout on  all children from firstChildOnLine to lastChildOnLine
    y += max lastLineMarginBottom, maxLineMarginTop if lastLineMarginBottom?
    x = 0
    lastMarginRight = 0

    # NOTE: most of the loop below is just recomputing X.
    #   Recomputing X is probably better than the current alternatives which all
    #   create more objects. We avoid that to reduce GC pauses.
    #   However, if we could just set the element's x and y separatly without creating objects...
    #     (i.e. if x and y were separate properties of the element)
    for childI in [firstChildOnLine..lastChildOnLine] by 1
      child = children[childI]

      currentMargin = child.getPendingCurrentMargin()
      childSize = child.getPendingCurrentSize()

      x += max currentMargin.left, lastMarginRight unless childI == firstChildOnLine

      child._setElementToParentMatrixFromLayout point(x, y), point childSize.x, lineHeight
      x += childSize.x
      lastMarginRight = currentMargin.right

    if state.flowChildren
      state.firstChildIndexOfEachLine.push firstChildOnLine
      state.lastChildIndexOfEachLine.push lastChildOnLine
      state.widthOfEachLine.push x

    state.lastLineMarginBottom = maxLineMarginBottom
    state.y = y + lineHeight
    state.firstChildOnLine = lastChildOnLine + 1
    state.maxWidth = max maxWidth, x

  subLayoutChildrenAndGatherInformation = (parentSize, children, secondPassSizeLayoutChildren) ->
    for child in children
      if child.getPendingLayoutSizeParentCircular()
        child._setSizeFromLayout child._layoutSize point0, point0
        secondPassSizeLayoutChildren.push child
      else
        layoutElement child, parentSize, true

  layoutChildrenFlow = (
      element,
      currentPadding,
      firstPassSizeForChildrenUnconstrained,
      firstPassSizeForChildrenConstrained,
      children,
      secondPassSizeLayoutChildren
    ) ->

    subLayoutChildrenAndGatherInformation firstPassSizeForChildrenConstrained, children, secondPassSizeLayoutChildren

    # flow children
    halfPixel = .5 # TODO: should this should take into account pixelsPerPoint? Or is it just a layout thing and this should be halfPoint - and always .5?
    rightEdge = firstPassSizeForChildrenUnconstrained.x + halfPixel

    # log layoutChildrenFlow:
    #   firstPassSizeForChildrenUnconstrained: firstPassSizeForChildrenUnconstrained
    #   firstPassSizeForChildrenConstrained: firstPassSizeForChildrenConstrained
    #   rightEdge: rightEdge

    state =
      y: 0
      firstChildOnLine: 0
      lastLineMarginBottom: null
      maxWidth: 0

    childrenAlignment = element.getPendingChildrenAlignment()
    if !floatEq(childrenAlignment.x, 0) || !floatEq(childrenAlignment.y, 0)

      state.childrenAlignment = childrenAlignment
      state.flowChildren = children
      state.firstChildIndexOfEachLine = []
      state.lastChildIndexOfEachLine = []
      state.widthOfEachLine = []

    childrenLength = children.length
    while state.firstChildOnLine < childrenLength
      layoutChildrenFlowLine(
        children
        rightEdge
        state
      )

    state.childrenSize = sizeWithPadding state.maxWidth, state.y, currentPadding
    state

  isSpace = (charCode) -> charCode == 32

  # NOTE: grid layout determines an area dedicated to each element.
  #   This area is passed to the element as-if it was the parent's full children-area
  #   The child can layout its location and size within this area.
  #   Ex: The default propertires for location: 0 and size: ps:1 will result an element perfectly
  #     filling the allocated area.
  #   Ex: You could choose a fixed size and center the element in the grid-laid out area:
  #     location: ps: .5
  #     axis: .5
  #     size: 25
  #   Ex: Define a 3-slot grid with 2 gridlines and center the two children on those grid-lines:
  #     new Element
  #       childrenLayout: "row"
  #       childrenGrid: " ab"
  #       new Element axis: "topCenter"
  #       new Element axis: "topCenter"
  layoutChildrenRowGrid = (isRowLayout, element, gridString, currentPadding, parentSize, children, secondPassSizeLayoutChildren) ->
    # TODO: distribute rounding error among the spaces, if there are spaces.
    # TODO: do we need to do anything special for circular layout items?

    gridCount = gridString.length
    lowerCaseACode = 97

    gridStep = (if isRowLayout then parentSize.x else parentSize.y) / gridCount

    maxCrossSize = offset = 0
    eachRunAsCharCodes gridString.toLowerCase(), (charCode, count) ->
      gridSize = count * gridStep
      if child = children[charCode - lowerCaseACode]
        adjustedParentSize = if isRowLayout
          parentSize.withX gridSize
        else
          parentSize.withY gridSize
        layoutElement child, adjustedParentSize, true

        locationX = child._layoutLocationX adjustedParentSize
        locationY = child._layoutLocationY adjustedParentSize

        maxCrossSize = max maxCrossSize, if isRowLayout
          child._setElementToParentMatrixFromLayoutXY offset + locationX, locationY, parentSize
          child.getPendingCurrentSize().y
        else
          child._setElementToParentMatrixFromLayoutXY locationX, offset + locationY, parentSize
          child.getPendingCurrentSize().x

      offset += gridSize

    childrenSize:
      sizeWithPadding offset, maxCrossSize, currentPadding

  alignChildren = (state, parentSize, childrenSize) ->
    {childrenAlignment, flowChildren, firstChildIndexOfEachLine, lastChildIndexOfEachLine, widthOfEachLine, widthOfEachLineFunction} = state
    widthOfEachLineFunction ||= (i) -> widthOfEachLine[i]

    childrenAlignmentX = childrenAlignment.x
    childrenAlignmentY = childrenAlignment.y

    for firstIndex, i in firstChildIndexOfEachLine
      lastIndex = lastChildIndexOfEachLine[i]
      width = widthOfEachLineFunction i
      firstChildOnLine = flowChildren[firstIndex]

      if firstChildOnLine.getPendingLayoutSizeParentCircular() && firstChildOnLine.getPendingSize().getXParentRelative()
        width = firstChildOnLine.getPendingCurrentSize().x
      offsetX = (parentSize.x - width) * childrenAlignmentX
      offsetY = (parentSize.y - childrenSize.y) * childrenAlignmentY

      if !floatEq(offsetX, 0) || !floatEq(offsetY, 0)
        for j in [firstIndex..lastIndex] by 1
          child = flowChildren[j]
          l = child.getPendingCurrentLocation()
          child._setElementToParentMatrixFromLayoutXY l.x + offsetX, l.y + offsetY, parentSize

  LayoutTools.layoutElement = CoreLayout.layoutElement = layoutElement = (element, parentSize, skipLocation) =>
    # Don't layout more than we need to
    # key = element.getObjectId() #element.inspectedName - inspectedName is really slow. getObjectId is OK


    ###
    TODO - increase effieciency
    Currently, we will always recurse all the way down any children
    which are children-size-relative regardless on if they (or one of their
    decendents) is actually parent-relative.

    Sometimes this is right (see the children relative middlemen tests).
    Often, though, the children really are 100% child-size-relative and 100% ignore
    parent's size.

    In that case, we shouldn't re-lay them out.

    Is there any way to be smart about that?

    Obviously we can let the app dev specify an element is 100% child-size relative in some way.
      Element ignoreParentSize: true

    But that's ugly!
    ###
    return element.getPendingCurrentSize() unless (
      element.__layoutPropertiesChanged ||
      !shallowEq element._lastParentSize, parentSize
    )

    # Mark this element "laid out"
    element._lastParentSize = parentSize
    element.__layoutPropertiesChanged = false

    ##############################
    # Gather Information
    ##############################
    # Compute firstPassSize and finalLocation
    finalLocation = element._layoutLocation parentSize unless skipLocation
    firstPassSize = element._layoutSize parentSize, nearInfiniteSize
    currentPadding = layoutPadding element, parentSize
    currentMargin  = layoutMargin element, parentSize
    firstPassSizeForChildrenUnconstrained = element._sizeForChildren firstPassSize
    firstPassSizeForChildrenConstrained = element._sizeForChildren element._layoutSizeForChildren parentSize, nearInfiniteSize

    # Partition children into firstPassChildren and secondPassChildren
    pendingChildren = element.getPendingChildren()
    firstPassChildren = secondPassChildren = null
    childrenLayout = element.getPendingChildrenLayout()
    layoutIsChildrenRelative = element.getPendingSize().getChildrenRelative()

    #####################################
    # Assign Children to Layout Passes
    #####################################
    if childrenLayout || layoutIsChildrenRelative
      firstPassChildren = pendingChildren

      # split pendingChildren into firstPass and secondPass based on:
      #   inFlow: true  -> firstPass
      #   inFlow: false -> secondPass
      # And do it smart - don't create new arrays if all children are inFlow, the default.
      for child, childI in pendingChildren
        if child.getPendingInFlow()
          firstPassChildren.push child if secondPassChildren
        else
          unless secondPassChildren
            firstPassChildren = pendingChildren.slice 0, childI
            secondPassChildren = []
          secondPassChildren.push child

      secondPassSizeLayoutChildren = []
      secondPassLocationLayoutChildren = []
      secondPassChildren ||= []
    else
      secondPassChildren = pendingChildren


    #####################################
    # non Children Layout First Pass
    #####################################
    childrenSize = if element.nonChildrenLayoutFirstPass
      childrenSize = currentPadding.addedToSize element.nonChildrenLayoutFirstPass(
        firstPassSizeForChildrenConstrained
        firstPassSizeForChildrenUnconstrained
      )
    else point0


    #####################################
    # Children First-Pass
    #####################################
    if firstPassChildren

      switch childrenLayout
        when "flow"
          childrenFlowState = layoutChildrenFlow(
            element
            currentPadding
            firstPassSizeForChildrenUnconstrained
            firstPassSizeForChildrenConstrained
            firstPassChildren
            secondPassSizeLayoutChildren
          )
          childrenFlowState.childrenSize
        when "column"
          childrenFlowState = if childrenGrid = element.getPendingChildrenGrid()
            layoutChildrenRowGrid(
              false
              element
              childrenGrid
              currentPadding
              firstPassSizeForChildrenConstrained
              firstPassChildren
              secondPassSizeLayoutChildren
            )
          else
            layoutChildrenFlex(
              false
              element
              currentPadding
              firstPassSizeForChildrenConstrained
              firstPassChildren
              parentSize
            )
          childrenFlowState.childrenSize
        when "row"
          childrenFlowState = if childrenGrid = element.getPendingChildrenGrid()
            layoutChildrenRowGrid(
              true
              element
              childrenGrid
              currentPadding
              firstPassSizeForChildrenConstrained
              firstPassChildren
              secondPassSizeLayoutChildren
            )
          else
            layoutChildrenFlex(
              true
              element
              currentPadding
              firstPassSizeForChildrenConstrained
              firstPassChildren
              parentSize
            )
          childrenFlowState.childrenSize
        else
          layoutChildren(
            element
            currentPadding
            firstPassSizeForChildrenConstrained
            firstPassChildren
            secondPassChildren
            secondPassLocationLayoutChildren
          )

      # if layoutIsChildrenRelative
      if layoutIsChildrenRelative || childrenFlowState?.childrenAlignment
        childrenSize = childrenSize.max computeChildrenSizeWithPadding element, firstPassChildren, currentPadding

      # compute final size
      finalSize = element._layoutSize parentSize, childrenSize
      finalSizeForChildren = element._sizeForChildren finalSize

      # finalize layout except location as needed
      if secondPassSizeLayoutChildren
        for child in secondPassSizeLayoutChildren
          layoutElement child, finalSizeForChildren, true

      # finalize locations as needed
      if secondPassLocationLayoutChildren
        for child in secondPassLocationLayoutChildren
          child._setElementToParentMatrixFromLayout child._layoutLocation(finalSizeForChildren), parentSize

      # Align Children
      if childrenFlowState?.childrenAlignment
        alignChildren childrenFlowState, finalSizeForChildren, childrenSize
    else
      finalSize = firstPassSize
      finalSizeForChildren = firstPassSizeForChildrenConstrained

    #####################################
    # Non-Children Final-Pass
    #####################################
    element.nonChildrenLayoutFinalPass? finalSizeForChildren

    #####################################
    # Children Final-Pass
    #####################################
    layoutElement child, finalSizeForChildren for child in secondPassChildren if secondPassChildren

    #####################################
    # Final Layout
    #####################################
    # store the final location and size, returning finalSize
    element._setSizeFromLayout     deinfinitize finalSize
    element._setElementToParentMatrixFromLayout deinfinitize(finalLocation), parentSize unless skipLocation

    finalSize

