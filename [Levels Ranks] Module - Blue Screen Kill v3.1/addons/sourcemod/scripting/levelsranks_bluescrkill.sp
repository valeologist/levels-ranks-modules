#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Blue Screen Kill"
#define PLUGIN_AUTHOR "RoadSide Romeo & R1KO"

int		g_iBSKLevel;
bool		g_bButtonBSK[MAXPLAYERS+1];
Handle	g_hBlueScreenKill;

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
		case Engine_CSGO, Engine_CSS, Engine_SourceSDK2006: LoadTranslations("lr_module_bluescrkill.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO, CS:S OB or v34");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);

	HookEvent("player_death", PlayerDeath);
	g_hBlueScreenKill = RegClientCookie("LR_BlueScrKill", "LR_BlueScrKill", CookieAccess_Private);
	
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/bluescrkill.ini");
	KeyValues hLR_BSK = new KeyValues("BlueScrKill");

	if(!hLR_BSK.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iBSKLevel = hLR_BSK.GetNum("rank", 0);

	hLR_BSK.Close();
}

public void PlayerDeath(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{	
	int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if(iAttacker && IsClientInGame(iAttacker) && !g_bButtonBSK[iAttacker] && LR_GetClientInfo(iAttacker, ST_RANK) >= g_iBSKLevel)
	{
		int iClients[1];
		iClients[0] = iAttacker;
		int iColors[4] = {0, 0, 200, 100};

		Handle hMessage = StartMessage("Fade", iClients, 1);
		if(GetUserMessageType() == UM_Protobuf) 
		{
			PbSetInt(hMessage, "duration", 600);
			PbSetInt(hMessage, "hold_time", 0);
			PbSetInt(hMessage, "flags", 0x0001);
			PbSetColor(hMessage, "clr", iColors);
		}
		else
		{
			BfWriteShort(hMessage, 600);
			BfWriteShort(hMessage, 0);
			BfWriteShort(hMessage, (0x0001));
			BfWriteByte(hMessage, 0);
			BfWriteByte(hMessage, 0);
			BfWriteByte(hMessage, 200);
			BfWriteByte(hMessage, 100);
		}
		EndMessage(); 
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iBSKLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bButtonBSK[iClient] ? "BSK_On" : "BSK_Off", iClient);
		hMenu.AddItem("BlueScreenKill", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "BSK_RankClosed", iClient, g_iBSKLevel);
		hMenu.AddItem("BlueScreenKill", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "BlueScreenKill"))
	{
		g_bButtonBSK[iClient] = !g_bButtonBSK[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hBlueScreenKill, sCookie, sizeof(sCookie));
	g_bButtonBSK[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bButtonBSK[iClient]);
	SetClientCookie(iClient, g_hBlueScreenKill, sCookie);
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