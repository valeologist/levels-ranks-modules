#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Distributor"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iDistributorValue,
		g_iDistributorTime;
Handle	g_hTimerGiver[MAXPLAYERS + 1];

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION}
public void OnPluginStart()
{
	LR_Hook(LR_OnCoreIsReady, ConfigLoad);
	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	switch(GetEngineVersion())
	{
		case Engine_CSGO, Engine_CSS: LoadTranslations("lr_module_distributor.phrases");
		case Engine_SourceSDK2006: LoadTranslations("lr_module_distributor_old.phrases");
	}
}

public void OnMapStart() 
{
	ConfigLoad();
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(sPath[0] == '\0')
	{
		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/distributor.ini");
	}

	KeyValues hLR_Distributor = new KeyValues("LR_Distributor");
	if(!hLR_Distributor.ImportFromFile(sPath))
	{
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);
	}

	hLR_Distributor.GotoFirstSubKey();
	hLR_Distributor.Rewind();

	if(hLR_Distributor.JumpToKey("Settings"))
	{
		g_iDistributorValue = hLR_Distributor.GetNum("value", 1);
		g_iDistributorTime = hLR_Distributor.GetNum("time", 50);
	}
	else SetFailState(PLUGIN_NAME ... " : Section Settings is not found (%s)", sPath);
	delete hLR_Distributor;
}

public void OnClientPutInServer(int iClient)
{
	if(!LR_GetSettingsValue(LR_TypeStatistics) && iClient && IsClientInGame(iClient) && !IsFakeClient(iClient))
	{
		g_hTimerGiver[iClient] = CreateTimer(float(g_iDistributorTime), TimerGiver, GetClientUserId(iClient), TIMER_REPEAT);
	}
}

public Action TimerGiver(Handle hTimer, int iUserid)
{
	int iClient = GetClientOfUserId(iUserid);
	if(LR_CheckCountPlayers() && LR_GetClientStatus(iClient) && GetClientTeam(iClient) > 1)
	{
		LR_ChangeClientValue(iClient, g_iDistributorValue);
		LR_PrintToChat(iClient, true, "%T", "Distributor", iClient, LR_GetClientInfo(iClient, ST_EXP), g_iDistributorValue);
	}
}

public void OnClientDisconnect(int iClient)
{
	if(g_hTimerGiver[iClient] != null)
	{
		KillTimer(g_hTimerGiver[iClient]);
		g_hTimerGiver[iClient] = null;
	}
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