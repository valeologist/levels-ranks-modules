#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Health Giver"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iHGLevel,
		g_iHGHealth;
bool		g_bButtonHealthGiver[MAXPLAYERS+1];
Handle	g_hHealthGiver;

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
		case Engine_CSGO, Engine_CSS, Engine_SourceSDK2006: LoadTranslations("lr_module_healthgiver.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO, CS:S OB or v34");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);

	HookEvent("player_spawn", PlayerSpawn);
	g_hHealthGiver = RegClientCookie("LR_HealthGiver", "LR_HealthGiver", CookieAccess_Private);
	
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/healthgiver.ini");
	KeyValues hLR_HG = new KeyValues("HealthGiver");

	if(!hLR_HG.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iHGLevel = hLR_HG.GetNum("rank", 0);
	g_iHGHealth = hLR_HG.GetNum("value", 125);

	hLR_HG.Close();
}

public void PlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{	
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(iClient && IsClientInGame(iClient) && !g_bButtonHealthGiver[iClient] && (LR_GetClientInfo(iClient, ST_RANK) >= g_iHGLevel))
	{
		SetEntProp(iClient, Prop_Send, "m_iHealth", g_iHGHealth);
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iHGLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bButtonHealthGiver[iClient] ? "HG_On" : "HG_Off", iClient, g_iHGHealth);
		hMenu.AddItem("HealthGiver", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "HG_RankClosed", iClient, g_iHGHealth, g_iHGLevel);
		hMenu.AddItem("HealthGiver", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "HealthGiver"))
	{
		g_bButtonHealthGiver[iClient] = !g_bButtonHealthGiver[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hHealthGiver, sCookie, sizeof(sCookie));
	g_bButtonHealthGiver[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bButtonHealthGiver[iClient]);
	SetClientCookie(iClient, g_hHealthGiver, sCookie);
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