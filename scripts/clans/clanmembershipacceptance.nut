let function canChange(clanData)
{
  if (!clanData)
    return false
  if (::clan_get_admin_editor_mode())
    return true
  let isMyClan = clanData.id == ::clan_get_my_clan_id()
  let myRights = isMyClan ? ::clan_get_role_rights(::clan_get_my_role()) : []
  return myRights.indexof("CHANGE_INFO") != null
}

let function getValue(clanData)
{
  return (clanData?.status ?? "closed") != "closed"
}

let function setValue(clanData, value, handler)
{
  if (!canChange(clanData) || value == getValue(clanData))
    return

  let clanId = ::clan_get_admin_editor_mode() ? clanData.id : "-1"
  let isLocking = getValue(clanData)

  handler.taskId = ::clan_request_close_for_new_members(clanId, isLocking)
  if (handler.taskId < 0)
    return

  ::set_char_cb(handler, handler.slotOpCb)
  handler.showTaskProgressBox()
  if (clanId == "-1")
    ::sync_handler_simulate_signal("clan_info_reload")
  handler.afterSlotOp = function() {
    ::broadcastEvent("ClanMembershipAcceptanceChanged")
    handler.msgBox("clan_membership_acceptance",
      ::loc("clan/" + (isLocking ? "was_closed" : "was_opened")), [["ok"]], "ok")
  }
}

return {
  canChange = canChange
  getValue = getValue
  setValue = setValue
}
