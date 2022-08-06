let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { setColoredDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let mkHoverHoldAction = require("%sqDagui/timer/mkHoverHoldAction.nut")

::gui_handlers.IngameConsoleStore <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/items/itemsShop.blk"

  itemsCatalog = null
  chapter = null
  afterCloseFunc = null

  seenList = null
  sheetsArray = null

  titleLocId = ""
  storeLocId = ""
  openStoreLocId = ""
  seenEnumId = "other" // replacable

  curSheet = null
  curSheetId = null
  curItem = null

  itemsPerPage = -1
  itemsList = null
  curPage = 0

  navItems  = null
  navigationHandlerWeak = null
  headerOffsetX = null
  isNavCollapsed = false

  // Used to avoid expensive get...List and further sort.
  itemsListValid = false

  sortBoxId = "sort_params_list"
  lastSorting = 0

  needWaitIcon = false
  isLoadingInProgress = false
  hoverHoldAction = null
  isMouseMode = true

  function initScreen()
  {
    updateMouseMode()
    updateShowItemButton()
    let infoObj = scene.findObject("item_info")
    guiScene.replaceContent(infoObj, "%gui/items/itemDesc.blk", this)

    let titleObj = scene.findObject("wnd_title")
    titleObj.setValue(::loc(titleLocId))

    ::show_obj(getTabsListObj(), false)
    ::show_obj(getSheetsListObj(), false)
    hoverHoldAction = mkHoverHoldAction(scene.findObject("hover_hold_timer"))

    fillItemsList()
    moveMouseToMainList()
  }

  function reinitScreen(params)
  {
    itemsCatalog = params?.itemsCatalog
    curItem = params?.curItem ?? curItem
    itemsListValid = false
    applyFilters()
    moveMouseToMainList()
  }

  function fillItemsList()
  {
    initNavigation()
    initSheets()
  }

  function initSheets()
  {
    if (!sheetsArray.len() && isLoadingInProgress)
    {
      fillPage()
      return
    }

    navItems = []
    foreach(idx, sh in sheetsArray)
    {
      if (curSheetId && curSheetId == sh.categoryId)
        curSheet = sh

      if (!curSheet && ::isInArray(chapter, sh.contentTypes))
        curSheet = sh

      navItems.append({
        idx = idx
        text = sh?.locText ?? ::loc(sh.locId)
        unseenIconId = "unseen_icon"
        unseenIcon = bhvUnseen.makeConfigStr(seenEnumId, sh.getSeenId())
      })
    }

    if (navigationHandlerWeak)
      navigationHandlerWeak.setNavItems(navItems)

    let sheetIdx = sheetsArray.indexof(curSheet) ?? 0
    getSheetsListObj().setValue(sheetIdx)

    //Update this objects only once. No need to do it on each updateButtons
    this.showSceneBtn("btn_preview", false)
    let warningTextObj = scene.findObject("warning_text")
    if (::checkObj(warningTextObj))
      warningTextObj.setValue(::colorize("warningTextColor", ::loc("warbond/alreadyBoughtMax")))

    applyFilters()
  }

  function initNavigation()
  {
    let handler = ::handlersManager.loadHandler(
      ::gui_handlers.navigationPanel,
      { scene                  = scene.findObject("control_navigation")
        onSelectCb             = ::Callback(doNavigateToSection, this)
        onClickCb              = ::Callback(onItemClickCb, this)
        onCollapseCb           = ::Callback(onNavCollapseCb, this)
        needShowCollapseButton = true
        headerHeight           = "1@buttonHeight"
      })
    registerSubHandler(navigationHandlerWeak)
    navigationHandlerWeak = handler.weakref()
    headerOffsetX = handler.headerOffsetX
  }

  function doNavigateToSection(obj) {
    if (obj?.isCollapsable)
      return

    markCurrentPageSeen()

    let newSheet = sheetsArray?[obj.idx]
    if (!newSheet)
      return

    curSheet = newSheet
    itemsListValid = false

    if (obj?.subsetId)
    {
      subsetList = curSheet.getSubsetsListParameters().subsetList
      curSubsetId = initSubsetId ?? obj.subsetId
      initSubsetId = null
      curSheet.setSubset(curSubsetId)
    }

    applyFilters()
  }

  function onItemClickCb(obj)
  {
    if (!obj?.isCollapsable || !navigationHandlerWeak)
      return

    let collapseBtnObj = scene.findObject($"btn_nav_{obj.idx}")
    let subsetId = curSubsetId
    navigationHandlerWeak.onCollapse(collapseBtnObj)
    if (collapseBtnObj.getParent().collapsed == "no")
      getSheetsListObj().setValue(//set selection on chapter item if not found item with subsetId just in case to avoid crash
        ::u.search(navItems, @(item) item?.subsetId == subsetId)?.idx ?? obj.idx)
  }

  function recalcCurPage() {
    let lastIdx = itemsList.findindex(function(item) { return item.id == curItem?.id}.bindenv(this)) ?? -1
    if (lastIdx > 0)
      curPage = getPageNum(lastIdx)
    else if (curPage * itemsPerPage > itemsList.len())
      curPage = max(0, getPageNum(itemsList.len() - 1))
  }

  function applyFilters()
  {
    initItemsListSizeOnce()
    if (!itemsListValid)
    {
      itemsListValid = true
      loadCurSheetItemsList()
      updateSortingList()
    }

    recalcCurPage()
    fillPage()
  }

  function fillPage()
  {
    let view = { items = [], hasFocusBorder = true, onHover = "onItemHover" }

    if (!isLoadingInProgress)
    {
      let pageStartIndex = curPage * itemsPerPage
      let pageEndIndex = min((curPage + 1) * itemsPerPage, itemsList.len())
      for (local i=pageStartIndex; i < pageEndIndex; i++)
      {
        let item = itemsList[i]
        if (!item)
          continue
        view.items.append(item.getViewData({
          itemIndex = i.tostring(),
          unseenIcon = item.canBeUnseen()? null : bhvUnseen.makeConfigStr(seenEnumId, item.getSeenId())
        }))
      }
    }

    let listObj = getItemsListObj()
    let prevValue = listObj.getValue()
    let data = ::handyman.renderCached(("%gui/items/item"), view)
    let isEmptyList = data.len() == 0 || isLoadingInProgress

    this.showSceneBtn("sorting_block", !isEmptyList)
    ::show_obj(listObj, !isEmptyList)
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    let emptyListObj = scene.findObject("empty_items_list")
    ::show_obj(emptyListObj, isEmptyList)
    ::show_obj(emptyListObj.findObject("loadingWait"), isEmptyList && needWaitIcon && isLoadingInProgress)

    this.showSceneBtn("items_shop_to_marketplace_button", false)
    this.showSceneBtn("items_shop_to_shop_button", false)
    let emptyListTextObj = scene.findObject("empty_items_list_text")
    emptyListTextObj.setValue(::loc($"items/shop/emptyTab/default{isLoadingInProgress ? "/loading" : ""}"))

    if (isLoadingInProgress)
      ::hidePaginator(scene.findObject("paginator_place"))
    else {
      recalcCurPage()
      generatePaginator(scene.findObject("paginator_place"), this,
        curPage, getPageNum(itemsList.len() - 1), null, true /*show last page*/)
    }

    if (!itemsList?.len() && sheetsArray.len())
      focusSheetsList()

    if (!isLoadingInProgress)
    {
      let value = findLastValue(prevValue)
      if (value >= 0)
        listObj.setValue(value)
    }
  }

  focusSheetsList = @() ::move_mouse_on_child_by_value(getSheetsListObj())

  function findLastValue(prevValue)
  {
    let offset = curPage * itemsPerPage
    let total = clamp(itemsList.len() - offset, 0, itemsPerPage)
    if (!total)
      return 0

    local res = clamp(prevValue, 0, total - 1)
    if (curItem)
      for(local i = 0; i < total; i++)
      {
        let item = itemsList[offset + i]
        if (curItem.id != item.id)
          continue
        res = i
      }
    return res
  }

  function goToPage(obj)
  {
    markCurrentPageSeen()
    curItem = null
    curPage = obj.to_page.tointeger()
    fillPage()
  }

  function onItemAction(buttonObj)
  {
    let id = buttonObj?.holderId
    if (id == null)
      return
    let item = ::getTblValue(id.tointeger(), itemsList)
    onShowDetails(item)
  }

  function onMainAction(obj)
  {
    onShowDetails()
  }

  function onAltAction(obj)
  {
    let item = getCurItem()
    if (!item)
      return

    item.showDescription()
  }

  function onShowDetails(item = null)
  {
    item = item || getCurItem()
    if (!item)
      return

    item.showDetails()
  }

  function onNavCollapseCb (isCollapsed)
  {
    isNavCollapsed = isCollapsed
    applyFilters()
  }

  function initItemsListSizeOnce()
  {
    let listObj = getItemsListObj()
    let emptyListObj = scene.findObject("empty_items_list")
    let infoObj = scene.findObject("item_info_nest")
    let collapseBtnWidth = $"1@cIco+2*({headerOffsetX})"
    let leftPos = isNavCollapsed ? collapseBtnWidth : "0"
    let nawWidth = isNavCollapsed ? "0" : "1@defaultNavPanelWidth"
    let itemHeightWithSpace = "1@itemHeight+1@itemSpacing"
    let itemWidthWithSpace = "1@itemWidth+1@itemSpacing"
    let mainBlockHeight = "@rh-2@frameHeaderHeight-1@fontHeightMedium-1@frameFooterHeight-1@bottomMenuPanelHeight-1@blockInterval"
    let itemsCountX = max(::to_pixels($"@rw-1@shopInfoMinWidth-({leftPos})-({nawWidth})")
      / max(1, ::to_pixels(itemWidthWithSpace)), 1)
    let itemsCountY = max(::to_pixels(mainBlockHeight)
      / max(1, ::to_pixels(itemHeightWithSpace)), 1)
    let contentWidth = $"{itemsCountX}*({itemWidthWithSpace})+1@itemSpacing"
    scene.findObject("main_block").height = mainBlockHeight
    scene.findObject("paginator_place").left = $"0.5({contentWidth})-0.5w+{leftPos}+{nawWidth}"
    listObj.width = contentWidth
    listObj.left = leftPos
    emptyListObj.width = contentWidth
    emptyListObj.left = leftPos
    infoObj.left = leftPos
    infoObj.width = "fw"
    itemsPerPage = (itemsCountX * itemsCountY ).tointeger()
  }

  function onChangeSortParam(obj)
  {
    let val = ::get_obj_valid_index(obj)
    lastSorting = val < 0 ? 0 : val
    updateSorting()
    applyFilters()
  }

  function updateSortingList()
  {
    let obj = scene.findObject("sorting_block_bg")
    if (!::checkObj(obj))
      return

    let curVal = lastSorting
    let view = {
      id = sortBoxId
      btnName = "Y"
      funcName = "onChangeSortParam"
      values = curSheet?.sortParams.map(@(p, idx) {
        text = "{0} ({1})".subst(::loc($"items/sort/{p.param}"), ::loc(p.asc? "items/sort/ascending" : "items/sort/descending"))
        isSelected = curVal == idx
      }) ?? []
    }

    let data = ::handyman.renderCached("%gui/commonParts/comboBox", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
    getSortListObj().setValue(curVal)
  }

  function updateSorting()
  {
    if (!curSheet)
      return

    let sortParam = getSortParam()
    let isAscendingSort = sortParam.asc
    let sortSubParam = curSheet.sortSubParam
    itemsList.sort(function(a, b) {
      return sortOrder(a, b, isAscendingSort, sortParam.param, sortSubParam)
    }.bindenv(this))
  }

  function sortOrder(a, b, isAscendingSort, sortParam, sortSubParam)
  {
    return (isAscendingSort? 1: -1) * (a[sortParam] <=> b[sortParam]) || a[sortSubParam] <=> b[sortSubParam]
  }

  function getSortParam()
  {
    return curSheet?.sortParams[getSortListObj().getValue()]
  }

  function markCurrentPageSeen()
  {
    if (!itemsList)
      return

    let pageStartIndex = curPage * itemsPerPage
    let pageEndIndex = min((curPage + 1) * itemsPerPage, itemsList.len())
    let list = []
    for (local i = pageStartIndex; i < pageEndIndex; ++i)
      list.append(itemsList[i].getSeenId())

    seenList.markSeen(list)
  }

  function updateItemInfo()
  {
    let item = getCurItem()
    fillItemInfo(item)
    this.showSceneBtn("jumpToDescPanel", ::show_console_buttons && item != null)
    updateButtons()

    if (!item && !isLoadingInProgress)
      return

    curItem = item
    markItemSeen(item)
  }

  function fillItemInfo(item)
  {
    let descObj = scene.findObject("item_info")

    local obj = null

    obj = descObj.findObject("item_name")
    obj.setValue(item?.name ?? "")

    obj = descObj.findObject("item_desc_div")
    let itemsView = item?.getItemsView() ?? ""
    let data = $"{getPriceBlock(item)}{itemsView}"
    guiScene.replaceContentFromText(obj, data, data.len(), this)

    obj = descObj.findObject("item_desc_under_div")
    obj.setValue(item?.getDescription() ?? "")

    obj = descObj.findObject("item_icon")
    let imageData = item?.getBigIcon() ?? item?.getIcon() ?? ""
    obj.wideSize = "yes"
    let showImageBlock = imageData.len() != 0
    obj.show(showImageBlock)
    guiScene.replaceContentFromText(obj, imageData, imageData.len(), this)
  }

  function getPriceBlock(item)
  {
    if (item?.isBought)
      return ""
    //Generate price string as PSN requires and return blk format to replace it.
    return handyman.renderCached("%gui/commonParts/discount", item)
  }

  function updateButtonsBar() {
    let obj = getItemsListObj()
    let isButtonsVisible = isMouseMode || (::check_obj(obj) && obj.isHovered())
    this.showSceneBtn("item_actions_bar", isButtonsVisible)
    return isButtonsVisible
  }

  function updateButtons()
  {
    if (!updateButtonsBar())
      return

    let item = getCurItem()
    let showMainAction = item != null && !item.isBought
    let buttonObj = this.showSceneBtn("btn_main_action", showMainAction)
    if (showMainAction)
    {
      buttonObj.visualStyle = "secondary"
      setColoredDoubleTextToButton(scene, "btn_main_action", ::loc(storeLocId))
    }

    let showSecondAction = openStoreLocId != "" && (item?.isBought ?? false)
    this.showSceneBtn("btn_alt_action", showSecondAction)
    if (showSecondAction)
      setColoredDoubleTextToButton(scene, "btn_alt_action", ::loc(openStoreLocId))

    this.showSceneBtn("warning_text", showSecondAction)
  }

  function markItemSeen(item)
  {
    if (item)
      seenList.markSeen(item.getSeenId())
  }

  function getCurItem()
  {
    if (isLoadingInProgress)
      return null

    let obj = getItemsListObj()
    if (!::check_obj(obj))
      return null

    return itemsList?[obj.getValue() + curPage * itemsPerPage]
  }

  function getCurItemObj()
  {
    let itemListObj = getItemsListObj()
    let value = ::get_obj_valid_index(itemListObj)
    if (value < 0)
      return null

    return itemListObj.getChild(value)
  }

  getPageNum = @(itemsIdx) ::ceil(itemsIdx.tofloat() / itemsPerPage).tointeger() - 1

  onTabChange = @() null
  onToShopButton = @(obj) null
  onToMarketplaceButton = @(obj) null
  onLinkAction = @(obj) null
  onItemPreview = @(obj) null
  onOpenCraftTree = @(obj) null
  onShowSpecialTasks = @(obj) null
  onShowBattlePass = @(obj) null

  getTabsListObj = @() scene.findObject("tabs_list")
  getSheetsListObj = @() scene.findObject("nav_list")
  getSortListObj = @() scene.findObject(sortBoxId)
  getItemsListObj = @() scene.findObject("items_list")
  moveMouseToMainList = @() ::move_mouse_on_child_by_value(getItemsListObj())

  function goBack()
  {
    markCurrentPageSeen()
    base.goBack()
  }

  function afterModalDestroy()
  {
    if (afterCloseFunc)
      afterCloseFunc()
  }

  function onItemsListFocusChange()
  {
    if (isValid())
      updateItemInfo()
  }

  function onJumpToDescPanelAccessKey(obj)
  {
    if (!::show_console_buttons)
      return
    let containerObj = scene.findObject("item_info")
    if (::check_obj(containerObj) && containerObj.isHovered())
      ::move_mouse_on_obj(getCurItemObj())
    else
      ::move_mouse_on_obj(containerObj)
  }

  function onItemHover(obj) {
    if (!::show_console_buttons)
      return
    let wasMouseMode = isMouseMode
    updateMouseMode()
    if (wasMouseMode != isMouseMode)
      updateShowItemButton()
    if (isMouseMode)
      return

    if (obj.holderId == getCurItemObj()?.holderId)
      return
    hoverHoldAction(obj, function(focusObj) {
      let idx = focusObj.holderId.tointeger()
      let value = idx - curPage * itemsPerPage
      let listObj = getItemsListObj()
      if (listObj.getValue() != value && value >= 0 && value < listObj.childrenCount())
        listObj.setValue(value)
    }.bindenv(this))
  }

  updateMouseMode = @() isMouseMode = !::show_console_buttons || ::is_mouse_last_time_used()
  function updateShowItemButton() {
    let listObj = getItemsListObj()
    if (listObj?.isValid())
      listObj.showItemButton = isMouseMode ? "yes" : "no"
  }
}
