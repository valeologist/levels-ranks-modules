#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <lvl_ranks>
#include <clientprefs>

#define PLUGIN_NAME "[LR] Module - Endurance"
#define PLUGIN_AUTHOR "RoadSide Romeo & Kaneki"
	   
int			g_iLevel,
			m_flVelocityModifier;
bool			g_bActive[MAXPLAYERS+1];
Handle		g_hEndurance;

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
		case Engine_CSGO: LoadTranslations("lr_module_endurance.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);

	g_hEndurance = RegClientCookie("LR_Endurance", "LR_Endurance", CookieAccess_Private);
	m_flVelocityModifier = FindSendPropInfo("CCSPlayer", "m_flVelocityModifier");
	
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/endurance.ini");
	KeyValues hLR_Endurance = new KeyValues("Endurance");

	if(!hLR_Endurance.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR_Endurance.GetNum("rank", 0);

	hLR_Endurance.Close();
}

public Action OnPlayerRunCmd(int iClient, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(IsPlayerAlive(iClient) && GetEntDataFloat(iClient, m_flVelocityModifier) < 1.0 && LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel && !g_bActive[iClient])
	{
		SetEntDataFloat(iClient, m_flVelocityModifier, 1.0, true);
	}
	return Plugin_Continue;
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "Endurance_On" : "Endurance_Off", iClient);
		hMenu.AddItem("Endurance", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "Endurance_Closed", iClient, g_iLevel);
		hMenu.AddItem("Endurance", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Endurance"))
	{
		g_bActive[iClient] = !g_bActive[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hEndurance, sCookie, sizeof(sCookie));
	g_bActive[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bActive[iClient]);
	SetClientCookie(iClient, g_hEndurance, sCookie);
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