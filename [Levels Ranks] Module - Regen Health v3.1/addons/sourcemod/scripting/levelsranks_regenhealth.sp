#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Regen Health"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iRHLevel,
		g_iRHHealth,
		g_iRHMaxHealth;
bool		g_bRegenHealthButton[MAXPLAYERS+1];
float		g_fRHTime;
Handle	g_hRegenHealth,
		g_hRHTimer[MAXPLAYERS+1];

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
		case Engine_CSGO, Engine_CSS, Engine_SourceSDK2006: LoadTranslations("lr_module_regenhealth.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO, CS:S OB or v34");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
	g_hRegenHealth = RegClientCookie("LR_RegenHealth", "LR_RegenHealth", CookieAccess_Private);
	
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/regenhealth.ini");
	KeyValues hLR_RA = new KeyValues("RegenHealth");

	if(!hLR_RA.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iRHLevel = hLR_RA.GetNum("rank", 0);
	g_fRHTime = hLR_RA.GetFloat("time", 1.0);
	g_iRHMaxHealth = hLR_RA.GetNum("maxhealth", 125);
	g_iRHHealth = hLR_RA.GetNum("health", 5);

	hLR_RA.Close();
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iRHLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bRegenHealthButton[iClient] ? "RH_On" : "RH_Off", iClient);
		hMenu.AddItem("RegenHealth", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "RH_RankClosed", iClient, g_iRHLevel);
		hMenu.AddItem("RegenHealth", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "RegenHealth"))
	{
		g_bRegenHealthButton[iClient] = !g_bRegenHealthButton[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientPostAdminCheck(int iClient)
{
	if(iClient && IsClientInGame(iClient))
	{
		g_hRHTimer[iClient] = CreateTimer(g_fRHTime, TimerRegen, GetClientUserId(iClient), TIMER_REPEAT);
	}
}

public Action TimerRegen(Handle hTimer, int iUserid)
{
	int iClient = GetClientOfUserId(iUserid);
	if(iClient && IsClientInGame(iClient) && GetClientTeam(iClient) > 1 && IsPlayerAlive(iClient) && !g_bRegenHealthButton[iClient] && (LR_GetClientInfo(iClient, ST_RANK) >= g_iRHLevel))
	{
		int iHealth = GetEntProp(iClient, Prop_Send, "m_iHealth") + g_iRHHealth;
		if(iHealth > g_iRHMaxHealth)
		{
			iHealth = g_iRHMaxHealth;
		}

		SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hRegenHealth, sCookie, sizeof(sCookie));
	g_bRegenHealthButton[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	if(g_hRHTimer[iClient] != null)
	{
		KillTimer(g_hRHTimer[iClient]);
		g_hRHTimer[iClient] = null;
	}

	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bRegenHealthButton[iClient]);
	SetClientCookie(iClient, g_hRegenHealth, sCookie);
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