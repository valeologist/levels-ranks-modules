#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Respawn"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iRespawnCount,
		g_iRespawnLevel[64],
		g_iRespawnNumber[64],
		g_iRespawns[MAXPLAYERS+1];

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
		case Engine_CSGO, Engine_CSS, Engine_SourceSDK2006: LoadTranslations("lr_module_respawn.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO, CS:S OB or v34");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);

	HookEvent("round_start", RoundStart);
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/respawn.ini");
	KeyValues hLR_Respawn = new KeyValues("Respawn");

	if(!hLR_Respawn.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	hLR_Respawn.GotoFirstSubKey();
	hLR_Respawn.Rewind();

	if(hLR_Respawn.JumpToKey("Settings"))
	{
		g_iRespawnCount = 0;
		hLR_Respawn.GotoFirstSubKey();

		do
		{
			g_iRespawnNumber[g_iRespawnCount] = hLR_Respawn.GetNum("count", 1);
			g_iRespawnLevel[g_iRespawnCount] = hLR_Respawn.GetNum("rank", 0);
			g_iRespawnCount++;
		}
		while(hLR_Respawn.GotoNextKey());
	}
	else SetFailState(PLUGIN_NAME ... " : Section Settings is not found (%s)", sPath);
	hLR_Respawn.Close();
}

public void RoundStart(Handle event, char[] name, bool dontBroadcast)
{
	for(int id = 1; id <= MaxClients; id++)
	{
		if(IsClientInGame(id))
		{
			g_iRespawns[id] = 0;
			int iRank = LR_GetClientInfo(id, ST_RANK);

			for(int i = g_iRespawnCount - 1; i >= 0; i--)
			{
				if(iRank >= g_iRespawnLevel[i])
				{
					g_iRespawns[id] = g_iRespawnNumber[i];
					break;
				}
			}
		}
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	FormatEx(sText, sizeof(sText), "%T", "Respawn", iClient, g_iRespawns[iClient]);
	hMenu.AddItem("Respawn", sText, (GetClientTeam(iClient) > 1 && g_iRespawns[iClient] > 0 && !IsPlayerAlive(iClient)) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Respawn") && GetClientTeam(iClient) > 1)
	{
		CS_RespawnPlayer(iClient);
		g_iRespawns[iClient]--;
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}