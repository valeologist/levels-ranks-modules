#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Vampirism"
#define PLUGIN_AUTHOR "RoadSide Romeo & Kaneki"

int		g_iVampLevel;
bool		g_bVampActive[MAXPLAYERS+1];
ConVar	g_imaxHealth,
		g_iCountHealth;
Handle	g_hVampirism;

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
		case Engine_CSGO: LoadTranslations("lr_module_vampirism.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);

	g_hVampirism = RegClientCookie("LR_Vampirism", "LR_Vampirism", CookieAccess_Private);
	g_imaxHealth = CreateConVar("lr_vamp_maxHealth", "100", "Сколько максимально хп может получить игрок");
	g_iCountHealth = CreateConVar("lr_vamp_countHealth", "10", "Сколько прибавлять хп игроку");
	
	HookEvent("player_hurt", PH);
	AutoExecConfig(true, "LR_Vampirism", "levels_ranks");
	
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/vampirism.ini");
	KeyValues hLR_Vampir = new KeyValues("Vampirism");

	if(!hLR_Vampir.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iVampLevel = hLR_Vampir.GetNum("rank", 0);

	hLR_Vampir.Close();
}

public void PH(Handle event, const char[]name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(iClient && IsPlayerAlive(iClient) && !g_bVampActive[iClient] && LR_GetClientInfo(iClient, ST_RANK) >= g_iVampLevel)
	{  
        int irand = GetRandomInt(1, 5);
        if(irand == 3)
		{
	        int ihealth = GetClientHealth(iClient) + GetConVarInt(g_iCountHealth);
	
	        if (ihealth > g_imaxHealth.IntValue)
	        {
		        ihealth = GetConVarInt(g_imaxHealth);
	        }

	        SetEntityHealth(iClient, ihealth);
		}
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iVampLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bVampActive[iClient] ? "Vamp_On" : "Vamp_Off", iClient);
		hMenu.AddItem("Vamp", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "AG_RankClosed", iClient, g_iVampLevel);
		hMenu.AddItem("Vamp", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Vamp"))
	{
		g_bVampActive[iClient] = !g_bVampActive[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hVampirism, sCookie, sizeof(sCookie));
	g_bVampActive[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bVampActive[iClient]);
	SetClientCookie(iClient, g_hVampirism, sCookie);
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