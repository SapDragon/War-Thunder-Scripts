let { openUrl } = require("%scripts/onlineShop/url.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { havePlayerTag } = require("%scripts/user/userUtils.nut")
let { setColoredDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { register_command } = require("console")
let { isPlayerRecommendedEmailRegistration } = require("%scripts/user/playerCountry.nut")

let canEmailRegistration = isPlatformSony ? @() havePlayerTag("psnlogin")
  : isPlatformXboxOne ? @() havePlayerTag("livelogin") && ::has_feature("AllowXboxAccountLinking")
  : ::steam_is_running() ? @() havePlayerTag("steamlogin") && ::has_feature("AllowSteamAccountLinking")
  : @() false

let function launchSteamEmailRegistration() {
  let token = ::get_steam_link_token()
  if (token == "")
    return ::dagor.debug("Steam Email Registration: empty token")

  openUrl(::loc("url/steam_bind_url",
    {
      token = token,
      langAbbreviation = ::g_language.getShortName()
    }),
    false, false, "profile_page")
}

let function checkAutoShowSteamEmailRegistration() {
  if (!canEmailRegistration())
    return

  if (::g_language.getLanguageName() != "Japanese") {
    if (::loadLocalByAccount("SteamEmailRegistrationShowed", false))
      return

    ::saveLocalByAccount("SteamEmailRegistrationShowed", true)
  }

  ::showUnlockWnd({
    name = ::loc("mainmenu/SteamEmailRegistration")
    desc = ::loc("mainmenu/SteamEmailRegistration/desc")
    popupImage = "ui/images/invite_big.jpg?P1"
    onOkFunc = launchSteamEmailRegistration
    okBtnText = "msgbox/btn_bind"
  })
}

let launchPS4EmailRegistration = @()
  ::ps4_open_url_logged_in(::loc("url/ps4_bind_url"), ::loc("url/ps4_bind_redirect"))

let function checkAutoShowPS4EmailRegistration() {
  if (!canEmailRegistration())
    return

  if (::loadLocalByAccount("PS4EmailRegistrationShowed", false))
    return

  ::saveLocalByAccount("PS4EmailRegistrationShowed", true)

  ::showUnlockWnd({
    name = ::loc("mainmenu/PS4EmailRegistration")
    desc = ::loc("mainmenu/PS4EmailRegistration/desc")
    popupImage = "ui/images/invite_big.jpg?P1"
    onOkFunc = launchPS4EmailRegistration
    okBtnText = "msgbox/btn_bind"
  })
}

let sendXboxEmailBind = @(val) ::xbox_link_email(val, function(status) {
  ::g_popups.add("", ::colorize(
    status == ::YU2_OK ? "activeTextColor" : "warningTextColor",
    ::loc($"mainmenu/XboxOneEmailRegistration/result/{status}")
  ))
})

let function launchXboxEmailRegistration(override = {}) {
  ::gui_modal_editbox_wnd({
    leftAlignedLabel = true
    title = ::loc("mainmenu/XboxOneEmailRegistration")
    label = ::loc("mainmenu/XboxOneEmailRegistration/desc")
    checkWarningFunc = ::g_string.validateEmail
    allowEmpty = false
    needOpenIMEonInit = false
    editBoxEnableFunc = canEmailRegistration
    editBoxTextOnDisable = ::loc("mainmenu/alreadyBinded")
    editboxWarningTooltip = ::loc("tooltip/invalidEmail/possibly")
    okFunc = @(val) sendXboxEmailBind(val)
  }.__update(override))
}

let function reqUnlockForStartEmailBind() {
  let unlockId = ::get_gui_regional_blk()?.unlockOnStartEmailBind
  if (unlockId == null || ::is_unlocked_scripted(::UNLOCKABLE_ACHIEVEMENT, unlockId))
    return
  ::req_unlock_by_client(unlockId, true)
}

let function forceLauncheSonySuggestionEmailRegistration() {
  let bindBtnId = "bind"
  let msgBox = ::scene_msg_box("recommend_email_registration", null,
    ::loc("mainmenu/recommendEmailRegistration"),
    [
      [bindBtnId, function() {
        reqUnlockForStartEmailBind()
        launchPS4EmailRegistration()
      }],
      ["later", function() {}]
    ], null)
  if (!(msgBox?.isValid() ?? false))
    return

  local btnObj = msgBox.findObject(bindBtnId)
  if (!::check_obj(btnObj))
    return

  btnObj.hideText = "yes"
  local btnTextArea = "textarea { id:t='bind_text';class:t='buttonText';text:t=''}"
  ::get_cur_gui_scene().appendWithBlk(btnObj, btnTextArea, null)
  setColoredDoubleTextToButton(msgBox, bindBtnId, ::loc("msgbox/bind_and_recieve"))
}

let forceLauncheXboxSuggestionEmailRegistration = @()
  launchXboxEmailRegistration({
    leftAlignedLabel = false
    label = ::loc("mainmenu/recommendEmailRegistration")
    okBtnText = ::loc("msgbox/bind_and_recieve")
    okFunc = function(val) {
      reqUnlockForStartEmailBind()
      sendXboxEmailBind(val)
    }
  })

let forceLauncheSuggestionEmailRegistration =
  isPlatformSony ? forceLauncheSonySuggestionEmailRegistration
  : isPlatformXboxOne ? forceLauncheXboxSuggestionEmailRegistration
  : @() null

let function checkForceSuggestionEmailRegistration() {
  if (!canEmailRegistration())
    return

  if (isPlayerRecommendedEmailRegistration())
    forceLauncheSuggestionEmailRegistration()
}

let checkAutoShowEmailRegistration = isPlatformSony ? checkAutoShowPS4EmailRegistration
 : ::steam_is_running() ? checkAutoShowSteamEmailRegistration
 : @() null

let emailRegistrationTooltip = isPlatformSony ? loc("mainmenu/PS4EmailRegistration/desc")
  : isPlatformXboxOne ? loc("mainmenu/XboxOneEmailRegistration/desc")
  : loc("mainmenu/SteamEmailRegistration/desc")

let launchEmailRegistration = isPlatformSony ? launchPS4EmailRegistration
  : isPlatformXboxOne ? launchXboxEmailRegistration
  : ::steam_is_running() ? launchSteamEmailRegistration
  : @() null

addPromoAction("email_registration", @(handler, params, obj) launchEmailRegistration())

let promoButtonId = "email_registration_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  buttonType = "imageButton"
  getText = @() ::loc("promo/btnXBOXAccount_linked")
  image = isPlatformSony ? "https://static.warthunder.ru/upload/image/Promo/2022_03_psn_promo.jpg?P1"
    : isPlatformXboxOne ? "https://static.warthunder.ru/upload/image/Promo/2022_03_xbox_promo.jpg?P1"
    : ::steam_is_running() ? "https://static.warthunder.ru/upload/image/Promo/2022_03_steam_promo.jpg?P1"
    : ""
  aspect_ratio = 2.07
  updateFunctionInHandler = function() {
    let isVisible = isShowAllCheckBoxEnabled()
      || (canEmailRegistration() && ::g_promo.getVisibilityById(promoButtonId))
    ::showBtn(promoButtonId, isVisible, scene)
  }
})

register_command(function(platform) {
  let fn = platform == "xbox" ? forceLauncheXboxSuggestionEmailRegistration
    : platform == "sony" ? forceLauncheSonySuggestionEmailRegistration
    : @() console_print($"is missing suggestion for platform {platform}, available 'xbox', 'sony'")
  fn()
  return console_print($"show suggestion for platform {platform}")
}, "emailRegistration.showForceSuggestion")

return {
  launchEmailRegistration
  canEmailRegistration
  emailRegistrationTooltip
  checkAutoShowEmailRegistration
  checkForceSuggestionEmailRegistration
}
