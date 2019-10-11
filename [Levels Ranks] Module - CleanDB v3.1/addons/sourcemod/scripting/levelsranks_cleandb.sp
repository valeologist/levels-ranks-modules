#pragma semicolon 1
#pragma newdecls required

#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - CleanDB"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int				g_iDB_DaysCleaner,
				g_iAccountID[MAXPLAYERS+1];
bool				g_bDB_BanClient;
char				g_sTableName[32];
Database		g_hDatabase;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void LR_OnCoreIsReady()
{
	OnAllPluginsLoaded();
}

public void OnAllPluginsLoaded()
{
	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_Hook(LR_OnPlayerLoaded, OnPlayerLoaded);

	if(!g_hDatabase)
	{
		g_hDatabase = LR_GetDatabase();
		g_hDatabase.SetCharset("utf8");
		ConfigLoad();
	}
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/cleandb.ini");
	LR_GetTableName(g_sTableName, sizeof(g_sTableName));
	KeyValues hLR_Settings = new KeyValues("CleanDB");

	if(!hLR_Settings.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iDB_DaysCleaner = hLR_Settings.GetNum("lr_db_cleaner", 14);
	g_bDB_BanClient = view_as<bool>(hLR_Settings.GetNum("lr_db_banclient", 1));

	hLR_Settings.Close();
}

void OnPlayerLoaded(int iClient, int iAccountID)
{
	g_iAccountID[iClient] = iAccountID;
}

public Action OnBanClient(int iClient, int iTime, int iFlags, const char[] sReason, const char[] sKick_message, const char[] sCommand, any source)
{
	if(g_bDB_BanClient)
	{
		char sQuery[256];
		FormatEx(sQuery, sizeof(sQuery), "UPDATE `%s` SET `lastconnect` = 0 WHERE `steam` = 'STEAM_%i:%i:%i';", g_sTableName, GetEngineVersion() == Engine_CSGO, g_iAccountID[iClient] & 1, g_iAccountID[iClient] >> 1);
		g_hDatabase.Query(SQL_Callback, sQuery);
	}
}

public void OnMapEnd()
{
	if(g_iDB_DaysCleaner)
	{
		char sQuery[256];
		FormatEx(sQuery, sizeof(sQuery), "UPDATE `%s` SET `lastconnect` = 0 WHERE `lastconnect` < %d AND `lastconnect` != 0;", g_sTableName, GetTime() - (g_iDB_DaysCleaner * 86400));
		g_hDatabase.Query(SQL_Callback, sQuery);
	}
}

public void SQL_Callback(Database db, DBResultSet dbRs, const char[] sError, any data)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_Callback - error while working with data (%s)", sError);
		return;
	}
}