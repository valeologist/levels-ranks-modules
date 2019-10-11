#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <lvl_ranks>
#include <clientprefs>

#define PLUGIN_NAME "[LR] Module - No Self Damage"
#define PLUGIN_AUTHOR "RoadSide Romeo & Kaneki"

int		g_iLevel;
bool		g_bActive[MAXPLAYERS+1];
Handle	g_hNSD;

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
		case Engine_CSGO: LoadTranslations("lr_module_noselfdamage.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
	g_hNSD = RegClientCookie("LR_NoSelfDamage", "LR_NoSelfDamage", CookieAccess_Private);
	
	for(int iClient = 1; iClient <= MaxClients; iClient++)
    {
		if(IsClientInGame(iClient))
		{
			if(IsValidEntity(iClient)) OnClientPutInServer(iClient);
			OnClientCookiesCached(iClient);
		}
	}
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/noselfdamage.ini");
	KeyValues hLR_NSD = new KeyValues("NoSelfDamage");

	if(!hLR_NSD.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR_NSD.GetNum("rank", 0);

	hLR_NSD.Close();
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int iClient, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(0 < attacker <= MaxClients && LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel && !g_bActive[iClient] && iClient == attacker)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "NoSelfDamage_On" : "NoSelfDamage_Off", iClient);
		hMenu.AddItem("NoSelfDamage", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "NoSelfDamage_Closed", iClient, g_iLevel);
		hMenu.AddItem("NoSelfDamage", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "NoSelfDamage"))
	{
		g_bActive[iClient] = !g_bActive[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hNSD, sCookie, sizeof(sCookie));
	g_bActive[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bActive[iClient]);
	SetClientCookie(iClient, g_hNSD, sCookie);
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