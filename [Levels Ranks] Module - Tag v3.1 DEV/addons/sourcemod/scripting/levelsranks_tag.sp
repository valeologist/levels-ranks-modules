#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Tag"
#define PLUGIN_AUTHOR "RoadSide Romeo"

bool		g_bOffTag[MAXPLAYERS+1];
char		g_sClanTags[128][16];
Handle	g_hTagRank;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION}
public void OnPluginStart()
{
	LR_Hook(LR_OnCoreIsReady, ConfigLoad);
	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);

	HookEvent("player_spawn", PlayerSpawn);
	g_hTagRank = RegClientCookie("LR_TagRank", "LR_TagRank", CookieAccess_Private);
	LoadTranslations("lr_module_tag.phrases");

	for(int iClient = MaxClients + 1; --iClient;)
    {
		if(IsClientInGame(iClient))
		{
			OnClientCookiesCached(iClient);
		}
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
		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/tags.ini");
	}

	KeyValues hLR_Tags = new KeyValues("LR_Tags");
	if(!hLR_Tags.ImportFromFile(sPath))
	{
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);
	}

	hLR_Tags.GotoFirstSubKey();
	hLR_Tags.Rewind();

	if(hLR_Tags.JumpToKey("Tags"))
	{
		int iTagCount;
		hLR_Tags.GotoFirstSubKey();

		do
		{
			hLR_Tags.GetString("tag", g_sClanTags[iTagCount], 16);
			iTagCount++;
		}
		while(hLR_Tags.GotoNextKey());

		if(iTagCount != LR_GetRankExp().Length)
		{
			SetFailState(PLUGIN_NAME ... " : The number of ranks does not match the specified number in the core (%s)", sPath);
		}
	}
	else SetFailState(PLUGIN_NAME ... " : Section Tags is not found (%s)", sPath);
	delete hLR_Tags;
}

public void PlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{	
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(iClient && LR_GetClientStatus(iClient) && !g_bOffTag[iClient])
	{
		CS_SetClientClanTag(iClient, g_sClanTags[LR_GetClientInfo(iClient, ST_RANK) - 1]);
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuCreated, int iClient, Menu hMenu)
{
	char sText[64];
	FormatEx(sText, 64, "%T", !g_bOffTag[iClient] ? "TagRankOn" : "TagRankOff", iClient);
	hMenu.AddItem("RankTag", sText);
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuCreated, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "RankTag"))
	{
		g_bOffTag[iClient] = !g_bOffTag[iClient];
		CS_SetClientClanTag(iClient, g_bOffTag[iClient] ? NULL_STRING : g_sClanTags[LR_GetClientInfo(iClient, ST_RANK) - 1]);
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sBuffer[3];
	GetClientCookie(iClient, g_hTagRank, sBuffer, 3);
	g_bOffTag[iClient] = view_as<bool>(StringToInt(sBuffer));
}

public void OnClientDisconnect(int iClient)
{
	if(AreClientCookiesCached(iClient))
	{
		char sBuffer[3];
		IntToString(g_bOffTag[iClient], sBuffer, sizeof(sBuffer));
		SetClientCookie(iClient, g_hTagRank, sBuffer);	
	}
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