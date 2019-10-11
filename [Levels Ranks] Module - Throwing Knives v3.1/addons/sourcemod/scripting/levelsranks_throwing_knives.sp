#pragma semicolon 1
#include <throwing_knives_core>

#pragma newdecls required
#include <sourcemod>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Throwing Knives"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iTKCount,
		g_iTKLevel[64],
		g_iTKnivesCount[64];

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
		case Engine_CSGO, Engine_CSS: {}
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO, CS:S OB");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	HookEvent("player_spawn", PlayerSpawn);
}

public void OnMapStart()
{
	ConfigLoad();
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/throwing_knives.ini");
	KeyValues hLR_TK = new KeyValues("Throwing_Knives");

	if(!hLR_TK.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	hLR_TK.GotoFirstSubKey();
	hLR_TK.Rewind();

	if(hLR_TK.JumpToKey("Settings"))
	{
		g_iTKCount = 0;
		hLR_TK.GotoFirstSubKey();

		do
		{
			g_iTKnivesCount[g_iTKCount] = hLR_TK.GetNum("count", 1);
			g_iTKLevel[g_iTKCount] = hLR_TK.GetNum("level", 0);
			g_iTKCount++;
		}
		while(hLR_TK.GotoNextKey());
	}
	else SetFailState(PLUGIN_NAME ... " : Section Settings is not found (%s)", sPath);
	hLR_TK.Close();
}

public void PlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{	
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(iClient && IsClientInGame(iClient))
	{
		int iRank = LR_GetClientInfo(iClient, ST_RANK);
		TKC_SetClientKnives(iClient, 0);

		for(int i = g_iTKCount - 1; i >= 0; i--)
		{
			if(iRank >= g_iTKLevel[i])
			{
				TKC_SetClientKnives(iClient, g_iTKnivesCount[i]);
				break;
			}
		}
	}
}