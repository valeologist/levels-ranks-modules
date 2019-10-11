#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Fast Plant"
#define PLUGIN_AUTHOR "RoadSide Romeo & wS"

int		g_iFPLevel;
bool		g_bFPButton[MAXPLAYERS+1];
Handle	g_hFastPlant;

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
		case Engine_CSGO, Engine_CSS, Engine_SourceSDK2006: LoadTranslations("lr_module_fastplant.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO, CS:S OB or v34");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);

	g_hFastPlant = RegClientCookie("LR_FastPlant", "LR_FastPlant", CookieAccess_Private);
	HookEvent("bomb_beginplant", PlayerBeginPlant, EventHookMode_Post);
	
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/fastplant.ini");
	KeyValues hLR_FP = new KeyValues("FastPlant");

	if(!hLR_FP.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iFPLevel = hLR_FP.GetNum("rank", 0);

	hLR_FP.Close();
}

public Action PlayerBeginPlant(Handle hEvent, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iFPLevel && !g_bFPButton[iClient])
	{
		int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		if(iWeapon)
		{
			char sClass[32];
			if(GetEntityClassname(iWeapon, sClass, 32) && !strcmp(sClass[7], "c4", false))
			{
				SetEntPropFloat(iWeapon, Prop_Send, "m_fArmedTime", GetGameTime());
			}
		}
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iFPLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bFPButton[iClient] ? "FP_On" : "FP_Off", iClient);
		hMenu.AddItem("FastPlant", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "FP_RankClosed", iClient, g_iFPLevel);
		hMenu.AddItem("FastPlant", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "FastPlant"))
	{
		g_bFPButton[iClient] = !g_bFPButton[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hFastPlant, sCookie, sizeof(sCookie));
	g_bFPButton[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bFPButton[iClient]);
	SetClientCookie(iClient, g_hFastPlant, sCookie);
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