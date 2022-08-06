let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let isInBattleState = ::Watched(::is_in_flight())

addListenersWithoutEnv({
  LoadingStateChange = @(_) isInBattleState(::is_in_flight())
})

return {
  isInBattleState
}