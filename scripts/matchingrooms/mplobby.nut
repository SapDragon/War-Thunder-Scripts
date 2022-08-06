let avatars = require("%scripts/user/avatars.nut")
let playerContextMenu = require("%scripts/user/playerContextMenu.nut")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let { isChatEnabled } = require("%scripts/chat/chatStates.nut")
let fillSessionInfo = require("%scripts/matchingRooms/fillSessionInfo.nut")
let { mpLobbyBlkPath } = require("%scripts/matchingRooms/getMPLobbyBlkPath.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { getUnitItemStatusText } = require("%scripts/unit/unitInfoTexts.nut")
let { showMsgboxIfSoundModsNotAllowed } = require("%scripts/penitentiary/soundMods.nut")
let { getToBattleLocId } = require("%scripts/viewUtils/interfaceCustomization.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { setGuiOptionsMode } = ::require_native("guiOptions")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")

::session_player_rmenu <- function session_player_rmenu(handler, player, chatLog = null, position = null, orientation = null)
{
  if (!player || player.isBot || !("userId" in player) || !::g_login.isLoggedIn())
    return

  playerContextMenu.showMenu(null, handler, {
    playerName = player.name
    uid = player.userId.tostring()
    clanTag = player.clanTag
    position = position
    orientation = orientation
    chatLog = chatLog
    isMPLobby = true
    canComplain = true
  })
}

::gui_start_mp_lobby <- function gui_start_mp_lobby()
{
  if (::SessionLobby.status != lobbyStates.IN_LOBBY)
  {
    ::gui_start_mainmenu()
    return
  }

  local backFromLobby = ::gui_start_mainmenu
  if (::SessionLobby.getGameMode() == ::GM_SKIRMISH && !::g_missions_manager.isRemoteMission)
    backFromLobby = ::gui_start_skirmish
  else
  {
    let lastEvent = ::SessionLobby.getRoomEvent()
    if (lastEvent && ::events.eventRequiresTicket(lastEvent) && ::events.getEventActiveTicket(lastEvent) == null)
    {
      ::gui_start_mainmenu()
      return
    }
  }

  ::g_missions_manager.isRemoteMission = false
  ::handlersManager.loadHandler(::gui_handlers.MPLobby, { backSceneFunc = backFromLobby })
}

::gui_handlers.MPLobby <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = mpLobbyBlkPath.value
  shouldBlurSceneBgFn = needUseHangarDof
  handlerLocId = "multiplayer/lobby"

  tblData = null
  tblMarkupData = null

  haveUnreadyButton = false
  waitBox = null
  optionsBox = null
  curGMmode = -1
  slotbarActions = ["autorefill", "aircraft", "crew", "sec_weapons", "weapons", "repair"]

  playersListWidgetWeak = null
  tableTeams = null
  isInfoByTeams = false
  isTimerVisible = false

  viewPlayer = null
  isPlayersListHovered = true

  function initScreen()
  {
    if (!::SessionLobby.isInRoom())
      return

    curGMmode = ::SessionLobby.getGameMode()
    setGuiOptionsMode(::get_options_mode(curGMmode))

    scene.findObject("mplobby_update").setUserData(this)

    initTeams()

    playersListWidgetWeak = ::gui_handlers.MRoomPlayersListWidget.create({
      scene = scene.findObject("players_tables_place")
      teams = tableTeams
      onPlayerSelectCb = ::Callback(refreshPlayerInfo, this)
      onPlayerDblClickCb = ::Callback(openUserCard, this)
      onPlayerRClickCb = ::Callback(onUserRClick, this)
      onTablesHoverChange = ::Callback(onPlayersListHover, this)
    })
    if (playersListWidgetWeak)
      playersListWidgetWeak = playersListWidgetWeak.weakref()
    registerSubHandler(playersListWidgetWeak)
    playersListWidgetWeak?.moveMouse()

    if (!::SessionLobby.getPublicParam("symmetricTeams", true))
      ::SessionLobby.setTeam(::SessionLobby.getRandomTeam(), true)

    updateSessionInfo()
    createSlotbar({ getLockedCountryData = @() ::SessionLobby.getLockedCountryData() })
    setSceneTitle(::loc("multiplayer/lobby"))
    updateWindow()
    updateRoomInSession()

    initChat()
    let sessionInfo = ::SessionLobby.getSessionInfo()
    ::update_vehicle_info_button(scene, sessionInfo)
  }

  function initTeams()
  {
    tableTeams = [::g_team.ANY]
    if (::SessionLobby.isEventRoom)
    {
      tableTeams = [::g_team.A, ::g_team.B]
      isInfoByTeams = true
    }
  }

  function initChat()
  {
    if (!isChatEnabled())
      return

    let chatObj = scene.findObject("lobby_chat_place")
    if (::checkObj(chatObj))
      ::joinCustomObjRoom(chatObj, ::SessionLobby.getChatRoomId(), ::SessionLobby.getChatRoomPassword(), this)
  }

  function updateSessionInfo()
  {
    let mpMode = ::SessionLobby.getGameMode()
    if (curGMmode != mpMode)
    {
      curGMmode = mpMode
      ::set_mp_mode(curGMmode)
      setGuiOptionsMode(::get_options_mode(curGMmode))
    }

    fillSessionInfo(scene, ::SessionLobby.getSessionInfo())
  }

  function updateTableHeader()
  {
    let commonHeader = this.showSceneBtn("common_list_header", !isInfoByTeams)
    let byTeamsHeader = this.showSceneBtn("list_by_teams_header", isInfoByTeams)
    let teamsNest = isInfoByTeams ? byTeamsHeader : commonHeader.findObject("num_teams")

    let maxMembers = ::SessionLobby.getMaxMembersCount()
    let countTbl = ::SessionLobby.getMembersCountByTeams()
    let countTblReady = ::SessionLobby.getMembersCountByTeams(null, true)
    if (!isInfoByTeams)
    {
      let totalNumPlayersTxt = ::loc("multiplayer/playerList")
        + ::loc("ui/parentheses/space", { text = countTbl.total + "/" + maxMembers })
      commonHeader.findObject("num_players").setValue(totalNumPlayersTxt)
    }

    let event = ::SessionLobby.getRoomEvent()
    foreach(team in tableTeams)
    {
      let teamObj = teamsNest.findObject("num_team" + team.id)
      if (!::check_obj(teamObj))
        continue

      local text = ""
      if (isInfoByTeams && event)
      {
        local locId = "multiplayer/teamPlayers"
        let locParams = {
          players = countTblReady[team.code]
          maxPlayers = ::events.getMaxTeamSize(event)
          unready = countTbl[team.code] - countTblReady[team.code]
        }
        if (locParams.unready)
          locId = "multiplayer/teamPlayers/hasUnready"
        text = ::loc(locId, locParams)
      }
      teamObj.setValue(text)
    }

    ::update_team_css_label(teamsNest)
  }

  function updateRoomInSession()
  {
    if (::checkObj(scene))
      scene.findObject("battle_in_progress").wink = ::SessionLobby.isRoomInSession ? "yes" : "no"
    updateTimerInfo()
  }

  function updateWindow()
  {
    updateTableHeader()
    updateSessionStatus()
    updateButtons()
  }

  function onEventLobbyMembersChanged(p)
  {
    updateWindow()
  }

  function onEventLobbyMemberInfoChanged(p)
  {
    updateWindow()
  }

  function onEventLobbySettingsChange(p)
  {
    updateSessionInfo()
    reinitSlotbar()
    updateWindow()
    updateTimerInfo()
  }

  function onEventLobbyRoomInSession(p)
  {
    updateRoomInSession()
    updateButtons()
  }

  function getSelectedPlayer()
  {
    return playersListWidgetWeak && playersListWidgetWeak.getSelectedPlayer()
  }

  function refreshPlayerInfo(player)
  {
    viewPlayer = player
    updatePlayerInfo(player)
    this.showSceneBtn("btn_usercard", player != null && !::show_console_buttons && ::has_feature("UserCards"))
    updateOptionsButton()
  }

  updateOptionsButton = @() this.showSceneBtn("btn_user_options",
    ::show_console_buttons && viewPlayer != null && isPlayersListHovered)

  function updatePlayerInfo(player)
  {
    let mainObj = scene.findObject("player_info")
    if (!::checkObj(mainObj) || !player)
      return

    let titleObj = mainObj.findObject("player_title")
    if (::checkObj(titleObj))
      titleObj.setValue((player.title != "") ? (::loc("title/title") + ::loc("ui/colon") + ::loc("title/" + player.title)) : "")

    let spectatorObj = mainObj.findObject("player_spectator")
    if (::checkObj(spectatorObj))
    {
      let desc = ::g_player_state.getStateByPlayerInfo(player).getText(player)
      spectatorObj.setValue((desc != "") ? (::loc("multiplayer/state") + ::loc("ui/colon") + desc) : "")
    }

    let myTeam = (::SessionLobby.status == lobbyStates.IN_LOBBY)? ::SessionLobby.team : ::get_mp_local_team()
    mainObj.playerTeam = myTeam==Team.A? "a" : (myTeam == Team.B? "b" : "")

    let teamObj = mainObj.findObject("player_team")
    if (::checkObj(teamObj))
    {
      local teamTxt = ""
      local teamStyle = ""
      let team = player? player.team : Team.Any
      if (team == Team.A)
      {
        teamStyle = "a"
        teamTxt = ::loc("multiplayer/teamA")
      }
      else if (team == Team.B)
      {
        teamStyle = "b"
        teamTxt = ::loc("multiplayer/teamB")
      }

      teamObj.team = teamStyle
      let teamIcoObj = teamObj.findObject("player_team_ico")
      teamIcoObj.show(teamTxt != "")
      teamIcoObj.tooltip = ::loc("multiplayer/team") + ::loc("ui/colon") + teamTxt
    }

    let playerIcon = (!player || player.isBot)? "cardicon_bot" : avatars.getIconById(player.pilotId)
    ::fill_gamer_card({
                      name = player.name
                      clanTag = player.clanTag
                      icon = playerIcon
                      country = player?.country ?? ""
                    },
                    "player_", mainObj)

    let airObj = mainObj.findObject("curAircraft")
    if (!::checkObj(airObj))
      return

    let showAirItem = ::SessionLobby.getMissionParam("maxRespawns", -1) == 1 && player.country && player.selAirs.len() > 0
    airObj.show(showAirItem)

    if (showAirItem)
    {
      let airName = ::getTblValue(player.country, player.selAirs, "")
      let air = getAircraftByName(airName)
      if (!air)
      {
        airObj.show(false)
        return
      }

      let existingAirObj = airObj.findObject("curAircraft_place")
      if (::checkObj(existingAirObj))
        guiScene.destroyElement(existingAirObj)

      let params = {
        getEdiffFunc = ::Callback(getCurrentEdiff, this)
        status = getUnitItemStatusText(bit_unit_status.owned)
      }
      local data = ::build_aircraft_item(airName, air, params)
      data = "rankUpList { id:t='curAircraft_place'; holdTooltipChildren:t='yes'; {0} }".subst(data)
      guiScene.appendWithBlk(airObj, data, this)
      ::fill_unit_item_timers(airObj.findObject(airName), air)
    }
  }

  function getMyTeamDisbalanceMsg(isFullText = false)
  {
    let countTbl = ::SessionLobby.getMembersCountByTeams(null, true)
    let maxDisbalance = ::SessionLobby.getMaxDisbalance()
    let myTeam = ::SessionLobby.team
    if (myTeam != Team.A && myTeam != Team.B)
      return ""

    let otherTeam = ::g_team.getTeamByCode(myTeam).opponentTeamCode
    if (countTbl[myTeam] - maxDisbalance < countTbl[otherTeam])
      return ""

    let params = {
      chosenTeam = ::colorize("teamBlueColor", ::g_team.getTeamByCode(myTeam).getShortName())
      otherTeam =  ::colorize("teamRedColor", ::g_team.getTeamByCode(otherTeam).getShortName())
      chosenTeamCount = countTbl[myTeam]
      otherTeamCount =  countTbl[otherTeam]
      reqOtherteamCount = countTbl[myTeam] - maxDisbalance + 1
    }
    let locKey = "multiplayer/enemyTeamTooLowMembers" + (isFullText ? "" : "/short")
    return ::loc(locKey, params)
  }

  function getReadyData()
  {
    let res = {
      readyBtnText = ""
      readyBtnHint = ""
      isVisualDisabled = false
    }

    if (!::SessionLobby.isUserCanChangeReady() && !::SessionLobby.hasSessionInLobby())
      return res

    let isReady = ::SessionLobby.hasSessionInLobby() ? ::SessionLobby.isInLobbySession : ::SessionLobby.isReady
    if (::SessionLobby.canStartSession() && isReady)
      res.readyBtnText = ::loc("multiplayer/btnStart")
    else if (::SessionLobby.isRoomInSession)
    {
      res.readyBtnText = ::loc(getToBattleLocId())
      res.isVisualDisabled = !::SessionLobby.canJoinSession()
    } else if (!isReady)
      res.readyBtnText = ::loc("mainmenu/btnReady")

    if (!isReady && ::SessionLobby.isEventRoom && ::SessionLobby.isRoomInSession)
    {
      res.readyBtnHint = getMyTeamDisbalanceMsg()
      res.isVisualDisabled = res.readyBtnHint.len() > 0
    }
    return res
  }

  function updateButtons()
  {
    let readyData = getReadyData()
    let readyBtn = this.showSceneBtn("btn_ready", readyData.readyBtnText.len())
    setDoubleTextToButton(scene, "btn_ready", readyData.readyBtnText)
    readyBtn.inactiveColor = readyData.isVisualDisabled ? "yes" : "no"
    scene.findObject("cant_ready_reason").setValue(readyData.readyBtnHint)

    let spectatorBtnObj = scene.findObject("btn_spectator")
    if (::checkObj(spectatorBtnObj))
    {
      let isSpectator = ::SessionLobby.spectator
      let buttonText = ::loc("mainmenu/btnReferee")
        + (isSpectator ? (::loc("ui/colon") + ::loc("options/on")) : "")
      spectatorBtnObj.setValue(buttonText)
      spectatorBtnObj.active = isSpectator ? "yes" : "no"
    }

    let isReady = ::SessionLobby.isReady
    this.showSceneBtn("btn_not_ready", ::SessionLobby.isUserCanChangeReady() && isReady)
    this.showSceneBtn("btn_ses_settings", ::SessionLobby.canChangeSettings())
    this.showSceneBtn("btn_team", !isReady && ::SessionLobby.canChangeTeam())
    this.showSceneBtn("btn_spectator", !isReady && ::SessionLobby.canBeSpectator()
      && !::SessionLobby.isSpectatorSelectLocked)
  }

  function getCurrentEdiff()
  {
    let ediff = ::SessionLobby.getCurRoomEdiff()
    return ediff != -1 ? ediff : ::get_current_ediff()
  }

  function onEventLobbyMyInfoChanged(params)
  {
    updateButtons()
    if ("team" in params)
      guiScene.performDelayed(this, function () {
        reinitSlotbar()
      })
  }

  function onEventLobbyReadyChanged(p)
  {
    updateButtons()
  }

  function updateSessionStatus()
  {
    let needSessionStatus = !isInfoByTeams && !::SessionLobby.isRoomInSession
    let sessionStatusObj = this.showSceneBtn("session_status", needSessionStatus)
    if (needSessionStatus)
      sessionStatusObj.setValue(::SessionLobby.getMembersReadyStatus().statusText)

    let mGameMode = ::SessionLobby.getMGameMode()
    let needTeamStatus = isInfoByTeams && !::SessionLobby.isRoomInSession && !!mGameMode
    local countTbl = null
    if (needTeamStatus)
      countTbl = ::SessionLobby.getMembersCountByTeams()
    foreach(idx, team in tableTeams)
    {
      let teamObj = this.showSceneBtn("team_status_" + team.id, needTeamStatus)
      if (!teamObj || !needTeamStatus)
        continue

      local status = ""
      let minSize = ::events.getMinTeamSize(mGameMode)
      let teamSize = countTbl[team.code]
      if (teamSize < minSize)
        status = ::loc("multiplayer/playersTeamLessThanMin", { minSize = minSize })
      else
      {
        let maxDisbalance = ::SessionLobby.getMaxDisbalance()
        let otherTeamSize = countTbl[team.opponentTeamCode]
        if (teamSize - maxDisbalance > max(otherTeamSize, minSize))
          status = ::loc("multiplayer/playersTeamDisbalance", { maxDisbalance = maxDisbalance })
      }
      teamObj.setValue(status)
    }
  }

  function updateTimerInfo()
  {
    let timers = ::SessionLobby.getRoomActiveTimers()
    let isVisibleNow = timers.len() > 0 && !::SessionLobby.isRoomInSession
    if (!isVisibleNow && !isTimerVisible)
      return

    isTimerVisible = isVisibleNow
    let timerObj = this.showSceneBtn("battle_start_countdown", isTimerVisible)
    if (timerObj && isTimerVisible)
      timerObj.setValue(timers[0].text)
  }

  function onUpdate(obj, dt)
  {
    updateTimerInfo()
  }

  function getChatLog()
  {
    let chatRoom = ::g_chat.getRoomById(::SessionLobby.getChatRoomId())
    return chatRoom!= null ? chatRoom.getLogForBanhammer() : null
  }

  function onComplain(obj)
  {
    let player = getSelectedPlayer()
    if (player && !player.isBot && !player.isLocal)
      ::gui_modal_complain({uid = player.userId, name = player.name }, getChatLog())
  }

  function openUserCard(player)
  {
    if (player && !player.isBot)
      ::gui_modal_userCard({ name = player.name, uid = player.userId });
  }

  function onUserCard(obj)
  {
    openUserCard(getSelectedPlayer())
  }

  function onUserRClick(player)
  {
    session_player_rmenu(this, player, getChatLog())
  }

  function onUserOption(obj)
  {
    let pos = playersListWidgetWeak && playersListWidgetWeak.getSelectedRowPos()
    session_player_rmenu(this, getSelectedPlayer(), getChatLog(), pos)
  }

  function onSessionSettings()
  {
    if (!::SessionLobby.isRoomOwner)
      return

    if (::SessionLobby.isReady)
    {
      this.msgBox("cannot_options_on_ready", ::loc("multiplayer/cannotOptionsOnReady"),
        [["ok", function() {}]], "ok", {cancel_fn = function() {}})
      return
    }

    if (::SessionLobby.isRoomInSession)
    {
      this.msgBox("cannot_options_on_ready", ::loc("multiplayer/cannotOptionsWhileInBattle"),
        [["ok", function() {}]], "ok", {cancel_fn = function() {}})
      return
    }

    //local gm = ::SessionLobby.getGameMode()
    //if (gm == ::GM_SKIRMISH)
    ::gui_start_mislist(true, ::get_mp_mode())
  }

  function onSpectator(obj)
  {
    ::SessionLobby.switchSpectator()
  }

  function onTeam(obj)
  {
    let isSymmetric = ::SessionLobby.getPublicParam("symmetricTeams", true)
    ::SessionLobby.switchTeam(!isSymmetric)
  }

  function onPlayers(obj)
  {
  }

  function doQuit()
  {
    SessionLobby.leaveRoom()
  }

  function onEventLobbyStatusChange(params)
  {
    if (!::SessionLobby.isInRoom())
      goBack()
    else
      updateButtons()
  }

  onEventToBattleLocChanged = @(params) updateButtons()

  function onNotReady()
  {
    if (::SessionLobby.isReady)
      ::SessionLobby.setReady(false)
  }

  function onCancel()
  {
    this.msgBox("ask_leave_lobby", ::loc("flightmenu/questionQuitGame"),
    [
      ["yes", doQuit],
      ["no", function() { }]
    ], "no", { cancel_fn = function() {}})
  }

  function onReady()
  {
    let event = ::SessionLobby.getRoomEvent()
    if (event != null && (!antiCheat.showMsgboxIfEacInactive(event) ||
                          !showMsgboxIfSoundModsNotAllowed(event)))
      return

    if (::SessionLobby.tryJoinSession())
      return

    if (!::SessionLobby.isRoomOwner || !::SessionLobby.isReady)
      return ::SessionLobby.setReady(true)

    let status = ::SessionLobby.getMembersReadyStatus()
    if (status.readyToStart)
      return ::SessionLobby.startSession()

    local msg = status.statusText
    local buttons = [["ok", function() {}]]
    local defButton = "ok"
    if (status.ableToStart)
    {
      buttons = [["#multiplayer/btnStart", function() { ::SessionLobby.startSession() }], ["cancel", function() {}]]
      defButton = "cancel"
      msg += "\n" + ::loc("ask/startGameAnyway")
    }

    this.msgBox("ask_start_session", msg, buttons, defButton, { cancel_fn = function() {}})
  }

  function onCustomChatCancel()
  {
    onCancel()
  }

  function canPresetChange()
  {
    return true
  }

  function onVehiclesInfo(obj)
  {
    ::gui_start_modal_wnd(::gui_handlers.VehiclesWindow, {
      teamDataByTeamName = ::SessionLobby.getSessionInfo()
      roomSpecialRules = ::SessionLobby.getRoomSpecialRules()
    })
  }

  function onPlayersListHover(tblId, isHovered) {
    isPlayersListHovered = isHovered
    updateOptionsButton()
  }
}
