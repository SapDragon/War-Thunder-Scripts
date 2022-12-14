let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let { getEntitlementView, getEntitlementLayerIcons } = require("%scripts/onlineShop/entitlementView.nut")

::gui_handlers.EntitlementRewardWnd <- class extends ::gui_handlers.trophyRewardWnd
{
  wndType = handlerType.MODAL

  entitlementConfig = null

  chestDefaultImg = "every_day_award_trophy_big"

  prepareParams = @() null
  getTitle = @() getEntitlementName(entitlementConfig)
  isRouletteStarted = @() false

  viewParams = null

  function openChest() {
    if (opened)
      return false

    opened = true
    updateWnd()
    return true
  }

  function checkConfigsArray() {
    let unitNames = entitlementConfig?.aircraftGift ?? []
    if (unitNames.len())
      unit = ::getAircraftByName(unitNames[0])

    let decalsNames = entitlementConfig?.decalGift ?? []
    let attachablesNames = entitlementConfig?.attachableGift ?? []
    let skinsNames = entitlementConfig?.skinGift ?? []
    local resourceType = ""
    local resource = ""
    if (decalsNames.len())
    {
      resourceType = "decal"
      resource = decalsNames[0]
    }
    else if (attachablesNames.len())
    {
      resourceType = "attachable"
      resource = attachablesNames[0]
    }
    else if (skinsNames.len())
    {
      resourceType = "skin"
      resource = skinsNames[0]
    }

    if (resource != "")
      updateResourceData(resource, resourceType)
  }

  function getIconData() {
    if (!opened)
      return ""

    return "{0}{1}".subst(
      ::LayersIcon.getIconData($"{chestDefaultImg}_opened"),
      getEntitlementLayerIcons(entitlementConfig)
    )
  }

  function updateRewardText() {
    if (!opened)
      return

    let obj = scene.findObject("prize_desc_div")
    if (!::checkObj(obj))
      return

    let data = getEntitlementView(entitlementConfig, (viewParams ?? {}).__merge({
      header = ::loc("mainmenu/you_received")
      multiAwardHeader = true
      widthByParentParent = true
    }))

    guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  checkSkipAnim = @() false
  notifyTrophyVisible = @() null
  updateRewardPostscript = @() null
  updateRewardItem = @() null
}

return {
  showEntitlement = function(entitlementId, params = {}) {
    let config = getEntitlementConfig(entitlementId)
    if (!config)
    {
      ::dagor.logerr($"Entitlement Reward: Could not find entitlement config {entitlementId}")
      return
    }

    ::handlersManager.loadHandler(::gui_handlers.EntitlementRewardWnd, {
      entitlementConfig = config
      viewParams = params
    })
  }
}