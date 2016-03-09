Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
{Elements} = require 'art-engine'
Helper = require '../helper'
StateEpochTestHelper = require '../../core/state_epoch_test_helper'

{inspect, log, min, isNumber} = Foundation
{point, matrix, Matrix, Point, rect} = Atomic
{Element, Rectangle, Fill, TextElement, Shapes} = Elements
{drawTest, drawTest2, drawTest3} =  Helper
{pow} = Math

{stateEpochTest} = StateEpochTestHelper

layoutFragmentTester = (element, result) ->
  for areaPart, correctValues of result
    values = for {alignedLayoutArea} in element._textLayout.fragments
      Math.round alignedLayoutArea[areaPart]
    assert.eq values, correctValues, "testing: element._textLayout.fragments.alignedLayoutArea.#{areaPart}"

roundedEq = (testValue, correctValue, note) ->
  if (testValue instanceof Atomic.Rectangle) || (testValue instanceof Point)
    testValue = testValue.rounded
  else if isNumber testValue
    Math.round testValue
  assert.eq testValue, correctValue, note

layoutTester = (element, tests) ->
  {fragments} = tests
  fragments && layoutFragmentTester element, fragments
  if tests.element
    for k, correctValue of tests.element
      testValue = element[k]
      roundedEq  testValue, correctValue, "testing: element.#{k}"
  for k, correctValue of tests when k != "fragments" && k != "element"
    testValue = element._textLayout[k]
    roundedEq testValue, correctValue, "testing: element._textLayout.#{k}"

suite "Art.Engine.Elements.Shapes.TextElement.basic", ->
  stateEpochTest "Layout basic", ->
    textElement = new TextElement text:"foo"
    ->
      assert.eq textElement.currentSize.rounded, point 21, 12
      textElement.setText "foobar"
      ->
        assert.eq textElement.currentSize.rounded, point 42, 12

  stateEpochTest "Layout textualBaseline", ->
    textElement = new TextElement text:"foo", layoutMode: "textualBaseline"
    ->
      assert.eq textElement.currentSize.rounded, point 21, 12
      textElement.setText "foobar"
      ->
        assert.eq textElement.currentSize.rounded, point 42, 12

  stateEpochTest "Layout with axis: .5 (basic)", ->
    textElement = new TextElement text:"foo", axis: .5, location: 123
    ->
      assert.eq textElement.currentLocation, point 123, 123
      textElement.setText "foobar"
      ->
        assert.eq textElement.currentLocation, point 123, 123

  stateEpochTest "Layout with axis: .5, location: ps:.5", ->
    new Element size: 246,
      textElement = new TextElement text:"foo", axis: .5, location: ps:.5
    ->
      assert.eq textElement.currentLocation, point 123, 123
      assert.eq textElement.currentSize.rounded, point 21, 12
      textElement.setText "foobar"
      ->
        assert.eq textElement.currentLocation, point 123, 123
        assert.eq textElement.currentSize.rounded, point 42, 12

  drawTest3 "TEXT layoutMode: textual",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new TextElement
        color:"red", text:"Thing()", fontSize:48
        new Rectangle color: "#0003"
        new Fill()

  drawTest3 "layoutMode: textualBaseline",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new TextElement
        color:"red"
        text:"Thing()\nThang"
        fontSize:48
        layoutMode: "textualBaseline"
        new Rectangle color: "#0003"
        new Fill()

  drawTest3 "layoutMode: textualBaseline with word-wrap",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new TextElement
        size:
          w: (ps, cs) -> min 100, cs.w
          hch:1
        color:"red"
        text:"I am a dog."
        fontSize:32
        layoutMode: "textualBaseline"
        new Rectangle color: "#0003"
        new Fill()

  drawTest3 "tight layoutMode",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new Element
        size: cs:1
        new Rectangle color:"#ff7"
        new TextElement text:"test", layoutMode:"tight", fontSize:50
    test: (element) ->
      assert.eq element.currentSize, point 68, 29

  drawTest3 "compositeMode",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new Element {},
        new Rectangle size:point(40, 60), color:"red"
        new Rectangle size:point(40, 60), location:point(40,0), color:"blue"
        new TextElement color:"#0f0", fontSize:50, text:"test", compositeMode:"add"

  drawTest3 "opacity",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new TextElement color:"red", fontSize:50, text:"test", opacity:.5

  drawTest3 "all options",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new TextElement
        color:      "green"
        text:       "Dude!"
        fontSize:   40
        fontFamily: "Times New Roman"
        fontWeight: "bold"
        fontStyle: "italic"
        fontVariant:"small-caps"
        layoutMode: "tight"
        align:      "center"

  drawTest3 "children",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new TextElement color:"red", fontSize:50, text:"test",
        new Fill
        new Rectangle
          color:"#70F7"
          axis:point(.5)
          location: ps: .5
          size: w:60, h:60
          angle: Math.PI * .3

  drawTest3 "children with mask",
    stagingBitmapsCreateShouldBe: 2
    element: ->
      new TextElement color:"red", fontSize:50, text:"test",
        new Rectangle
          color:"#F0F"
          axis: .5
          location: ps: .5
          size: w:60, h:60
          angle: Math.PI * .3
        new Fill isMask:true

  drawTest3 "basic",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new Element
        size: w:100, hch:1
        new Rectangle color: "#fcc"
        new TextElement color:"red", text:"That darn quick, brown fox. He always gets away!", fontSize:16, size: wpw:1

  drawTest3 "centered-aligned",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new Element
        size: w:100, hch:1
        new Rectangle color: "#fcc"
        new TextElement color:"red", text:"That!", fontSize:16, align: "center", size: wpw:1

  drawTest3 "right-aligned",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new Element
        size: w:100, hch:1
        new Rectangle color: "#fcc"
        new TextElement color:"red", text:"That!", fontSize:16, align: "right", size: wpw:1

  test "flow two paragraphTexts", ->
    e = new Element
      size: w:200, hch:1
      childrenLayout: "flow"
      e1 = new TextElement color:"red", text:"This is going to be great, don't you think?", fontSize:32
      e2 = new TextElement color:"red", text:"-------", fontSize:32
    e1.onNextReady()
    .then ->
      e.toBitmap {}
    .then (bitmap) ->
      log bitmap
      assert.neq e1.currentLocation, e2.currentLocation

  test "drawArea", ->
    el = new TextElement text:"hi", fontSize:16, align: "center", size: w:300
    el.onNextReady ->
      assert.within el.elementSpaceDrawArea.right, 150, 300

  test "drawArea width wordWrap", (done)->
    el =
      new Element
        size: w:100, hch:1
        new TextElement
          text:"The quick brown fox jumped over the lazy dog."
          size: wpw:1, hch:1
    el.onNextReady ->
      log el.elementSpaceDrawArea
      el.logBitmap()
      assert.within el.elementSpaceDrawArea.width, 90, 100
      assert.within el.elementSpaceDrawArea.height, 85, 100
      done()

suite "Art.Engine.Elements.Shapes.TextElement.as shape", ->
  drawTest3 "gradient",
    element: ->
      new TextElement
        colors: ["red", "yellow"]
        text: "Red-yellow gradient."
        fontSize: 32

  drawTest3 "shadow",
    element: ->
      new TextElement
        color: "red"
        shadow: offsetY: 2, blur: 2, color: "#0005"
        text: "Shadow"
        fontSize: 32

suite "Art.Engine.Elements.Shapes.TextElement.alignment", ->
    suite "multi-line, layoutMode: textual", ->

      suite "layout ps:1", ->
        leftAligned     = [0,   0,    0,    0   ]
        topAligned      = [0,   20,   40,   60  ]
        rightAligned    = [100, 100,  100,  100 ]
        bottomAligned   = [40,  60,   80,   100 ]
        hCenterAligned  = [50,  50,   50,   50  ]
        vCenterAligned  = [20,  40,   60,   80  ]
        for value, result of {
            top:
              area:      rect 0, 0, 82, 72
              drawArea:  rect -8, -8, 97, 91
              element:
                logicalArea:            rect 0, 0, 100, 100
                elementSpaceDrawArea:   rect -8, -8, 97, 91
              fragments:             top:      topAligned,     left:     leftAligned
            left:         fragments: top:      topAligned,     left:     leftAligned
            center:       fragments: top:      topAligned,     hCenter:  hCenterAligned
            right:        fragments: top:      topAligned,     right:    rightAligned
            bottom:       fragments: bottom:   bottomAligned,  left:     leftAligned
            topLeft:      fragments: top:      topAligned,     left:     leftAligned
            topCenter:    fragments: top:      topAligned,     hCenter:  hCenterAligned
            topRight:     fragments: top:      topAligned,     right:    rightAligned
            centerLeft:   fragments: vCenter:  vCenterAligned, left:     leftAligned
            centerCenter:
              area:      rect 0, 0, 82, 72
              drawArea:  rect 1, 6, 97, 91
              fragments:             vCenter:  vCenterAligned, hCenter:  hCenterAligned
            centerRight:  fragments: vCenter:  vCenterAligned, right:    rightAligned
            bottomLeft:   fragments: bottom:   bottomAligned,  left:     leftAligned
            bottomCenter: fragments: bottom:   bottomAligned,  hCenter:  hCenterAligned
            bottomRight:
              area:      rect 0, 0, 82, 72
              drawArea:  rect 10, 20, 97, 91
              fragments:             bottom:   bottomAligned,  right:    rightAligned
            }
          do (value, result) =>
            drawTest3 "align: '#{value}'",
              stagingBitmapsCreateShouldBe: 0
              element: ->
                new TextElement
                  size: ps: 1
                  align: value
                  color:"red", text:"The quick brown fox jumped over the lazy dog.", fontSize:16
              test: (element) -> layoutTester element, result

      suite "drawAreas, Fill and size: w:200, hch:1", ->
        for value, result of {
            top:
              area:      rect 0, 0, 135, 52
              drawArea:  rect -8, -8, 150, 71
              element:
                logicalArea:            rect -20, -10, 200, 72
                paddedArea:             rect 0, 0, 160, 52
                elementSpaceDrawArea:   rect -8, -8, 150, 71
            }
          do (value, result) =>
            drawTest3 "align: '#{value}'",
              stagingBitmapsCreateShouldBe: 0
              element: ->
                new TextElement
                  size: w:200, hch:1
                  padding: h:20, v:10
                  align: value
                  color:"red"
                  text:"The quick brown fox jumped over the lazy dog."
                  # fontSize:16
                  new Fill() # IMPORTANT FOR THIS TEST - DONT REMOVE
              test: (element) -> layoutTester element, result

      suite "width change in second layout pass should update alignments", ->
        for align, result of {
            right:
              fragments: width: [112], left:[0]
            }
          do (align, result) =>
            drawTest3 "align: '#{align}'",
              stagingBitmapsCreateShouldBe: 0
              element: ->
                new Element
                  size: w:150, hch: 1
                  new TextElement
                    fontSize: 17.5
                    fontFamily: "'HelveticaNeue-Light', sans-serif"
                    color: "red"
                    size: cs: 1, max: ww: 1
                    text: "MMMM! Rajas!"
                    align: align
                    padding: bottom: 9
                    leading: 1.1
                    new Rectangle color: "#0002"
                    new Fill

              test: (element) -> layoutTester element.children[0], result

      suite "layout ww:.5, hh:1", ->
        leftAligned     = [0,   0,    0,    0,    0]
        topAligned      = [0,   20,   40,   60,   80]
        rightAligned    = [50,  50,   50,   50,   50]
        bottomAligned   = [20,  40,   60,   80,   100]
        hCenterAligned  = [25,  25,   25,   25,   25]
        vCenterAligned  = [10,  30,   50,   70,   90]
        for value, result of {
            top:          top:      topAligned,     left:     leftAligned
            left:         top:      topAligned,     left:     leftAligned
            center:       top:      topAligned,     hCenter:  hCenterAligned
            right:        top:      topAligned,     right:    rightAligned
            bottom:       bottom:   bottomAligned,  left:     leftAligned
            topLeft:      top:      topAligned,     left:     leftAligned
            topCenter:    top:      topAligned,     hCenter:  hCenterAligned
            topRight:     top:      topAligned,     right:    rightAligned
            centerLeft:   vCenter:  vCenterAligned, left:     leftAligned
            centerCenter: vCenter:  vCenterAligned, hCenter:  hCenterAligned
            centerRight:  vCenter:  vCenterAligned, right:    rightAligned
            bottomLeft:   bottom:   bottomAligned,  left:     leftAligned
            bottomCenter: bottom:   bottomAligned,  hCenter:  hCenterAligned
            bottomRight:  bottom:   bottomAligned,  right:    rightAligned
            }
          do (value, result) =>
            drawTest3 "align: '#{value}'",
              stagingBitmapsCreateShouldBe: 0
              element: ->
                new TextElement
                  size: ww:.5, hh:1
                  align: value
                  color:"red", text:"The quick brown fox jumped over the lazy dog.", fontSize:16
                  new Rectangle color: "#0002"
                  new Fill()
              test: (element) -> layoutFragmentTester element, result

      suite "layout ww:1, hch:1", ->
        leftAligned     = [0,   0,    0,    0   ]
        rightAligned    = [100, 100,  100,  100 ]
        hCenterAligned  = [50,  50,   50,   50  ]
        topAligned      = [0,   20,   40,   60  ]
        for value, result of {
            top:          top:  topAligned, left:     leftAligned
            centerCenter: top:  topAligned, hCenter:  hCenterAligned
            bottomRight:  top:  topAligned, right:    rightAligned
            }
          do (value, result) =>
            drawTest3 "align: '#{value}'",
              stagingBitmapsCreateShouldBe: 0
              element: ->
                new TextElement
                  size: ww:1, hch:1
                  align: value
                  color:"red", text:"The quick brown fox jumped over the lazy dog.", fontSize:16
                  new Rectangle color: "#0002"
                  new Fill()
              test: (element) -> layoutFragmentTester element, result

    suite "one line, cs: 1 should mean alignment has no effect", ->
      leftAligned     = [0,   ]
      topAligned      = [0,   ]
      w = [46]
      h = [12]
      for value, result of {
          top:          top:  topAligned, left: leftAligned, w: w, h: h
          centerCenter: top:  topAligned, left: leftAligned, w: w, h: h
          bottomRight:  top:  topAligned, left: leftAligned, w: w, h: h
          }
        do (value, result) =>
          drawTest3 "align: '#{value}'",
            stagingBitmapsCreateShouldBe: 0
            element: ->
              new TextElement
                size: cs:1
                align: value
                color:"red", text:"Thingy", fontSize:16
                new Rectangle color: "#0002"
                new Fill()
            test: (element) -> layoutFragmentTester element, result

    suite "layoutMode: tight", ->
      ###
      NOTES / TODO

      Okay, I need to refactor text layout. Right now the fragment.area variable isn't really an area.
      The location is used for where to tell Canvas to draw the text. It isn't the upper-left corner
      of the area enclosing the text. This is just "wrong."
      I also think we should just drop using rectangles at all and just store the components. It's
      a little more code, but its a lot less GC pressure.
      So, I need the following:
        logicalLocation - the upper-left corner of the logical area
          logical area is the exact area if using tight0 - otherwise it is the textual area
        logicalSize
        textLocationOffset - the offsets to add to logicalLocation to get the coordinates to pass to Canvas for drawing
        drawAreaOffset - add to logicalLocation to get the drawArea location
        drawAreaSize - size of the draw area
      I'm thinking of making a new object for Fragments. Then I can package most the logic
      for managing those values as X/Y Number-value-members.

      ###
      leftAligned     = [0    ]
      topAligned      = [0    ]
      rightAligned    = [100  ]
      bottomAligned   = [100  ]
      hCenterAligned  = [50   ]
      vCenterAligned  = [50   ]
      for value, result of {
          top:          top:      topAligned,     left:     leftAligned, w: [44], h: [29]
          left:         top:      topAligned,     left:     leftAligned
          center:       top:      topAligned,     hCenter:  hCenterAligned
          right:        top:      topAligned,     right:    rightAligned
          bottom:       bottom:   bottomAligned,  left:     leftAligned
          topLeft:      top:      topAligned,     left:     leftAligned
          topCenter:    top:      topAligned,     hCenter:  hCenterAligned
          topRight:     top:      topAligned,     right:    rightAligned
          centerLeft:   vCenter:  vCenterAligned, left:     leftAligned
          centerCenter: vCenter:  vCenterAligned, hCenter:  hCenterAligned
          centerRight:  vCenter:  vCenterAligned, right:    rightAligned
          bottomLeft:   bottom:   bottomAligned,  left:     leftAligned
          bottomCenter: bottom:   bottomAligned,  hCenter:  hCenterAligned
          bottomRight:  bottom:   bottomAligned,  right:    rightAligned
          }
        do (value, result) =>
          drawTest3 "align: '#{value}'",
            stagingBitmapsCreateShouldBe: 0
            element: ->
              new TextElement
                layoutMode: "tight0"
                size: ps: 1
                align: value
                color:"red", text:"(Q)", fontSize:32
                new Rectangle color: "#0002"
                new Fill()
            test: (element) -> layoutFragmentTester element, result