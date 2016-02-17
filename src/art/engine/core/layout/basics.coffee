Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
LayoutBase = require '../../layout/layout_base'

{point, Point, perimeter} = Atomic
{BaseObject, isFunction, abs} = Foundation
{nearInfiniteSize, nearInfinity, nearInfinityResult} = LayoutBase

module.exports = class Basics extends BaseObject
  @nearInfiniteSize: nearInfiniteSize
  @nearInfinity: nearInfinity
  @nearInfinityResult: nearInfinityResult

  @layoutMargin: (element, parentSize) ->
    margin = element.getPendingMargin()
    element._setMarginFromLayout perimeter if isFunction margin
      margin parentSize
    else
      margin

  @layoutPadding: (element, parentSize) ->
    padding = element.getPendingPadding()
    element._setPaddingFromLayout perimeter if isFunction padding
      padding parentSize
    else
      padding

  @isInfiniteResult: isInfiniteResult = (x) -> abs(x) >= nearInfinityResult

  @deinfinitize: (p) ->
    {x, y} = p
    x = if isInfiniteResult x then 0 else x
    y = if isInfiniteResult y then 0 else y
    p.with x, y

  @sizeWithPadding: (width, height, currentPadding) ->
    point(
      width + currentPadding.getWidth()
      height + currentPadding.getHeight()
    )