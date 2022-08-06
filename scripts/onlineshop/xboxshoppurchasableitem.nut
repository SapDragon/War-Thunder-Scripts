let { calcPercent } = require("%sqstd/math.nut")
let statsd = require("statsd")
let { cutPrefix } = require("%sqstd/string.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { getEntitlementId } = require("%scripts/onlineShop/onlineBundles.nut")
let { getEntitlementConfig } = require("%scripts/onlineShop/entitlements.nut")
let { getEntitlementView } = require("%scripts/onlineShop/entitlementView.nut")

let XBOX_SHORT_NAME_PREFIX_CUT = "War Thunder - "

local XboxShopPurchasableItem = class
{
  defaultIconStyle = "default_chest_debug"
  imagePath = null

  id = ""
  entitlementId = ""
  categoryId = [-1]
  releaseDate = 0
  price = 0.0         // Price with discount as number
  listPrice = 0.0     // Original price without discount as number
  priceText = ""      // Price with discount as string
  listPriceText = ""  // Original price without discount as string
  currencyCode = ""
  isPurchasable = false
  isBought = false
  name = ""
  shortName = ""
  description = ""
  isBundle = false
  isPartOfAnyBundle = false
  consumableQuantity = 0
  signedOffer = "" //for direct purchase

  amount = ""

  isMultiConsumable = false
  needHeader = true

  constructor(blk)
  {
    id = blk.getBlockName()
    entitlementId = getEntitlementId(id)

    let xbItemType = blk?.MediaItemType
    isMultiConsumable = xbItemType == xboxMediaItemType.GameConsumable
    if (isMultiConsumable)
      defaultIconStyle = "reward_gold"

    categoryId = [xbItemType]
    let entConfig = getEntitlementConfig(entitlementId)
    if ("aircraftGift" in entConfig)
      categoryId = entConfig.aircraftGift.map(@(unitId) ::getAircraftByName(unitId)?.unitType.typeName)
    else if (!isMultiConsumable)
      ::dagor.debug($"[XBOX SHOP ITEM] not found aircraftGift in entitlementConfig, {entitlementId}, {id}")

    name = blk?.Name ?? ""
    //HACK: On GDK no param ReducedName, c++ code copy to this key original name
    //Because of difficulties in searching packs by game title on xbox store
    //We don't want to change packs names
    //So have to try cut prefix if ReducedName is equal as Name
    //On XDK they are different and correct
    shortName = blk?.ReducedName == name ? cutPrefix(name, XBOX_SHORT_NAME_PREFIX_CUT, "") : (blk?.ReducedName ?? "")
    description = blk?.Description ?? ""

    releaseDate = blk?.ReleaseDate ?? 0

    price = blk?.Price ?? 0.0
    priceText = price == 0.0 ? ::loc("shop/free") : (blk?.DisplayPrice ?? "")
    listPrice = blk?.ListPrice ?? 0.0
    listPriceText = blk?.DisplayListPrice ?? ""
    currencyCode = blk?.CurrencyCode ?? ""

    isPurchasable = blk?.IsPurchasable ?? false
    isBundle = blk?.IsBundle ?? false
    isPartOfAnyBundle = blk?.IsPartOfAnyBundle ?? false
    isBought = !!blk?.isBought

    consumableQuantity = blk?.ConsumableQuantity ?? 0
    signedOffer = blk?.SignedOffer ?? ""

    needHeader = isPurchasable

    if (isPurchasable)
      amount = getPriceText()

    let xboxShopBlk = GUI.get()?.xbox_ingame_shop
    let ingameShopImages = xboxShopBlk?.items
    if (ingameShopImages?[id] && xboxShopBlk?.mainPart && xboxShopBlk?.fileExtension)
      imagePath = "!" + xboxShopBlk.mainPart + id + xboxShopBlk.fileExtension
  }

  getPriceText = function() {
    if (price == null)
      return ""

    return ::colorize(
      haveDiscount()? "goodTextColor" : "",
      price == 0.0? ::loc("shop/free") : $"{price} {currencyCode}"
    )
  }

  updateIsBoughtStatus = @() isBought = isMultiConsumable? false : ::xbox_is_item_bought(id)
  haveDiscount = @() price != null && listPrice != null && !isBought && listPrice > 0.0 && price != listPrice
  getDiscountPercent = function() {
    if (price == null || listPrice == null)
      return 0

    return calcPercent(1 - (price.tofloat() / listPrice))
  }

  getDescription = @() description

  getViewData = @(params = {}) {
    isAllBought = isBought
    price = getPriceText()
    layered_image = getIcon()
    enableBackground = true
    isInactive = isInactive()
    isItemLocked = !isPurchasable
    itemHighlight = isBought
    needAllBoughtIcon = true
    headerText = shortName
  }.__merge(params)

  getItemsView = @() getEntitlementView(entitlementId)

  isCanBuy = @() isPurchasable && !isBought
  isInactive = @() !isPurchasable || isBought

  getIcon = @(...) imagePath ? ::LayersIcon.getCustomSizeIconData(imagePath, "pw, ph")
                             : ::LayersIcon.getIconData(null, null, 1.0, defaultIconStyle)

  getSeenId = @() id.tostring()
  canBeUnseen = @() isBought
  showDetails = function(metricPlaceCall = "ingame_store") {
    statsd.send_counter($"sq.{metricPlaceCall}.open_product", 1)
    ::add_big_query_record("open_product",
      ::save_to_json({
        itemId = id
      })
    )
    ::xbox_show_details(id)
  }
  showDescription = @() null
}

return XboxShopPurchasableItem