let { format, split_by_chars } = require("string")
let guidParser = require("%scripts/guidParser.nut")
let itemRarity = require("%scripts/items/itemRarity.nut")
let contentPreview = require("%scripts/customization/contentPreview.nut")
let skinLocations = require("%scripts/customization/skinLocations.nut")
let { isMarketplaceEnabled } = require("%scripts/items/itemsMarketplace.nut")
let { copyParamsToTable, eachParam } = require("%sqstd/datablock.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { processUnitTypeArray } = require("%scripts/unit/unitClassType.nut")
let { GUI } = require("%scripts/utils/configs.nut")

::Decorator <- class
{
  id = ""
  blk = null
  decoratorType = null
  unlockId = ""
  unlockBlk = null
  isLive = false
  couponItemdefId = null
  group = ""

  category = ""
  catIndex = 0

  limit = -1

  tex = ""
  aspect_ratio = 0

  countries = null
  units = null
  allowedUnitTypes = []

  tags = null
  rarity = null

  lockedByDLC = null

  cost = null
  maxSurfaceAngle = 180

  isToStringForDebug = true

  constructor(blkOrId, decType)
  {
    decoratorType = decType
    if (::u.isString(blkOrId))
      id = blkOrId
    else if (::u.isDataBlock(blkOrId))
    {
      blk = blkOrId
      id = blk.getBlockName()
    }

    unlockId = ::getTblValue("unlock", blk, "")
    unlockBlk = ::g_unlocks.getUnlockById(unlockId)
    limit = ::getTblValue("limit", blk, decoratorType.defaultLimitUsage)
    category = ::getTblValue("category", blk, "")
    group = ::getTblValue("group", blk, "")

    // Only decorators from live.warthunder.com has GUID in id.
    let slashPos = id.indexof("/")
    isLive = guidParser.isGuid(slashPos == null ? id : id.slice(slashPos + 1))

    cost = decoratorType.getCost(id)
    maxSurfaceAngle = blk?.maxSurfaceAngle ?? 180

    tex = blk ? ::get_decal_tex(blk, 1) : id
    aspect_ratio = blk ? decoratorType.getRatio(blk) : 1

    if ("countries" in blk)
    {
      countries = []
      eachParam(blk.countries, function(access, country) {
        if (access == true)
          countries.append($"country_{country}")
      }, this)
    }

    units = []
    if ("units" in blk)
      units = split_by_chars(blk.units, "; ")

    allowedUnitTypes = blk?.unitType ? (blk % "unitType") : []

    if ("tags" in blk)
      tags = copyParamsToTable(blk.tags)

    rarity  = itemRarity.get(blk?.item_quality, blk?.name_color)

    if (blk?.marketplaceItemdefId != null && isMarketplaceEnabled())
    {
      couponItemdefId = blk.marketplaceItemdefId

      let couponItem = ::ItemsManager.findItemById(couponItemdefId)
      if (couponItem)
        updateFromItemdef(couponItem.itemDef)
    }

    if (!isUnlocked() && !isVisible() && ("showByEntitlement" in unlockBlk))
      lockedByDLC = ::has_entitlement(unlockBlk.showByEntitlement) ? null : unlockBlk.showByEntitlement
  }

  function getName()
  {
    let name = decoratorType.getLocName(id)
    return isRare() ? ::colorize(getRarityColor(), name) : name
  }

  function getDesc()
  {
    return decoratorType.getLocDesc(id)
  }

  function isUnlocked()
  {
    return decoratorType.isPlayerHaveDecorator(id)
  }

  function isVisible()
  {
    return decoratorType.isVisible(blk, this)
  }

  function getCost()
  {
    return cost
  }

  function canRecieve()
  {
    return unlockBlk != null || ! getCost().isZero() || getCouponItemdefId() != null
  }

  function isSuitableForUnit(unit)
  {
    return unit == null
      || (!isLockedByCountry(unit) && !isLockedByUnit(unit) && isAllowedByUnitTypes(unit.unitType.tag))
  }

  function isLockedByCountry(unit)
  {
    if (countries == null)
      return false

    return !::isInArray(::getUnitCountry(unit), countries)
  }

  function isLockedByUnit(unit)
  {
    if (decoratorType == ::g_decorator_type.SKINS)
      return unit?.name != ::g_unlocks.getPlaneBySkinId(id)

    if (::u.isEmpty(units))
      return false

    return !::isInArray(unit?.name, units)
  }

  function getUnitTypeLockIcon()
  {
    if (::u.isEmpty(units))
      return null

    return ::get_unit_type_font_icon(::get_es_unit_type(::getAircraftByName(units[0])))
  }

  function getTypeDesc()
  {
    return decoratorType.getTypeDesc(this)
  }

  function getRestrictionsDesc()
  {
    if (decoratorType == ::g_decorator_type.SKINS)
      return ""

    let important = []
    let common    = []

    if (!::u.isEmpty(units))
    {
      let visUnits = ::u.filter(units, @(u) ::getAircraftByName(u)?.isInShop)
      important.append(::loc("options/unit") + ::loc("ui/colon") +
        ::g_string.implode(::u.map(visUnits, @(u) ::getUnitName(u)), ::loc("ui/comma")))
    }

    if (countries)
    {
      let visCountries = ::u.filter(countries, @(c) ::isInArray(c, shopCountriesList))
      important.append(::loc("events/countres") + " " +
        ::g_string.implode(::u.map(visCountries, @(c) ::loc(c)), ::loc("ui/comma")))
    }

    if (limit != -1)
      common.append(::loc("mainmenu/decoratorLimit", { limit = limit }))

    return ::colorize("warningTextColor", ::g_string.implode(important, "\n")) +
      (important.len() ? "\n" : "") + ::g_string.implode(common, "\n")
  }

  function getLocationDesc()
  {
    if (!decoratorType.hasLocations(id))
      return ""

    let mask = skinLocations.getSkinLocationsMaskBySkinId(id, false)
    let locations = mask ? skinLocations.getLocationsLoc(mask) : []
    if (!locations.len())
      return ""

    return ::loc("camouflage/for_environment_conditions") +
      ::loc("ui/colon") + ::g_string.implode(locations.map(@(l) ::colorize("activeTextColor", l)), ", ")
  }

  function getTagsDesc()
  {
    local tagsLoc = getTagsLoc()
    if (!tagsLoc.len())
      return ""

    tagsLoc = ::u.map(tagsLoc, @(txt) ::colorize("activeTextColor", txt))
    return ::loc("ugm/tags") + ::loc("ui/colon") + ::g_string.implode(tagsLoc, ::loc("ui/comma"))
  }

  function getUnlockDesc()
  {
    if (!unlockBlk)
      return ""

    let config = ::build_conditions_config(unlockBlk)

    let showStages = (config?.stages ?? []).len() > 1
    if (!showStages && config.maxVal < 0)
      return ""

    let descData = []

    let isComplete = ::g_unlocks.isUnlockComplete(config)

    if (showStages && !isComplete)
      descData.append(::loc("challenge/stage", {
                           stage = ::colorize("unlockActiveColor", config.curStage + 1)
                           totalStages = ::colorize("unlockActiveColor", config.stages.len())
                         }))

    let curVal = config.curVal < config.maxVal ? config.curVal : null
    descData.append(::UnlockConditions.getConditionsText(config.conditions, curVal, config.maxVal))

    return ::g_string.implode(descData, "\n")
  }

  function getCostText()
  {
    if (isUnlocked())
      return ""

    if (cost.isZero())
      return ""

    return ::loc("ugm/price")
           + ::loc("ui/colon")
           + cost.getTextAccordingToBalance()
           + "\n"
           + ::loc("shop/object/can_be_purchased")
  }

  function getRevenueShareDesc()
  {
    if (unlockBlk?.isRevenueShare != true)
      return ""

    return ::colorize("advertTextColor", ::loc("content/revenue_share"))
  }

  function getSmallIcon()
  {
    return decoratorType.getSmallIcon(this)
  }

  function canBuyUnlock(unit)
  {
    return isSuitableForUnit(unit) && !isUnlocked() && !getCost().isZero() && ::has_feature("SpendGold")
  }

  function canGetFromCoupon(unit)
  {
    return isSuitableForUnit(unit) && !isUnlocked()
      && (::ItemsManager.getInventoryItemById(getCouponItemdefId())?.canConsume() ?? false)
  }

  function canBuyCouponOnMarketplace(unit)
  {
    return isSuitableForUnit(unit) && !isUnlocked()
      && (::ItemsManager.findItemById(getCouponItemdefId())?.hasLink() ?? false)
  }

  function canUse(unit)
  {
    return isAvailable(unit) && !isOutOfLimit(unit)
  }

  function isAvailable(unit)
  {
    return isSuitableForUnit(unit) && isUnlocked()
  }

  function getCountOfUsingDecorator(unit)
  {
    if (decoratorType != ::g_decorator_type.ATTACHABLES || !isUnlocked())
      return 0

    local numUse = 0
    for (local i = 0; i < decoratorType.getAvailableSlots(unit); i++)
      if (id == decoratorType.getDecoratorNameInSlot(i) || (group != "" && group == decoratorType.getDecoratorGroupInSlot(i)))
        numUse++

    return numUse
  }

  function isOutOfLimit(unit)
  {
    if (limit < 0)
      return false

    if (limit == 0)
      return true

    return limit <= getCountOfUsingDecorator(unit)
  }

  function isRare()
  {
    return rarity.isRare
  }

  function getRarity()
  {
    return rarity.value
  }

  function getRarityColor()
  {
    return  rarity.color
  }

  function getTagsLoc()
  {
    let res = rarity.tag ? [ rarity.tag ] : []
    let tagsVisibleBlk = GUI.get()?.decorator_tags_visible
    if (tagsVisibleBlk && tags)
      foreach (tagBlk in tagsVisibleBlk % "i")
        if (tags?[tagBlk.tag])
          res.append(::loc("content/tag/" + tagBlk.tag))
    return res
  }

  function updateFromItemdef(itemDef)
  {
    rarity = itemRarity.get(itemDef?.item_quality, itemDef?.name_color)
    tags = itemDef?.tags
  }

  function setCouponItemdefId(itemdefId)
  {
    couponItemdefId = itemdefId
  }

  function getCouponItemdefId()
  {
    return couponItemdefId
  }

  function _tostring()
  {
    return format("Decorator(%s, %s%s)", ::toString(id), decoratorType.name,
      unlockId == "" ? "" : (", unlock=" + unlockId))
  }

  function getLocParamsDesc()
  {
    return decoratorType.getLocParamsDesc(this)
  }

  function canPreview()
  {
    return isLive ? decoratorType.canPreviewLiveDecorator() : true
  }

  function doPreview()
  {
    if (canPreview())
      contentPreview.showResource(id, decoratorType.resourceType)
  }

  function isAllowedByUnitTypes(unitType)
  {
    return (allowedUnitTypes.len() == 0 || allowedUnitTypes.indexof(unitType) != null)
  }

  function getLocAllowedUnitTypes() {
    if (blk == null)
      return ""

    let processedUnitTypes = processUnitTypeArray(blk % "unitType")
    if (processedUnitTypes.len() == 0)
      return ""

    return ::colorize("activeTextColor", ::loc("ui/comma").join(
      processedUnitTypes.map(@(unitType) ::loc($"mainmenu/type_{unitType}"))))
  }

  function getVehicleDesc()
  {
    let locUnitTypes = getLocAllowedUnitTypes()
    if (locUnitTypes == "")
      return ""
    return $"{::loc("mainmenu/btnUnits")}{::loc("ui/colon")}{locUnitTypes}"
  }
}
