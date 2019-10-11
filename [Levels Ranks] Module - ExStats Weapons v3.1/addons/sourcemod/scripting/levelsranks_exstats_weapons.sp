#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - ExStats Weapons"
#define PLUGIN_AUTHOR "RoadSide Romeo & Wend4r"

enum struct WeaponsData
{
	bool 	bShowTop;
	float 	fCoefficient;
	char 	sName[64];
}

int				g_iCountWeapons,
				g_iAccountID[MAXPLAYERS+1],
				g_iWeaponsStats[MAXPLAYERS+1][96];
bool				g_bWeaponsCoeffActive;
char				g_sTableName[32], g_sPluginTitle[64], g_sWeaponsClassName[96][64];
Database		g_hDatabase;
StringMap		g_hWeapons;
EngineVersion	g_iEngine;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void LR_OnCoreIsReady()
{
    OnAllPluginsLoaded();
}

public void OnAllPluginsLoaded()
{
	LoadTranslations("lr_module_exweapons.phrases");

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_Hook(LR_OnPlayerLoaded, LoadDataPlayer);
	LR_Hook(LR_OnPlayerSaved, SaveDataPlayer);
	LR_Hook(LR_OnResetPlayerStats, ResetDataPlayer);
	LR_Hook(LR_OnDatabaseCleanup, DatabaseCleanup);
	LR_Hook(LR_OnPlayerKilledPre, view_as<LR_HookCB>(PlayerKilled));

	LR_MenuHook(LR_TopMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
	LR_MenuHook(LR_MyStatsSecondary, LR_OnMenuCreated, LR_OnMenuItemSelected);

	if(!g_hDatabase)
	{
		char sQuery[512];
		g_iEngine = GetEngineVersion();
		g_hWeapons = new StringMap();
		LR_GetTableName(g_sTableName, sizeof(g_sTableName));
		LR_GetTitleMenu(g_sPluginTitle, sizeof(g_sPluginTitle));

		SQL_LockDatabase((g_hDatabase = LR_GetDatabase()));

		FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s_weapons` (`steam` varchar(32) NOT NULL default '', `classname` varchar(64) NOT NULL default '', `kills` int NOT NULL default 0, PRIMARY KEY (`steam`, `classname`))%s", g_sTableName, LR_GetDatabaseType() ? ";" : " CHARSET=utf8 COLLATE utf8_general_ci");
		if(!SQL_FastQuery(g_hDatabase, sQuery)) SetFailState(PLUGIN_NAME ... " : OnAllPluginsLoaded - could not create table (You must to reset the database)");

		SQL_UnlockDatabase(g_hDatabase);
		g_hDatabase.SetCharset("utf8");

		for(int iClient = MaxClients + 1; --iClient;)
		{
			if(LR_GetClientStatus(iClient))
			{
				LoadDataPlayer(iClient, GetSteamAccountID(iClient));
			}
		}
		ConfigLoad();
	}
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(sPath[0] == '\0') BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/exstats_weapons.ini");
	KeyValues hLR_ExWeapons = new KeyValues("ExStats_Weapons");

	if(!hLR_ExWeapons.ImportFromFile(sPath))
	{
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);
	}

	hLR_ExWeapons.GotoFirstSubKey();
	hLR_ExWeapons.Rewind();

	if(hLR_ExWeapons.JumpToKey("WeaponsList"))
	{
		g_iCountWeapons = 0;
		WeaponsData iWeaponStruct;

		g_bWeaponsCoeffActive = view_as<bool>(hLR_ExWeapons.GetNum("weapon_coefficient", 1));
		hLR_ExWeapons.GotoFirstSubKey();

		do
		{
			hLR_ExWeapons.GetSectionName(g_sWeaponsClassName[g_iCountWeapons], sizeof(g_sWeaponsClassName[]));
			hLR_ExWeapons.GetString("name", iWeaponStruct.sName, sizeof(iWeaponStruct.sName));
			iWeaponStruct.bShowTop = view_as<bool>(hLR_ExWeapons.GetNum("showtop", 0));
			iWeaponStruct.fCoefficient = hLR_ExWeapons.GetFloat("coefficient", 1.0);
			g_hWeapons.SetArray(g_sWeaponsClassName[g_iCountWeapons++], iWeaponStruct, sizeof(WeaponsData));
		}
		while(hLR_ExWeapons.GotoNextKey());
	}
	else SetFailState(PLUGIN_NAME ... " : Section WeaponsList is not found (%s)", sPath);
	hLR_ExWeapons.Close();
}

void PlayerKilled(Event hEvent, int& iExpGive)
{
	if(LR_CheckCountPlayers())
	{
		int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
		char sBuffer[48], sClassname[64];

		GetEventString(hEvent, "weapon", sBuffer, sizeof(sBuffer));
		FormatEx(sClassname, sizeof(sClassname), "weapon_%s", sBuffer);

		if(sBuffer[0] == 'k' || !strcmp(sBuffer, "bayonet"))
		{
			sClassname = "weapon_knife";
		}

		for(int i; i != g_iCountWeapons; i++)
		{
			if(!strcmp(sClassname, g_sWeaponsClassName[i]))
			{
				if(g_bWeaponsCoeffActive)
				{
					WeaponsData iWeaponStruct;
					g_hWeapons.GetArray(sClassname, iWeaponStruct, sizeof(WeaponsData));
					iExpGive = RoundToNearest(iExpGive * iWeaponStruct.fCoefficient);
				}
				g_iWeaponsStats[iAttacker][i]++;
				break;
			}
		}
	}
}

public void OnClientSayCommand_Post(int iClient, const char[] sCommand, const char[] sArgs)
{
	static StringMap hCommands;
	if(!hCommands)
	{
		(hCommands = new StringMap()).SetValue("topkills", 0);
		hCommands.SetValue("!topkills", 0);
		hCommands.SetValue("topweapons", 1);
		hCommands.SetValue("!topweapons", 1);
	}

	int iValue;
	if(hCommands.GetValue(sArgs, iValue))
	{
		if(iValue) TOPGeneralWeapon(iClient);
		else TOPGeneral(iClient);
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	static char sText[64];
	switch(OnMenuType)
	{
		case LR_TopMenu:
		{
			FormatEx(sText, sizeof(sText), "%T", "TOPGeneral", iClient);
			hMenu.AddItem("topgeneral", sText);
		}

		case LR_MyStatsSecondary:
		{
			FormatEx(sText, sizeof(sText), "%T", "DataAllWeapons", iClient);
			hMenu.AddItem("weapon_stats", sText);
		}
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	switch(OnMenuType)
	{
		case LR_TopMenu:
		{
			if(!strcmp(sInfo, "topgeneral"))
			{
				TOPGeneral(iClient);
			}
		}

		case LR_MyStatsSecondary:
		{
			if(!strcmp(sInfo, "weapon_stats"))
			{
				WeaponsPlayerStats(iClient);
			}
		}
	}
}

void TOPGeneral(int iClient)
{
	static char sText[128];
	Menu hMenu = new Menu(TOPGeneralHandler);
	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "TOPGeneral", iClient);

	FormatEx(sText, sizeof(sText), "%T", "TOPGeneralCount", iClient);
	hMenu.AddItem(NULL_STRING, sText);

	FormatEx(sText, sizeof(sText), "%T", "TOPGeneralWeapon", iClient);
	hMenu.AddItem(NULL_STRING, sText);

	hMenu.ExitBackButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int TOPGeneralHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel:
		{
			if(iSlot == MenuCancel_ExitBack)
			{
				LR_ShowMenu(iClient, LR_TopMenu);
			}
		}

		case MenuAction_Select:
		{
			if(!iSlot)
			{
				TOPGeneralCount(iClient);
			}
			else TOPGeneralWeapon(iClient);
		}
	}
}

void TOPGeneralCount(int iClient)
{
	if(LR_GetClientStatus(iClient))
	{
		static char sQuery[512];
		FormatEx(sQuery, sizeof(sQuery), "SELECT `name`, `kills` FROM `%s` WHERE `lastconnect` > 0 ORDER BY `kills` DESC LIMIT 10 OFFSET 0", g_sTableName);
		g_hDatabase.Query(SQL_TOPGeneralCount, sQuery, GetClientUserId(iClient));
	}
}

public void SQL_TOPGeneralCount(Database db, DBResultSet dbRs, const char[] sError, any iUserID)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_TOPGeneralCount - error while working with data (%s)", sError);
		return;
	}

	int i;
	char sText[256], sName[24], sTemp[640];
	int iClient = GetClientOfUserId(iUserID);

	if(iClient && dbRs.HasResults)
	{
		while(dbRs.FetchRow())
		{
			i++;
			dbRs.FetchString(0, sName, sizeof(sName));
			FormatEx(sText, sizeof(sText), "%T\n", "TOPList", iClient, i, dbRs.FetchInt(1), sName);
			
			if(strlen(sTemp) + strlen(sText) < 640)
			{
				Format(sTemp, sizeof(sTemp), "%s%s", sTemp, sText);
				sText = "\0";
			}
		}

		Menu hMenu = new Menu(TOPGeneralCountHandler);
		hMenu.SetTitle("%s | %T\n \n%s\n ", g_sPluginTitle, "TOPGeneralCount", iClient, sTemp);

		FormatEx(sText, sizeof(sText), "%T", "Back", iClient);
		hMenu.AddItem(NULL_STRING, sText);

		hMenu.Display(iClient, MENU_TIME_FOREVER);
	}
}

public int TOPGeneralCountHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Select: TOPGeneral(iClient);
	}
}

void TOPGeneralWeapon(int iClient)
{
	static char sBuffer[4], sText[128];
	WeaponsData iWeaponStruct;
	Menu hMenu = new Menu(TOPGeneralWeaponHandler);

	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "TOPGeneralWeapon", iClient);
	for(int i; i != g_iCountWeapons; i++)
	{
		g_hWeapons.GetArray(g_sWeaponsClassName[i], iWeaponStruct, sizeof(WeaponsData));

		if(iWeaponStruct.bShowTop)
		{
			FormatEx(sText, sizeof(sText), "%T", "TOPWeapon", iClient, iWeaponStruct.sName);
			IntToString(i, sBuffer, sizeof(sBuffer));
			hMenu.AddItem(sBuffer, sText);
		}
	}

	hMenu.ExitBackButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int TOPGeneralWeaponHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel:
		{
			if(iSlot == MenuCancel_ExitBack)
			{
				TOPGeneral(iClient);
			}
		}

		case MenuAction_Select:
		{
			char sInfo[4]; hMenu.GetItem(iSlot, sInfo, sizeof(sInfo));
			PrintTopWeapons(iClient, StringToInt(sInfo));
		}
	}
}

void PrintTopWeapons(int iClient, int iIndex)
{
	if(LR_GetClientStatus(iClient))
	{
		char sQuery[1024];
		int iUserID = GetClientUserId(iClient);
		FormatEx(sQuery, sizeof(sQuery), "SELECT `%s`.`name`, `%s_weapons`.`kills` FROM `%s`, `%s_weapons` WHERE `%s`.`lastconnect` != 0 AND `%s`.`steam` = `%s_weapons`.`steam` AND `classname` = '%s' ORDER BY `%s_weapons`.`kills` DESC LIMIT 10 OFFSET 0", g_sTableName, g_sTableName, g_sTableName, g_sTableName, g_sTableName, g_sTableName, g_sTableName, g_sWeaponsClassName[iIndex], g_sTableName);
		g_hDatabase.Query(SQL_PrintTopWeapons, sQuery, iUserID << 24 | iIndex);
	}
}

public void SQL_PrintTopWeapons(Database db, DBResultSet dbRs, const char[] sError, int iData)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_PrintTopWeapons - error while working with data (%s)", sError);
		return;
	}

	int i;
	char sText[256], sName[24], sTemp[640];

	int iClient = GetClientOfUserId(iData >> 24);
	int iIndex = iData & 0xFFFFFF;

	if(iClient && dbRs.HasResults)
	{
		while(dbRs.FetchRow())
		{
			i++;
			dbRs.FetchString(0, sName, sizeof(sName));
			FormatEx(sText, sizeof(sText), "%T\n", "TOPList", iClient, i, dbRs.FetchInt(1), sName);
			
			if(strlen(sTemp) + strlen(sText) < 640)
			{
				Format(sTemp, sizeof(sTemp), "%s%s", sTemp, sText);
				sText = "\0";
			}
		}

		WeaponsData iWeaponStruct;
		g_hWeapons.GetArray(g_sWeaponsClassName[iIndex], iWeaponStruct, sizeof(WeaponsData));

		Menu hMenu = new Menu(PrintTopWeaponsHandler);
		hMenu.SetTitle("%s | %T\n \n%s\n ", g_sPluginTitle, "TOPWeapon", iClient, iWeaponStruct.sName, sTemp);

		FormatEx(sText, sizeof(sText), "%T", "Back", iClient);
		hMenu.AddItem(NULL_STRING, sText);

		hMenu.ExitButton = true;
		hMenu.Display(iClient, MENU_TIME_FOREVER);
	}
}

public int PrintTopWeaponsHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Select: TOPGeneralWeapon(iClient);
	}
}

void WeaponsPlayerStats(int iClient)
{
	if(LR_GetClientStatus(iClient))
	{
		char sQuery[512];
		FormatEx(sQuery, sizeof(sQuery), "SELECT `classname`, `kills` FROM `%s_weapons` WHERE `steam` = 'STEAM_%i:%i:%i' ORDER BY `kills` DESC", g_sTableName, g_iEngine == Engine_CSGO, g_iAccountID[iClient] & 1, g_iAccountID[iClient] >>> 1);
		g_hDatabase.Query(SQL_WeaponsPlayerStats, sQuery, GetClientUserId(iClient));
	}
}

public void SQL_WeaponsPlayerStats(Database db, DBResultSet dbRs, const char[] sError, int iUserID)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_WeaponsPlayerStats - error while working with data (%s)", sError);
		return;
	}

	int iClient = GetClientOfUserId(iUserID);
	if(iClient && dbRs.HasResults)
	{
		int iKills, iGlobalKills = LR_GetClientInfo(iClient, ST_KILLS);
		char sText[128], sWeaponClassName[24];
		WeaponsData iWeaponStruct;

		Menu hMenu = new Menu(WeaponsPlayerStatsHandler);
		hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "DataAllWeapons", iClient);

		while(dbRs.FetchRow())
		{
			dbRs.FetchString(0, sWeaponClassName, sizeof(sWeaponClassName));
			g_hWeapons.GetArray(sWeaponClassName, iWeaponStruct, sizeof(WeaponsData));
			if(!(iKills = dbRs.FetchInt(1))) break;
			else
			{
				FormatEx(sText, sizeof(sText), "%T", "DataAllWeaponsList", iClient, iWeaponStruct.sName, iKills, RoundToCeil(100.0 / iGlobalKills * iKills));
				hMenu.AddItem(NULL_STRING, sText, ITEMDRAW_DISABLED);
			}
		}

		if(!hMenu.ItemCount)
		{
			FormatEx(sText, sizeof(sText), "%T", "DataAllWeaponsNone", iClient);
			hMenu.AddItem(NULL_STRING, sText, ITEMDRAW_DISABLED);
		}

		hMenu.ExitBackButton = true;
		hMenu.Display(iClient, MENU_TIME_FOREVER);
	}
}

public int WeaponsPlayerStatsHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel:
		{
			if(iSlot == MenuCancel_ExitBack)
			{
				LR_ShowMenu(iClient, LR_MyStatsSecondary);
			}
		}
	}
}

void DatabaseCleanup(Transaction hQuery)
{
	char sQuery[196];
	FormatEx(sQuery, sizeof(sQuery), "TRUNCATE TABLE `%s_weapons`;", g_sTableName);
	hQuery.AddQuery(sQuery);
}

void LoadDataPlayer(int iClient, int iAccountID)
{
	char sQuery[512];
	Transaction hTransaction = new Transaction();
	g_iAccountID[iClient] = iAccountID;

	for(int i; i != g_iCountWeapons; i++)
	{
		FormatEx(sQuery, sizeof(sQuery), "SELECT `kills` FROM `%s_weapons` WHERE `classname` = '%s' AND `steam` = 'STEAM_%i:%i:%i';", g_sTableName, g_sWeaponsClassName[i], g_iEngine == Engine_CSGO, g_iAccountID[iClient] & 1, g_iAccountID[iClient] >>> 1);
		hTransaction.AddQuery(sQuery);
	}

	g_hDatabase.Execute(hTransaction, SQLTransaction_Successful, SQLTransaction_Failure, GetClientUserId(iClient), DBPrio_High);
}

public void SQLTransaction_Successful(Database db, int iUserID, int numQueries, DBResultSet[] results, any[] queryData)
{
	int iClient = GetClientOfUserId(iUserID);
	if(iClient)
	{
		for(int i; i != g_iCountWeapons; i++)
		{
			if(results[i].HasResults && results[i].FetchRow())
			{
				g_iWeaponsStats[iClient][i] = results[i].FetchInt(0);
			}
		}
	}
}

public void SQLTransaction_Failure(Database db, any data, int numQueries, const char[] sError, int failIndex, any[] queryData)
{
	LogError(PLUGIN_NAME ... " : LoadDataPlayer - %s", sError);
}

void SaveDataPlayer(int iClient, Transaction hQuery)
{
	char sQuery[512];
	for(int i; i != g_iCountWeapons; i++)
	{
		if(g_iWeaponsStats[iClient][i])
		{
			FormatEx(sQuery, sizeof(sQuery), "INSERT IGNORE INTO `%s_weapons` SET `steam` = 'STEAM_%i:%i:%i', `classname` = '%s', `kills` = %i ON DUPLICATE KEY UPDATE `kills` = %i;", g_sTableName, g_iEngine == Engine_CSGO, g_iAccountID[iClient] & 1, g_iAccountID[iClient] >>> 1, g_sWeaponsClassName[i], g_iWeaponsStats[iClient][i], g_iWeaponsStats[iClient][i]);
			hQuery.AddQuery(sQuery);
		}
	}
}

void ResetDataPlayer(int iClient, int iAccountID)
{
	for(int i = 0; i != g_iCountWeapons; i++)
	{
		g_iWeaponsStats[iClient][i] = 0;
	}
}