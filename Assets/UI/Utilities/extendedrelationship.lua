-- Extended Relationship Tooltip creator
-- Aristos and atggta
function RelationshipGet(nPlayerID :number)
  local tPlayer :table = Players[nPlayerID];
  local nLocalPlayerID :number = Game.GetLocalPlayer();
  local tTooltips :table = tPlayer:GetDiplomaticAI():GetDiplomaticModifiers(nLocalPlayerID);

  if not tTooltips then return ""; end

  local tRelationship :table = {};
  local nRelationshipSum :number = 0;
  local sTextColor :string = "";

  for i, tTooltip in ipairs(tTooltips) do
    local nScore :number = tTooltip.Score;
    local sText :string = tTooltip.Text;

    if(nScore ~= 0) then
      if(nScore > 0) then
        sTextColor = "[COLOR_Civ6Green]";
      else
        sTextColor = "[COLOR_Civ6Red]";
      end
      table.insert(tRelationship, {nScore, sTextColor .. nScore .. "[ENDCOLOR] - " .. sText .. "[NEWLINE]"});
      nRelationshipSum = nRelationshipSum + nScore;
    end
  end

  table.sort(
    tRelationship,
    function(a, b)
      return a[1] > b[1];
    end
  );

  local sRelationshipSum :string = "";
  local sRelationship :string = "";
  if(nRelationshipSum >= 0) then
    sRelationshipSum = "[COLOR_Civ6Green]";
  else
    sRelationshipSum = "[COLOR_Civ6Red]";
  end
  sRelationshipSum = sRelationshipSum .. nRelationshipSum .. "[ENDCOLOR]"
  for nKey, tValue in pairs(tRelationship) do
    sRelationship = sRelationship .. tValue[2];
  end
  if sRelationship ~= "" then
    sRelationship = Locale.Lookup("LOC_DIPLOMACY_INTEL_RELATIONSHIPS") .. " " .. sRelationshipSum .. "[NEWLINE]" .. sRelationship:sub(1, #sRelationship - #"[NEWLINE]");
  end

  return sRelationship;
end
