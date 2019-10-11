#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Heavy Armor"
#define PLUGIN_AUTHOR "RoadSide Romeo & R1KO"

int		g_iHeavyArmorLevel;
bool		g_bHeavyArmor[MAXPLAYERS+1];
Handle	g_hHeavyArmor;

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
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);

	HookEvent("player_spawn", PlayerSpawn);
	g_hHeavyArmor = RegClientCookie("LR_HeavyArmor", "LR_HeavyArmor", CookieAccess_Private);
	LoadTranslations("lr_module_heavyarmor.phrases");
	
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/heavyarmor.ini");
	KeyValues hLR_HA = new KeyValues("HeavyArmor");

	if(!hLR_HA.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iHeavyArmorLevel = hLR_HA.GetNum("rank", 0);

	hLR_HA.Close();
}

public void PlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{	
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(iClient && IsClientInGame(iClient) && !g_bHeavyArmor[iClient] && LR_GetClientInfo(iClient, ST_RANK) >= g_iHeavyArmorLevel)
	{
		GivePlayerItem(iClient, "item_heavyassaultsuit");
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iHeavyArmorLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bHeavyArmor[iClient] ? "HA_On" : "HA_Off", iClient);
		hMenu.AddItem("HeavyArmor", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "HA_RankClosed", iClient, g_iHeavyArmorLevel);
		hMenu.AddItem("HeavyArmor", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "HeavyArmor"))
	{
		g_bHeavyArmor[iClient] = !g_bHeavyArmor[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hHeavyArmor, sCookie, sizeof(sCookie));
	g_bHeavyArmor[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bHeavyArmor[iClient]);
	SetClientCookie(iClient, g_hHeavyArmor, sCookie);
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