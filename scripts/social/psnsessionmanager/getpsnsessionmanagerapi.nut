let { isPlatformSony } = require("%scripts/clientState/platform.nut")

let {
  getPreferredVersion = @() -1
} = isPlatformSony
  ? require("%sonyLib/webApi.nut")
  : null

let {
  onPsnInvitation = @(...) null,
  invite = @(...) null,
  checkInvitesAfterFlight = @() null
} = isPlatformSony
  ? ( getPreferredVersion() == 2
      ? require("%scripts/social/psnSessionManager/psnSessionManagerApi.nut")
      : require("%scripts/social/psnSessions.nut")
    )
  : null


return {
  onPsnInvitation
  invite
  checkInvitesAfterFlight
}