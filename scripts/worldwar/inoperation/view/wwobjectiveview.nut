::WwObjectiveView <- class
{
  id = ""
  oType = null
  staticBlk = null
  dynamicBlk = null
  side = null
  status = ""
  statusImg = ""
  zonesList = null

  isLastObjective = false

  constructor(v_staticBlk, v_dynamicBlk, v_side, v_isLastObjective = false)
  {
    staticBlk = v_staticBlk
    dynamicBlk = v_dynamicBlk
    side = ::ww_side_val_to_name(v_side)
    oType = ::g_ww_objective_type.getTypeByTypeName(staticBlk.type)
    id = staticBlk.getBlockName()
    isLastObjective = v_isLastObjective

    let statusType = oType.getObjectiveStatus(dynamicBlk?.winner, side)
    status = statusType.name
    statusImg = statusType.wwMissionObjImg
    zonesList = oType.getUpdatableZonesParams(staticBlk, dynamicBlk, side)
  }

  function getNameId()
  {
    return oType.getNameId(staticBlk, side)
  }

  function getName()
  {
    return oType.getName(staticBlk, dynamicBlk, side)
  }

  function getDesc()
  {
    return oType.getDesc(staticBlk, dynamicBlk, side)
  }

  function getParamsArray()
  {
    return oType.getParamsArray(staticBlk, side)
  }

  function getUpdatableData()
  {
    return oType.getUpdatableParamsArray(staticBlk, dynamicBlk, side)
  }

  function getUpdatableDataDescriptionText()
  {
    return oType.getUpdatableParamsDescriptionText(staticBlk, dynamicBlk, side)
  }

  function getUpdatableDataDescriptionTooltip()
  {
    return oType.getUpdatableParamsDescriptionTooltip(staticBlk, dynamicBlk, side)
  }

  function getUpdatableZonesData()
  {
    return zonesList
  }

  function hasObjectiveZones()
  {
    return zonesList.len()
  }
}
