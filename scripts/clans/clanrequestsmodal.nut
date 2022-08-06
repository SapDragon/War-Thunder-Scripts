let clanContextMenu = require("%scripts/clans/clanContextMenu.nut")

::showClanRequests <- function showClanRequests(candidatesData, clanId, owner)
{
  ::gui_start_modal_wnd(::gui_handlers.clanRequestsModal,
    {
      candidatesData = candidatesData,
      owner = owner
      clanId = clanId
    });
    ::g_clans.markClanCandidatesAsViewed()
}

::gui_handlers.clanRequestsModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/clans/clanRequests.blk";
  owner = null;
  rowTexts = [];
  candidatesData = null;
  candidatesList = [];
  myRights = [];
  curCandidate = null;
  memListModified = false
  curPage = 0
  rowsPerPage = 10
  clanId = "-1"

  function initScreen()
  {
    myRights = ::g_clans.getMyClanRights()
    memListModified = false
    let isMyClan = !::my_clan_info ? false : (::my_clan_info.id == clanId ? true : false)
    clanId = isMyClan ? "-1" : clanId
    fillRequestList()
  }

  function fillRequestList()
  {
    rowTexts = [];
    candidatesList = [];

    foreach(candidate in candidatesData)
    {
      let rowTemp = {};
      foreach(item in ::clan_candidate_list)
      {
        let value = item.id in candidate ? candidate[item.id] : 0
        rowTemp[item.id] <- {value = value, text = item.type.getShortTextByValue(value)}
      }
      candidatesList.append({nick = candidate.nick, uid = candidate.uid });
      rowTexts.append(rowTemp);
    }
    //dlog("GP: candidates texts");
    //debugTableData(rowTexts);

    updateRequestList()
  }

  function updateRequestList()
  {
    if (!::checkObj(scene))
      return;

    if (curPage > 0 && rowTexts.len() <= curPage * rowsPerPage)
      curPage--

    let tblObj = scene.findObject("candidatesList");
    local data = "";

    let headerRow = [];
    foreach(item in ::clan_candidate_list)
    {
      let name = "#clan/" + (item.id == "date" ? "requestDate" : item.id);
      headerRow.append({
        id = item.id,
        text = name,
        tdalign="center",
      });
    }
    data = buildTableRow("row_header", headerRow, null,
      "enable:t='no'; commonTextColor:t='yes'; bigIcons:t='yes'; style:t='height:0.05sh;'; ");

    let startIdx = curPage * rowsPerPage
    let lastIdx = min((curPage + 1) * rowsPerPage, rowTexts.len())
    for(local i=startIdx; i < lastIdx; i++)
    {
      let rowName = "row_"+i;
      let rowData = [];

      foreach(item in ::clan_candidate_list)
      {
        rowData.append({
          id = item.id,
          text = "",
        });
      }
      data += buildTableRow(rowName, rowData, (i-startIdx)%2==0, "");
    }

    guiScene.setUpdatesEnabled(false, false);
    guiScene.replaceContentFromText(tblObj, data, data.len(), this);

    for(local i=startIdx; i < lastIdx; i++)
    {
      let row = rowTexts[i]
      foreach(item, itemValue in row)
        tblObj.findObject("row_"+i).findObject("txt_"+item).setValue(itemValue.text);
    }

    tblObj.setValue(1) //after header
    guiScene.setUpdatesEnabled(true, true);
    ::move_mouse_on_child_by_value(tblObj)
    onSelect()

    generatePaginator(scene.findObject("paginator_place"), this, curPage, ((rowTexts.len()-1) / rowsPerPage).tointeger())
  }

  function goToPage(obj)
  {
    curPage = obj.to_page.tointeger()
    updateRequestList()
  }

  function onSelect()
  {
    curCandidate = null;
    if (candidatesList && candidatesList.len()>0)
    {
      let objTbl = scene.findObject("candidatesList");
      let index = objTbl.getValue() + curPage*rowsPerPage - 1; //header
      if (index in candidatesList)
        curCandidate = candidatesList[index];
    }
    this.showSceneBtn("btn_approve", !::show_console_buttons && curCandidate != null && (isInArray("MEMBER_ADDING", myRights) || ::clan_get_admin_editor_mode()))
    this.showSceneBtn("btn_reject", !::show_console_buttons && curCandidate != null && isInArray("MEMBER_REJECT", myRights))
    this.showSceneBtn("btn_user_options", curCandidate != null && ::show_console_buttons)
  }

  function onUserCard()
  {
    if (curCandidate)
      ::gui_modal_userCard({ uid = curCandidate.uid })
  }

  function onUserRClick()
  {
    openUserPopupMenu()
  }

  function onUserAction()
  {
    let table = scene.findObject("candidatesList")
    if (!::checkObj(table))
      return

    let index = table.getValue()
    if (index < 0 || index >= table.childrenCount())
      return

    let position = table.getChild(index).getPosRC()
    openUserPopupMenu(position)
  }

  function openUserPopupMenu(position = null)
  {
    if (!curCandidate)
      return

    let menu = clanContextMenu.getRequestActions(clanId, curCandidate.uid, curCandidate?.nick, this)
    ::gui_right_click_menu(menu, this, position)
  }

  function onRequestApprove()
  {
    ::g_clans.approvePlayerRequest(curCandidate.uid, clanId)
  }

  function onRequestReject()
  {
    ::g_clans.rejectPlayerRequest(curCandidate.uid, clanId)
  }

  function hideCandidateByName(name)
  {
    if (!name)
      return

    memListModified = true
    foreach(idx, candidate in rowTexts)
      if (candidate.nick.value == name)
      {
        rowTexts.remove(idx)
        foreach(cIdx, player in candidatesList)
          if (player.nick == name)
          {
            candidatesList.remove(cIdx)
            break
          }
        break
      }

    if (rowTexts.len() > 0)
      updateRequestList()
    else
      goBack()
  }

  function afterModalDestroy()
  {
    if(memListModified)
    {
      if(::clan_get_admin_editor_mode() && (owner && "reinitClanWindow" in owner))
        owner.reinitClanWindow()
      //else
      //  ::requestMyClanData(true)
    }
  }

  function onDeleteFromBlacklist(){}

  function onEventClanCandidatesListChanged(p)
  {
    let uid = p?.userId
    let candidate = ::u.search(candidatesList, @(candidate) candidate.uid == uid )
    hideCandidateByName(candidate?.nick)
  }
}
