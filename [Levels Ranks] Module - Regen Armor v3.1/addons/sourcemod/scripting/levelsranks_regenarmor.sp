#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Regen Armor"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iRALevel,
		g_iRAArmor,
		g_iRAMaxArmor;
bool		g_bRegenArmorButton[MAXPLAYERS+1];
float		g_fRATime;
Handle	g_hRegenArmor,
		g_hRATimer[MAXPLAYERS+1];

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
		case Engine_CSGO, Engine_CSS, Engine_SourceSDK2006: LoadTranslations("lr_module_regenarmor.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO, CS:S OB or v34");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
	g_hRegenArmor = RegClientCookie("LR_RegenArmor", "LR_RegenArmor", CookieAccess_Private);
	
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/regenarmor.ini");
	KeyValues hLR_RA = new KeyValues("RegenArmor");

	if(!hLR_RA.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iRALevel = hLR_RA.GetNum("rank", 0);
	g_fRATime = hLR_RA.GetFloat("time", 1.0);
	g_iRAMaxArmor = hLR_RA.GetNum("maxarmor", 125);
	g_iRAArmor = hLR_RA.GetNum("armor", 5);

	hLR_RA.Close();
}

public void OnClientPostAdminCheck(int iClient)
{
	if(iClient && IsClientInGame(iClient))
	{
		g_hRATimer[iClient] = CreateTimer(g_fRATime, TimerRegen, GetClientUserId(iClient), TIMER_REPEAT);
	}
}

public Action TimerRegen(Handle hTimer, int iUserid)
{
	int iClient = GetClientOfUserId(iUserid);
	if(iClient && IsClientInGame(iClient) && GetClientTeam(iClient) > 1 && IsPlayerAlive(iClient) && !g_bRegenArmorButton[iClient] && (LR_GetClientInfo(iClient, ST_RANK) >= g_iRALevel))
	{
		int iArmor = GetEntProp(iClient, Prop_Send, "m_ArmorValue") + g_iRAArmor;
		if(iArmor > g_iRAMaxArmor)
		{
			iArmor = g_iRAMaxArmor;
		}

		SetEntProp(iClient, Prop_Send, "m_ArmorValue", iArmor);
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iRALevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bRegenArmorButton[iClient] ? "RA_On" : "RA_Off", iClient);
		hMenu.AddItem("RegenArmor", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "RA_RankClosed", iClient, g_iRALevel);
		hMenu.AddItem("RegenArmor", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "RegenArmor"))
	{
		g_bRegenArmorButton[iClient] = !g_bRegenArmorButton[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hRegenArmor, sCookie, sizeof(sCookie));
	g_bRegenArmorButton[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	if(g_hRATimer[iClient] != null)
	{
		KillTimer(g_hRATimer[iClient]);
		g_hRATimer[iClient] = null;
	}

	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bRegenArmorButton[iClient]);
	SetClientCookie(iClient, g_hRegenArmor, sCookie);
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