let { animBgLoad } = require("%scripts/loading/animBg.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { setHelpTextOnLoading, setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")

::gui_start_loading <- function gui_start_loading(isMissionLoading = false)
{
  let briefing = ::DataBlock()
  if (::g_login.isLoggedIn() && isMissionLoading
      && ::loading_get_briefing(briefing) && (briefing.blockCount() > 0))
  {
    ::dagor.debug("briefing loaded, place = "+briefing.getStr("place_loc", ""))
    ::handlersManager.loadHandler(::gui_handlers.LoadingBrief, { briefing = briefing })
  }
  else if (::g_login.isLoggedIn())
    ::handlersManager.loadHandler(::gui_handlers.LoadingHangarHandler, { isEnteringMission = isMissionLoading })
  else
    ::handlersManager.loadHandler(::gui_handlers.LoadingHandler)

  showTitleLogo()
}

::gui_handlers.LoadingHandler <- class extends ::BaseGuiHandler
{
  sceneBlkName = "%gui/loading/loading.blk"
  sceneNavBlkName = "%gui/loading/loadingNav.blk"

  function initScreen()
  {
    animBgLoad()
    setVersionText()
    setHelpTextOnLoading(scene.findObject("help_text"))

    let updObj = scene.findObject("cutscene_update")
    if (::checkObj(updObj))
      updObj.setUserData(this)
  }

  function onUpdate(obj, dt)
  {
    if (::loading_is_finished())
      ::loading_press_apply()
  }
}