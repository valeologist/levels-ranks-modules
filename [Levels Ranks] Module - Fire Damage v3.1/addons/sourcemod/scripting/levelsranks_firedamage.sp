#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <lvl_ranks>
#include <clientprefs>

#define PLUGIN_NAME "[LR] Module - Fire Damage"
#define PLUGIN_AUTHOR "RoadSide Romeo & Kaneki"

int			g_iLevel,
			g_isKnife,
			g_isHE;
bool			g_bActive[MAXPLAYERS+1];
float			g_fireDuration;
Handle		g_hFireDamage;

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
		case Engine_CSGO: LoadTranslations("lr_module_firedamage.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);

	g_hFireDamage = RegClientCookie("LR_FireDamage", "LR_FireDamage", CookieAccess_Private);
	HookEvent("player_hurt", PlayerHurt);
	
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/firedamage.ini");
	KeyValues hLR_FireDamage = new KeyValues("FireDamage");

	if(!hLR_FireDamage.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR_FireDamage.GetNum("rank", 0);
	g_isKnife = hLR_FireDamage.GetNum("knife", 0);
	g_isHE = hLR_FireDamage.GetNum("grenade", 0);
	g_fireDuration = hLR_FireDamage.GetFloat("duration", 2.0);

	hLR_FireDamage.Close();
}

public void PlayerHurt(Event event, const char []sEvName, bool bSilent) 
{
	int iClient = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(iClient && LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel && !g_bActive[iClient])
	{
		if(!g_isKnife || !g_isHE)
		{
			char sWeapon[32];
			GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
			if(!g_isKnife && !strcmp(sWeapon, "knife")) return;
			if(!g_isHE && !strcmp(sWeapon, "hegrenade")) return;
		}
		IgniteEntity(GetClientOfUserId(GetEventInt(event, "userid")), g_fireDuration);
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "FireDamage_On" : "FireDamage_Off", iClient);
		hMenu.AddItem("FireDamage", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "FireDamage_Closed", iClient, g_iLevel);
		hMenu.AddItem("FireDamage", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "FireDamage"))
	{
		g_bActive[iClient] = !g_bActive[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hFireDamage, sCookie, sizeof(sCookie));
	g_bActive[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bActive[iClient]);
	SetClientCookie(iClient, g_hFireDamage, sCookie);
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