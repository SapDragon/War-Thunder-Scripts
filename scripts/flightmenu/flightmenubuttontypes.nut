let enums = require("%sqStdLibs/helpers/enums.nut")
let { canRestart, canBailout } = require("%scripts/flightMenu/flightMenuState.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { is_replay_playing } = require("replays")

let buttons = {
  types = []

  template = {
    idx = -1
    name = ""
    buttonId = ""
    labelText = ""
    onClickFuncName = ""
    brAfter = false
    isAvailableInMission = @() true
    canShowOnMissionFailed = false
    isVisible = @() canShowOnMissionFailed || ::get_mission_status() != ::MISSION_STATUS_FAIL
    getUpdatedLabelText = @() "" // Unchangable buttons returns empty string.
  }
}

let function typeConstructor()
{
  buttonId = $"btn_{name.tolower()}"
  labelText = $"#flightmenu/btn{name}"
  onClickFuncName = $"on{name}"
}

local idx = 0
enums.addTypes(buttons, {
  RESUME = {
    idx = idx++
    name = "Resume"
    brAfter = true
  }
  OPTIONS = {
    idx = idx++
    name = "Options"
    isAvailableInMission = @() ::get_game_mode() != ::GM_BENCHMARK
  }
  CONTROLS = {
    idx = idx++
    name = "Controls"
    isAvailableInMission = @() ::get_game_mode() != ::GM_BENCHMARK && ::has_feature("ControlsAdvancedSettings")
  }
  STATS = {
    idx = idx++
    name = "Stats"
    isAvailableInMission = @() ::is_multiplayer()
  }
  CONTROLS_HELP = {
    idx = idx++
    name = "ControlsHelp"
    isAvailableInMission = @() ::get_game_mode() != ::GM_BENCHMARK && ::has_feature("ControlsHelp")
  }
  RESTART = {
    idx = idx++
    name = "Restart"
    canShowOnMissionFailed = true
    isVisible = canRestart
  }
  BAILOUT = {
    idx = idx++
    name = "Bailout"
    isVisible = canBailout
    getUpdatedLabelText = function getUpdatedLabelText() {
      local txt = getPlayerCurUnit()?.unitType.getBailoutButtonText() ?? ""
      if (!::is_multiplayer() && ::get_mission_restore_type() == ::ERT_ATTEMPTS)
      {
        local attemptsTxt
        let numLeft = ::get_num_attempts_left()
        if (numLeft < 0)
          attemptsTxt = ::loc("options/attemptsUnlimited")
        else
        {
          local attempts = ::loc(numLeft == 1 ? "options/attemptLeft" : "options/attemptsLeft")
          attemptsTxt = $"{numLeft} {attempts}"
        }
        txt = "".concat(txt, ::loc("ui/parentheses/space", { text = attemptsTxt }))
      }
      return txt
    }
  }
  QUIT_MISSION = {
    idx = idx++
    name = "QuitMission"
    canShowOnMissionFailed = true
    getUpdatedLabelText = function getUpdatedLabelText() {
      return ::loc(
        is_replay_playing() ? "flightmenu/btnQuitReplay"
        : (::get_mission_status() == ::MISSION_STATUS_SUCCESS
            && ::get_game_mode() == ::GM_DYNAMIC) ? "flightmenu/btnCompleteMission"
        : "flightmenu/btnQuitMission"
      )
    }
  }
  FREECAM = {
    idx = idx++
    name = "Freecam"
    isVisible = @() ("toggle_freecam" in getroottable())
  }
}, typeConstructor)

buttons.types.sort(@(a, b) a.idx <=> b.idx)
return buttons
