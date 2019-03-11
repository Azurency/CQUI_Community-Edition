-- ===========================================================================
-- Base File
-- ===========================================================================
include("CityPanelOverview_Expansion2");

function ViewPanelAmenities(data:table)
  BASE_ViewPanelAmenities(data);  -- AZURENCY : this is the base game version

  --kInstance = m_kAmenitiesIM:GetInstance();
  --kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_LOST_FROM_GOVERNORS") );
  --kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromGovernors) );
  CQUI_BuildAmenityBubbleInstance("ICON_GOVERNOR_THE_EDUCATOR", data.AmenitiesFromGovernors, "LOC_REPORTS_GOVERNOR");
end