#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Speed"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iSpeedLevel;
bool		g_bSpeedActivator[MAXPLAYERS+1];
float		g_fSpeedCount;
Handle	g_hSpeed;

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
		case Engine_CSGO, Engine_CSS: LoadTranslations("lr_module_speed.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO, CS:S OB");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);

	HookEvent("player_spawn", PlayerSpawn);
	g_hSpeed = RegClientCookie("LR_Speed", "LR_Speed", CookieAccess_Private);
	
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/speed.ini");
	KeyValues hLR_Speed = new KeyValues("Speed");

	if(!hLR_Speed.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iSpeedLevel = hLR_Speed.GetNum("rank", 0);
	g_fSpeedCount = hLR_Speed.GetFloat("value", 1.2);

	hLR_Speed.Close();
}

public void PlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{	
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(iClient && IsClientInGame(iClient) && !g_bSpeedActivator[iClient] && (LR_GetClientInfo(iClient, ST_RANK) >= g_iSpeedLevel))
	{
		SetEntPropFloat(iClient, Prop_Data, "m_flLaggedMovementValue", g_fSpeedCount);
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iSpeedLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bSpeedActivator[iClient] ? "Speed_On" : "Speed_Off", iClient, g_fSpeedCount);
		hMenu.AddItem("Speed", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "Speed_RankClosed", iClient, g_fSpeedCount, g_iSpeedLevel);
		hMenu.AddItem("Speed", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Speed"))
	{
		g_bSpeedActivator[iClient] = !g_bSpeedActivator[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hSpeed, sCookie, sizeof(sCookie));
	g_bSpeedActivator[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bSpeedActivator[iClient]);
	SetClientCookie(iClient, g_hSpeed, sCookie);
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