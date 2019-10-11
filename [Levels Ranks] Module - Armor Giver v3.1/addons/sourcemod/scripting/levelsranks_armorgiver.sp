#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Armor Giver"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iAGLevel,
		g_iAGArmor;
bool		g_bButtonArmor[MAXPLAYERS+1],
		g_bAGHelmet;
Handle	g_hArmorGiver;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void LR_OnCoreIsReady()
{
	if(LR_GetSettingsValue(LR_TypeStatistics))
	{
		SetFailState(PLUGIN_NAME ... " : Plug-in works only on Funded System");
	}
	else ConfigLoad();
}

public void OnPluginStart()
{
	switch(GetEngineVersion())
	{
		case Engine_CSGO, Engine_CSS, Engine_SourceSDK2006: LoadTranslations("lr_module_armorgiver.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO, CS:S OB or v34");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);

	HookEvent("player_spawn", PlayerSpawn);
	g_hArmorGiver = RegClientCookie("LR_ArmorGiver", "LR_ArmorGiver", CookieAccess_Private);
	
	for(int iClient = 1; iClient <= MaxClients; iClient++)
    {
		if(IsClientInGame(iClient))
		{
			OnClientCookiesCached(iClient);
		}
	}
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/armorgiver.ini");
	KeyValues hLR_AG = new KeyValues("Armor_Giver");

	if(!hLR_AG.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iAGLevel = hLR_AG.GetNum("rank", 0);
	g_iAGArmor = hLR_AG.GetNum("value", 125);
	g_bAGHelmet = view_as<bool>(hLR_AG.GetNum("helmet", 1));

	hLR_AG.Close();
}

public void PlayerSpawn(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{	
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient && IsClientInGame(iClient) && !g_bButtonArmor[iClient] && LR_GetClientInfo(iClient, ST_RANK) >= g_iAGLevel)
	{
		SetEntProp(iClient, Prop_Send, "m_ArmorValue", g_iAGArmor);
		if(g_bAGHelmet)
		{
			SetEntProp(iClient, Prop_Send, "m_bHasHelmet", 1);
		}
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iAGLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bButtonArmor[iClient] ? "AG_On" : "AG_Off", iClient, g_iAGArmor);
		hMenu.AddItem("Armor_Giver", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "AG_RankClosed", iClient, g_iAGArmor, g_iAGLevel);
		hMenu.AddItem("Armor_Giver", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Armor_Giver"))
	{
		g_bButtonArmor[iClient] = !g_bButtonArmor[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hArmorGiver, sCookie, sizeof(sCookie));
	g_bButtonArmor[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bButtonArmor[iClient]);
	SetClientCookie(iClient, g_hArmorGiver, sCookie);
}

public void OnPluginEnd()
{
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			OnClientDisconnect(iClient);
		}
	}
}