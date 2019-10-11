#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <lvl_ranks>
#include <clientprefs>

#define PLUGIN_NAME "[LR] Module - Bhop"
#define PLUGIN_AUTHOR "RoadSide Romeo & Kaneki"

int		g_iBhopLevel;
bool		g_bBhopClient[MAXPLAYERS+1],
		g_bButtonBhop[MAXPLAYERS+1];
Handle	g_hBhop;

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
		case Engine_CSGO, Engine_CSS, Engine_SourceSDK2006: LoadTranslations("lr_module_bhop.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO, CS:S OB or v34");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
	g_hBhop = RegClientCookie("LR_Bhop", "LR_Bhop", CookieAccess_Private);

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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/bhop.ini");
	KeyValues hLR_Bhop = new KeyValues("Bhop");

	if(!hLR_Bhop.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iBhopLevel = hLR_Bhop.GetNum("rank", 0);

	hLR_Bhop.Close();
}

public void PlayerSpawn(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	g_bBhopClient[iClient] = (iClient && IsClientInGame(iClient) && !g_bButtonBhop[iClient] && LR_GetClientInfo(iClient, ST_RANK) >= g_iBhopLevel);
}

public Action OnPlayerRunCmd(int iClient, int &buttons)
{
    if(IsPlayerAlive(iClient) && !g_bButtonBhop[iClient] && g_bBhopClient[iClient] && (buttons & IN_JUMP) && !(GetEntityFlags(iClient) & FL_ONGROUND) && !(GetEntityMoveType(iClient) & MOVETYPE_LADDER) && (GetEntProp(iClient, Prop_Data, "m_nWaterLevel") <= 1))
    {
		buttons &= ~IN_JUMP;
    }
}  

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iBhopLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bButtonBhop[iClient] ? "Bhop_On" : "Bhop_Off", iClient);
		hMenu.AddItem("Bhop", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "Bhop_Closed", iClient, g_iBhopLevel);
		hMenu.AddItem("Bhop", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Bhop"))
	{
		g_bButtonBhop[iClient] = !g_bButtonBhop[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hBhop, sCookie, sizeof(sCookie));
	g_bButtonBhop[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bBhopClient[iClient]);
	SetClientCookie(iClient, g_hBhop, sCookie);
	g_bBhopClient[iClient] = false;
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