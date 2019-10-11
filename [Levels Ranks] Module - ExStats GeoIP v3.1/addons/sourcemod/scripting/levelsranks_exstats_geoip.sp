#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <geoip>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - ExStats GeoIP"
#define PLUGIN_AUTHOR "RoadSide Romeo"

char				g_sTableName[32];
Database		g_hDatabase;
EngineVersion	g_iEngine;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void LR_OnCoreIsReady()
{
    OnAllPluginsLoaded();
}

public void OnAllPluginsLoaded()
{
	LR_Hook(LR_OnPlayerLoaded, LoadDataPlayer);
	LR_Hook(LR_OnDatabaseCleanup, DatabaseCleanup);

	if(!g_hDatabase)
	{
		char sQuery[384];
		g_iEngine = GetEngineVersion();
		g_hDatabase = LR_GetDatabase();
		LR_GetTableName(g_sTableName, sizeof(g_sTableName));

		SQL_LockDatabase(g_hDatabase);

		if(!LR_GetDatabaseType())
		{
			FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s_geoip` (`steam` varchar(32) NOT NULL default '' PRIMARY KEY, `clientip` varchar(16) NOT NULL default '', `country` varchar(48) NOT NULL default '', `region` varchar(48) NOT NULL default '', `city` varchar(48) NOT NULL default '', `country_code` varchar(4) NOT NULL default '') CHARSET=utf8 COLLATE utf8_general_ci", g_sTableName);
			SQL_FastQuery(g_hDatabase, sQuery);
		}
		else SetFailState(PLUGIN_NAME ... " : OnAllPluginsLoaded - not MySQL");

		SQL_UnlockDatabase(g_hDatabase);
		g_hDatabase.SetCharset("utf8");

		for(int iClient = MaxClients + 1; --iClient;)
		{
			if(LR_GetClientStatus(iClient))
			{
				LoadDataPlayer(iClient, GetSteamAccountID(iClient));
			}
		}
	}
}

void LoadDataPlayer(int iClient, int iAccountID)
{
	char sQuery[1024], sIp[16], sCity[45], sRegion[45], sCountry[45], sCountryCode[3];
	GetClientIP(iClient, sIp, sizeof(sIp));
	GeoipCity(sIp, sCity, sizeof(sCity));
	GeoipRegion(sIp, sRegion, sizeof(sRegion));
	GeoipCountry(sIp, sCountry, sizeof(sCountry));
	GeoipCode2(sIp, sCountryCode);
	FormatEx(sQuery, sizeof(sQuery), "INSERT IGNORE INTO `%s_geoip` SET `steam` = 'STEAM_%i:%i:%i', `clientip` = '%s', `country` = '%s', `region` = '%s', `city` = '%s', `country_code` = '%s' ON DUPLICATE KEY UPDATE `clientip` = '%s', `country` = '%s', `region` = '%s', `city` = '%s', `country_code` = '%s';", g_sTableName, g_iEngine == Engine_CSGO, iAccountID & 1, iAccountID >>> 1, sIp, sCountry, sRegion, sCity, sCountryCode, sIp, sCountry, sRegion, sCity, sCountryCode);
	g_hDatabase.Query(SQL_LoadDataPlayer, sQuery);
}

public void SQL_LoadDataPlayer(Database db, DBResultSet dbRs, const char[] sError, any data)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_LoadDataPlayer - %s", sError);
		return;
	}
}

void DatabaseCleanup(Transaction hQuery)
{
	char sQuery[64];
	FormatEx(sQuery, sizeof(sQuery), "TRUNCATE TABLE `%s_geoip`;", g_sTableName);
	hQuery.AddQuery(sQuery);
}