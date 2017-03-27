UPDATE CQUI_Settings
SET Value = (SELECT CQUI_Settings_Temp.Value FROM CQUI_Settings_Temp WHERE CQUI_Settings_Temp.Setting = CQUI_Settings.Setting)
WHERE EXISTS (SELECT * FROM CQUI_Settings_Temp WHERE CQUI_Settings_Temp.Setting = CQUI_Settings.Setting);
