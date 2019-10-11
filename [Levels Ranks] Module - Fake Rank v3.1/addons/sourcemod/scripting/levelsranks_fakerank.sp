#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - FakeRank"
#define PLUGIN_AUTHOR "RoadSide Romeo & Wend4r"

int			g_iType,
			m_iCompetitiveRanking;
KeyValues	g_hKv;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void LR_OnCoreIsReady()
{
	OnPluginStart();
}

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO) 
	{
		SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO");
	}

	if(LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad))
	{
		m_iCompetitiveRanking = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");
		ConfigLoad();
	}
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(g_hKv) delete g_hKv;
	else BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/fakerank.ini");

	g_hKv = new KeyValues("FakeRank");
	if(!g_hKv.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	switch(g_hKv.GetNum("Type", 0))
	{
		case 0: g_iType = 0;
		case 1: g_iType = 50;
		case 2: g_iType = 70;
	}
}

public void OnMapStart()
{
	static const char sPath[] = "materials/panorama/images/icons/skillgroups/skillgroup%i.svg";
	static char sBuffer[256];

	SDKHook(GetPlayerResourceEntity(), SDKHook_ThinkPost, OnThinkPost);

	static char sRank[12];
	for(int i = LR_GetRankExp().Length + 1, iIndex; --i;)
	{
		IntToString(i, sRank, sizeof(sRank));
		if((iIndex = g_hKv.GetNum(sRank, -1) + g_iType) > 18)
		{
			FormatEx(sBuffer, sizeof(sBuffer), sPath, iIndex);
			AddFileToDownloadsTable(sBuffer);
		}
	}
}

void OnThinkPost(int iEnt)
{
	static char sRank[12];
	for(int i = MaxClients + 1; --i;)
	{
		if(LR_GetClientStatus(i))
		{
			IntToString(LR_GetClientInfo(i, ST_RANK), sRank, sizeof(sRank));
			SetEntData(iEnt, m_iCompetitiveRanking + i*4, g_hKv.GetNum(sRank) + g_iType);
		}
	}
}

public void OnPlayerRunCmdPost(int iClient, int iButtons)
{
	static int iOldButtons[MAXPLAYERS+1];
	if(iButtons & IN_SCORE && !(iOldButtons[iClient] & IN_SCORE))
	{
		StartMessageOne("ServerRankRevealAll", iClient, USERMSG_BLOCKHOOKS);
		EndMessage();
	}

	iOldButtons[iClient] = iButtons;
}