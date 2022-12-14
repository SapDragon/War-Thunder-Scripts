/**
 * Some utility functions for work with timBar gui object
 */

::g_time_bar <- {
  _direction = {
    backward = {
      incSignMultiplier = -1
    }
    forward = {
      incSignMultiplier = 1
    }
  }

  /**
   * Set full period time to timeBar
   * @time_bar_obj - timeBar object
   * @period_time - time in seconds
   */
  function setPeriod(timeBarObj, periodTime, isCyclic = false)
  {
    let speed = periodTime ? 360.0 / periodTime : 0
    _setSpeed(timeBarObj, speed)

    if (isCyclic)
    {
      timeBarObj["inc-min"] = "0.0"
      timeBarObj["inc-max"] = "360.0"
      timeBarObj["inc-is-cyclic"] = "yes"
    }
  }

  function _setSpeed(timeBarObj, speed)
  {
    speed = getDirection(timeBarObj).incSignMultiplier * fabs(speed)
    timeBarObj["inc-factor"] = speed.tostring()
  }

  function _getSpeed(timeBarObj)
  {
    return (timeBarObj?["inc-factor"] ?? 0).tofloat()
  }

  /**
   * Set current time to timeBar
   * @time_bar_obj - timeBar object
   * @current_time - time in seconds
   */
  function setCurrentTime(timeBarObj, currentTime)
  {
    let curVal = currentTime * _getSpeed(timeBarObj)
    timeBarObj["sector-angle-2"] = curVal.tostring()
  }

  function setValue(timeBarObj, value)
  {
    timeBarObj["sector-angle-2"] = (360 * value).tointeger().tostring()
  }

  function getDirection(timeBarObj)
  {
    return _direction[getDirectionName(timeBarObj)]
  }

  function getDirectionName(timeBarObj)
  {
    if (timeBarObj?.direction != null)
      return timeBarObj.direction
    else
      return "forward"
  }

  /**
   * Set clockwise direction of time bar.
   * @time_bar_obj - timeBar object
   */
  function setDirectionForward(timeBarObj)
  {
    _setDirection(timeBarObj, "forward")
  }

  /**
   * Set counter clockwise direction of time bar.
   * @time_bar_obj - timeBar object
   */
  function setDirectionBackward(timeBarObj)
  {
    _setDirection(timeBarObj, "backward")
  }

  /**
   * Toggle direction of time bar.
   * @time_bar_obj - timeBar object
   */
  function toggleDirection(timeBarObj)
  {
    _setDirection(timeBarObj, getDirectionName(timeBarObj) == "forward" ? "backward" : "forward")
  }

  function _setDirection(timeBarObj, direction)
  {
    let w = _getSpeed(timeBarObj)
    timeBarObj.direction = direction
    _setSpeed(timeBarObj, w)
  }
}
