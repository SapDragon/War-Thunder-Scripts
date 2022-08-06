let { calcPercent } = require("%sqstd/math.nut")
let psnStore = require("sony.store")
let psnUser = require("sony.user")
let statsd = require("statsd")
let { serviceLabel } = require("%sonyLib/webApi.nut")
let { subscribe } = require("eventbus")
let { GUI } = require("%scripts/utils/configs.nut")
let { targetPlatform } = require("%scripts/clientState/platform.nut")
let { getEntitlementId } = require("%scripts/onlineShop/onlineBundles.nut")
let { getEntitlementView } = require("%scripts/onlineShop/entitlementView.nut")

let IMAGE_TYPE = "TAM_JACKET"
let BQ_DEFAULT_ACTION_ERROR = -1

enum PURCHASE_STATUS {
  PURCHASED = "RED_BAG" // - Already purchased and cannot be purchased again
  PURCHASED_MULTI = "BLUE_BAG" // - Already purchased and can be purchased again
  NOT_PURCHASED = "NONE" // - Not yet purchased
}

let function handleNewPurchase(itemId) {
  ::ps4_update_purchases_on_auth()
  let taskParams = { showProgressBox = true, progressBoxText = ::loc("charServer/checking") }
  ::g_tasker.addTask(::update_entitlements_limited(true), taskParams)
  ::broadcastEvent("PS4ItemUpdate", {id = itemId})
}

let getActionText = @(action) action == psnStore.Action.PURCHASED ? "purchased"
  : action == psnStore.Action.CANCELED ? "canceled"
  : action == BQ_DEFAULT_ACTION_ERROR ? "unknown"
  : "none"

let function sendBqRecord(metric, itemId, result = null) {
  let sendStat = {}

  if (result != null) {
    sendStat["isPlusAuthorized"] <- result?.isPlusAuthorized
    sendStat["action"] <- result?.action ?? BQ_DEFAULT_ACTION_ERROR
  }

  if ("action" in sendStat) {
    sendStat.__update({action = getActionText(sendStat.action)})
    metric.append(sendStat.action)
  }

  let path = ".".join(metric)
  statsd.send_counter($"sq.{path}", 1)
  ::add_big_query_record(path,
    ::save_to_json(sendStat.__merge({
      itemId = itemId
    }))
  )
}


let function reportRecord(data, record_name) {
  sendBqRecord([data.ctx.metricPlaceCall, "checkout.close"], data.ctx.itemId, data.result)
  if (data.result.action == psnStore.Action.PURCHASED)
    handleNewPurchase(data.ctx.itemId)
}

subscribe("storeCheckoutClosed", @(data) reportRecord(data, "checkout.close"))
subscribe("storeDescriptionClosed", @(data) reportRecord(data, "description.close"))


local psnV2ShopPurchasableItem = class {
  defaultIconStyle = "default_chest_debug"
  imagePath = null

  id = ""
  entitlementId = ""
  category = ""
  srvLabel = serviceLabel
  releaseDate = 0
  price = 0           // Price with discount as number
  listPrice = 0       // Original price without discount as number
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
  productId = ""

  amount = ""

  isMultiConsumable = false
  needHeader = true

  skuInfo = null

  constructor(blk, v_releaseDate) {
    id = blk.label
    entitlementId = getEntitlementId(id)
    name = blk.displayName
    category = blk?.category ?? ""
    description = blk?.description ?? ""
    releaseDate = v_releaseDate //PSN not give releaseDate param. but it return data in sorted order by release date

    let imagesArray = blk?.media.images != null ? (blk.media.images % "array") : []
    let imageIndex = imagesArray.findindex(@(t) t.type == IMAGE_TYPE)

    let psnShopBlk = GUI.get()?.ps4_ingame_shop
    if (imageIndex != null && imagesArray[imageIndex]?.url)
      imagePath = $"{imagesArray[imageIndex].url}?P1"
    else if (psnShopBlk?.mainPart != null && psnShopBlk?.fileExtension != null)
      imagePath = $"!{psnShopBlk.mainPart}{id}{psnShopBlk.fileExtension}"

    let customServiceLabelBlk = psnShopBlk?.customServiceLabel[targetPlatform]
    if (customServiceLabelBlk)
      srvLabel = customServiceLabelBlk?[id] ?? serviceLabel

    updateSkuInfo(blk)
  }

  function updateSkuInfo(blk) {
    skuInfo = (blk?.skus.blockCount() ?? 0) > 0? blk.skus.getBlock(0) : ::DataBlock()
    let userHasPlus = psnUser.hasPremium()
    let isPlusPrice = skuInfo?.isPlusPrice ?? false
    let displayPrice = skuInfo?.displayPrice ?? ""
    let skuPrice = skuInfo?.price

    priceText = (!userHasPlus && isPlusPrice) ? (skuInfo?.displayOriginalPrice ?? "")
      : (userHasPlus && !isPlusPrice) ? (skuInfo?.displayPlusUpsellPrice ?? displayPrice)
      : displayPrice
    listPriceText = skuInfo?.displayOriginalPrice ?? skuInfo?.displayPrice ?? priceText

    price = (!userHasPlus && isPlusPrice) ? skuInfo?.originalPrice
      : (userHasPlus && !isPlusPrice) ? (skuInfo?.plusUpsellPrice ?? skuPrice)
      : skuPrice
    listPrice = skuInfo?.originalPrice ?? skuInfo?.price ?? price

    needHeader = price != null && listPrice != null

    productId = skuInfo?.id
    let purchStatus = skuInfo?.annotationName ?? PURCHASE_STATUS.NOT_PURCHASED
    isBought = purchStatus == PURCHASE_STATUS.PURCHASED
    isPurchasable = purchStatus != PURCHASE_STATUS.PURCHASED
    isMultiConsumable = (skuInfo?.useLimit ?? 0) > 0
    if (isMultiConsumable)
      defaultIconStyle = "reward_gold"
  }

  haveDiscount = @() !isBought && price != null && listPrice != null && price != listPrice
  havePsPlusDiscount = @() psnUser.hasPremium() && ("displayPlusUpsellPrice" in skuInfo || skuInfo?.isPlusPrice) //use in markup
  getDiscountPercent = @() (price == null && listPrice == null)? 0 : calcPercent(1 - (price.tofloat() / listPrice))

  getPriceText = function() {
    if (priceText == "")
      return ""

    let color = !haveDiscount() ? ""
      : havePsPlusDiscount() ? "psplusTextColor"
      : "goodTextColor"

    return ::colorize(color, priceText)
  }

  getDescription = function() {
    //TEMP HACK!!! for PS4 TRC R4052A, to show all symbols of a single 2000-letter word
    let maxSymbolsInLine = 50 // Empirically fits with the biggest font we have
    if (description.len() > maxSymbolsInLine && description.indexof(" ") == null) {
      let splitDesc = [description.slice(0, maxSymbolsInLine)]
      let len = description.len()
      let totalLines = (len / maxSymbolsInLine).tointeger() + 1
      for (local i = 1; i < totalLines; i++) {
        splitDesc.append("\n")
        splitDesc.append(description.slice(i * maxSymbolsInLine, (i+1) * maxSymbolsInLine))
      }
      return "".join(splitDesc)
    }

    return description
  }

  getViewData = @(params = {}) {
    isAllBought = isBought
    price = getPriceText()
    layered_image = getIcon()
    enableBackground = true
    isInactive = isInactive()
    isItemLocked = !isPurchasable
    itemHighlight = isBought
    needAllBoughtIcon = true
    needPriceFadeBG = true
    headerText = shortName
    havePsPlusDiscount = havePsPlusDiscount()
  }.__merge(params)

  getItemsView = @() getEntitlementView(entitlementId)

  isCanBuy = @() isPurchasable && !isBought
  isInactive = @() !isPurchasable || isBought

  getIcon = @(...) imagePath ? ::LayersIcon.getCustomSizeIconData(imagePath, "pw, ph")
                             : ::LayersIcon.getIconData(null, null, 1.0, defaultIconStyle)

  getSeenId = @() id.tostring()
  canBeUnseen = @() isBought
  showDetails = function(metricPlaceCall = "ingame_store.v2") {
    let itemId = id
    let eventData = {itemId = itemId, metricPlaceCall = metricPlaceCall}
    sendBqRecord([metricPlaceCall, "checkout.open"], itemId)
    psnStore.open_checkout(
      [itemId],
      srvLabel,
      "storeCheckoutClosed",
      eventData
    )
  }
  showDescription = function(metricPlaceCall = "ingame_store.v2") {
    let itemId = id
    let eventData = {itemId = itemId, metricPlaceCall = metricPlaceCall}
    sendBqRecord([metricPlaceCall, "description.open"], itemId)
    psnStore.open_product(
      itemId,
      srvLabel,
      "storeDescriptionClosed",
      eventData
    )
  }
}

return psnV2ShopPurchasableItem
