let function giveUnlocksAbTestOnce(abTestBlk)
{
  let unlocksList = abTestBlk.unlocks
  let unlockId = unlocksList?[(::my_user_id_int64 % abTestBlk.divider).tostring()]
  if (!unlockId || ::is_unlocked_scripted(::UNLOCKABLE_ACHIEVEMENT, unlockId))
    return

  for(local i = 0; i < unlocksList.paramCount(); i++)
    if (::is_unlocked_scripted(::UNLOCKABLE_ACHIEVEMENT, unlocksList.getParamValue(i)))
      return

  ::req_unlock_by_client(unlockId, false)
}

let function checkUnlocksByAbTestList()
{
  let abTestUnlocksListByUsersGroups = ::get_gui_regional_blk()?.abTestUnlocksListByUsersGroups
  if (!abTestUnlocksListByUsersGroups)
    return

  foreach (abTestBlk in (abTestUnlocksListByUsersGroups % "abTest"))
    giveUnlocksAbTestOnce(abTestBlk)
}

return checkUnlocksByAbTestList
