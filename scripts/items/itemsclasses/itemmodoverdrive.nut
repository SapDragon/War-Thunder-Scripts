let BaseItemModClass = require("%scripts/items/itemsClasses/itemModBase.nut")

::items_classes.ModOverdrive <- class extends BaseItemModClass
{
  static iType = itemType.MOD_OVERDRIVE
  static defaultLocId = "modOverdrive"
  static defaultIcon = "#ui/gameuiskin#overdrive_upgrade_bg.png"
  static typeIcon = "#ui/gameuiskin#item_type_overdrive.svg"

  canBuy = true
  allowBigPicture = false
  isActiveOverdrive = false

  constructor(blk, invBlk = null, slotData = null)
  {
    base.constructor(blk, invBlk, slotData)

    isActiveOverdrive = slotData?.isActive ?? false
  }

  getConditionsBlk = @(configBlk) configBlk?.modOverdriveParams
  canActivate = @() isInventoryItem && !isActive()
  isActive = @(...) isActiveOverdrive

  getIconMainLayer = @() ::LayersIcon.findLayerCfg("mod_overdrive")

  function getMainActionData(isShort = false, params = {})
  {
    if (amount && canActivate())
      return {
        btnName = ::loc("item/activate")
      }

    return base.getMainActionData(isShort, params)
  }

  function doMainAction(cb, handler, params = null)
  {
    if (canActivate())
      return activate(cb, handler)
    return base.doMainAction(cb, handler, params)
  }

  function activate(cb, handler = null)
  {
    let uid = uids?[0]
    if (uid == null)
      return false

    let item = this
    let successCb = function() {
      if (cb)
        cb({ success = true, item = item })
      ::broadcastEvent("OverdriveActivated")
    }

    let blk = ::DataBlock()
    blk.uid = uid
    let taskId = ::char_send_blk("cln_activate_mod_overdrive_item", blk)
    return ::g_tasker.addTask(
      taskId,
      {
        showProgressBox = true
        progressBoxDelayedButtons = 30
      },
      successCb
    )
  }
}