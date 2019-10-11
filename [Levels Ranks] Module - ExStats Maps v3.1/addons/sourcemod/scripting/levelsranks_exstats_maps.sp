#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - ExStats Maps"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int				g_iAccountID[MAXPLAYERS+1],
				g_iMapCountPlay[MAXPLAYERS+1],
				g_iMapCountRoundsOverall[MAXPLAYERS+1],
				g_iMapCountRound[MAXPLAYERS+1][2],
				g_iMapCountTime[MAXPLAYERS+1],
				g_iMapCount_BPlanted[MAXPLAYERS+1],
				g_iMapCount_BDefused[MAXPLAYERS+1],
				g_iMapCount_HRescued[MAXPLAYERS+1],
				g_iMapCount_HKilled[MAXPLAYERS+1];
bool				g_bPlayerActive[MAXPLAYERS+1];
char				g_sTableName[96],
				g_sPluginTitle[64],
				g_sCurrentNameMap[128];
EngineVersion	g_iEngine;
Database		g_hDatabase;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void LR_OnCoreIsReady()
{
    OnAllPluginsLoaded();
}

public void OnAllPluginsLoaded()
{
	LR_Hook(LR_OnPlayerLoaded, LoadDataPlayer);
	LR_Hook(LR_OnResetPlayerStats, ResetDataPlayer);
	LR_Hook(LR_OnDatabaseCleanup, DatabaseCleanup);

	LR_MenuHook(LR_MyStatsSecondary, LR_OnMenuCreated, LR_OnMenuItemSelected);

	if(!g_hDatabase)
	{
		char sQuery[768];
		g_iEngine = GetEngineVersion();
		CreateTimer(1.0, TimerMap, _, TIMER_REPEAT);
		LoadTranslations("lr_module_exmaps.phrases");

		HookEvent("round_end", Hooks, EventHookMode_Pre);
		HookEvent("bomb_planted", Hooks, EventHookMode_Pre);
		HookEvent("bomb_defused", Hooks, EventHookMode_Pre);
		HookEvent("hostage_killed", Hooks, EventHookMode_Pre);
		HookEvent("hostage_rescued", Hooks, EventHookMode_Pre);

		LR_GetTableName(g_sTableName, sizeof(g_sTableName));
		LR_GetTitleMenu(g_sPluginTitle, sizeof(g_sPluginTitle));

		SQL_LockDatabase((g_hDatabase = LR_GetDatabase()));

		FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s_maps` (`steam` varchar(32) NOT NULL default '', `name_map` varchar(128) NOT NULL default '', `countplays` int NOT NULL DEFAULT 0, `rounds_overall` int NOT NULL DEFAULT 0, `rounds_ct` int NOT NULL DEFAULT 0, `rounds_t` int NOT NULL DEFAULT 0, `bomb_planted` int NOT NULL DEFAULT 0, `bomb_defused` int NOT NULL DEFAULT 0, `hostage_rescued` int NOT NULL DEFAULT 0, `hostage_killed` int NOT NULL DEFAULT 0, `playtime` int NOT NULL DEFAULT 0, PRIMARY KEY (`steam`, `name_map`))%s", g_sTableName, LR_GetDatabaseType() ? ";" : " CHARSET=utf8 COLLATE utf8_general_ci");
		if(!SQL_FastQuery(g_hDatabase, sQuery)) SetFailState(PLUGIN_NAME ... " : OnAllPluginsLoaded - could not create table (You must to reset the database)");

		SQL_UnlockDatabase(g_hDatabase);
		g_hDatabase.SetCharset("utf8");

		OnMapStart();
		for(int iClient = MaxClients + 1; --iClient;)
		{
			if(LR_GetClientStatus(iClient))
			{
				LoadDataPlayer(iClient, GetSteamAccountID(iClient));
			}
		}
	}
}

public void OnMapStart()
{
	GetCurrentMap(g_sCurrentNameMap, sizeof(g_sCurrentNameMap));
	int iPos = 0;
	for(int i = 0, iLen = strlen(g_sCurrentNameMap); i != iLen;)
	{
		if(g_sCurrentNameMap[i++] == '/')
		{
			iPos = i;
		}
	}

	if(iPos)
	{
		strcopy(g_sCurrentNameMap, sizeof(g_sCurrentNameMap) - iPos, g_sCurrentNameMap[iPos]);
	}
}

public Action TimerMap(Handle hTimer)
{
	for(int iClient = MaxClients + 1; --iClient;)
	{
		if(g_bPlayerActive[iClient])
		{
			g_iMapCountTime[iClient]++;
		}
	}
}

public void Hooks(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	switch(sEvName[0])
	{
		case 'r':
		{
			int iWinnerTeam = GetEventInt(hEvent, "winner");
			for(int iClient = MaxClients + 1; --iClient;)
			{
				if(IsClientInGame(iClient) && g_bPlayerActive[iClient])
				{
					g_iMapCountRoundsOverall[iClient]++;
					if(GetClientTeam(iClient) == iWinnerTeam)
					{
						switch(iWinnerTeam)
						{
							case CS_TEAM_CT: g_iMapCountRound[iClient][0]++;
							case CS_TEAM_T: g_iMapCountRound[iClient][1]++;
						}
					}
					SaveDataPlayer(iClient);
				}
			}
		}

		case 'b':
		{
			int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
			if(iClient)
			{
				switch(sEvName[6])
				{
					case 'l': g_iMapCount_BPlanted[iClient]++;
					case 'e': g_iMapCount_BDefused[iClient]++;
				}
			}
		}

		case 'h':
		{
			int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
			if(iClient)
			{
				switch(sEvName[8])
				{
					case 'k': g_iMapCount_HKilled[iClient]++;
					case 'r': g_iMapCount_HRescued[iClient]++;
				}
			}
		}
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	static char sText[64];
	FormatEx(sText, sizeof(sText), "%T", "MapStatisticsButton", iClient);
	hMenu.AddItem("map_stats", sText);
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "map_stats"))
	{
		MapsStats(iClient);
	}
}

void MapsStats(int iClient)
{
	static char sText[128], sBuffer[256];
	Menu hMenu = new Menu(MapsStatsHandler);

	if(!StrContains(g_sCurrentNameMap, "cs_", false))
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "MapStatistics_Cs", iClient, g_iMapCount_HRescued[iClient], g_iMapCount_HKilled[iClient]);
	}
	else if(!StrContains(g_sCurrentNameMap, "de_", false))
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "MapStatistics_De", iClient, g_iMapCount_BPlanted[iClient], g_iMapCount_BDefused[iClient]);
	}
	else
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "MapStatistics_Custom", iClient, g_iMapCountRound[iClient][0], g_iMapCountRound[iClient][1]);
	}

	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "MapStatistics", iClient, g_sCurrentNameMap, g_iMapCountTime[iClient] / 3600, g_iMapCountTime[iClient] / 60 % 60, g_iMapCountTime[iClient] % 60, RoundToCeil(100.0 / (g_iMapCountRoundsOverall[iClient] ? g_iMapCountRoundsOverall[iClient] : 1) * (g_iMapCountRound[iClient][0] + g_iMapCountRound[iClient][1])), sBuffer);

	FormatEx(sText, sizeof(sText), "%T", "Back", iClient);
	hMenu.AddItem(NULL_STRING, sText);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MapsStatsHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Select: LR_ShowMenu(iClient, LR_MyStatsSecondary);
	}
}

void LoadDataPlayer(int iClient, int iAccountID)
{
	char sQuery[512];
	g_iAccountID[iClient] = iAccountID;

	FormatEx(sQuery, sizeof(sQuery), "SELECT `countplays`, `rounds_overall`, `rounds_ct`, `rounds_t`, `bomb_planted`, `bomb_defused`, `hostage_rescued`, `hostage_killed`, `playtime` FROM `%s_maps` WHERE `steam` = 'STEAM_%i:%i:%i' AND `name_map` = '%s';", g_sTableName, g_iEngine == Engine_CSGO, g_iAccountID[iClient] & 1, g_iAccountID[iClient] >>> 1, g_sCurrentNameMap);
	g_hDatabase.Query(SQL_LoadDataPlayer, sQuery, GetClientUserId(iClient));
}

public void SQL_LoadDataPlayer(Database db, DBResultSet dbRs, const char[] sError, int iUserID)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_LoadDataPlayer - error while working with data (%s)", sError);
		return;
	}

	int iClient = GetClientOfUserId(iUserID);
	if(iClient)
	{
		if(dbRs.HasResults && dbRs.FetchRow())
		{
			g_iMapCountPlay[iClient] = dbRs.FetchInt(0) + 1;
			g_iMapCountRoundsOverall[iClient] = dbRs.FetchInt(1);
			g_iMapCountRound[iClient][0] = dbRs.FetchInt(2);
			g_iMapCountRound[iClient][1] = dbRs.FetchInt(3);
			g_iMapCount_BPlanted[iClient] = dbRs.FetchInt(4);
			g_iMapCount_BDefused[iClient] = dbRs.FetchInt(5);
			g_iMapCount_HRescued[iClient] = dbRs.FetchInt(6);
			g_iMapCount_HKilled[iClient] = dbRs.FetchInt(7);
			g_iMapCountTime[iClient] = dbRs.FetchInt(8);
			g_bPlayerActive[iClient] = true;
		}
		else CreateDataPlayer(iClient);
	}
}

void CreateDataPlayer(int iClient)
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `%s_maps` (`steam`, `name_map`) VALUES ('STEAM_%i:%i:%i', '%s');", g_sTableName, g_iEngine == Engine_CSGO, g_iAccountID[iClient] & 1, g_iAccountID[iClient] >>> 1, g_sCurrentNameMap);
	g_hDatabase.Query(SQL_CreateDataPlayer, sQuery, GetClientUserId(iClient));
}

public void SQL_CreateDataPlayer(Database db, DBResultSet dbRs, const char[] sError, int iUserID)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_CreateDataPlayer - error while working with data (%s)", sError);
		return;
	}

	int iClient = GetClientOfUserId(iUserID);
	if(iClient)
	{
		g_iMapCountPlay[iClient]++;
		g_iMapCountRoundsOverall[iClient] = 0;
		g_iMapCountRound[iClient][0] = 0;
		g_iMapCountRound[iClient][1] = 0;
		g_iMapCountTime[iClient] = 0;
		g_iMapCount_BPlanted[iClient] = 0;
		g_iMapCount_BDefused[iClient] = 0;
		g_iMapCount_HRescued[iClient] = 0;
		g_iMapCount_HKilled[iClient] = 0;
		g_bPlayerActive[iClient] = true;
	}
}

void SaveDataPlayer(int iClient)
{
	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "UPDATE `%s_maps` SET `countplays` = %d, `rounds_overall` = %d, `rounds_ct` = %d, `rounds_t` = %d, `bomb_planted` = %d, `bomb_defused` = %d, `hostage_rescued` = %d, `hostage_killed` = %d, `playtime` = %d WHERE `steam` = 'STEAM_%i:%i:%i' AND `name_map` = '%s';", g_sTableName, g_iMapCountPlay[iClient], g_iMapCountRoundsOverall[iClient], g_iMapCountRound[iClient][0], g_iMapCountRound[iClient][1], g_iMapCount_BPlanted[iClient], g_iMapCount_BDefused[iClient], g_iMapCount_HRescued[iClient], g_iMapCount_HKilled[iClient], g_iMapCountTime[iClient], g_iEngine == Engine_CSGO, g_iAccountID[iClient] & 1, g_iAccountID[iClient] >>> 1, g_sCurrentNameMap);
	g_hDatabase.Query(SQL_SaveDataPlayer, sQuery, GetClientUserId(iClient));
}

public void SQL_SaveDataPlayer(Database db, DBResultSet dbRs, const char[] sError, int iUserID)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_SaveDataPlayer - error while working with data (%s)", sError);
		return;
	}
}

void ResetDataPlayer(int iClient, int iAccountID)
{
	g_iMapCountPlay[iClient] = 1;
	g_iMapCountRoundsOverall[iClient] = 0;
	g_iMapCountRound[iClient][0] = 0;
	g_iMapCountRound[iClient][1] = 0;
	g_iMapCountTime[iClient] = 0;
	g_iMapCount_BPlanted[iClient] = 0;
	g_iMapCount_BDefused[iClient] = 0;
	g_iMapCount_HRescued[iClient] = 0;
	g_iMapCount_HKilled[iClient] = 0;
	g_bPlayerActive[iClient] = true;
}

void DatabaseCleanup(Transaction hQuery)
{
	char sQuery[196];
	FormatEx(sQuery, sizeof(sQuery), "TRUNCATE TABLE `%s_maps`;", g_sTableName);
	hQuery.AddQuery(sQuery);
}

public void OnClientDisconnect(int iClient)
{
	SaveDataPlayer(iClient);
	g_bPlayerActive[iClient] = false;
}

public void OnPluginEnd()
{
	for(int iClient = MaxClients + 1; --iClient;)
	{
		if(IsClientInGame(iClient))
		{
			OnClientDisconnect(iClient);	
		}
	}
}