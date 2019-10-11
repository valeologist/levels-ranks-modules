#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Overlays"
#define PLUGIN_AUTHOR "RoadSide Romeo"

bool		g_bOffOverlay[MAXPLAYERS+1];
char		g_sOverlaysPath[128][256];
Handle	g_hOverlays;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void LR_OnCoreIsReady()
{
    ConfigLoad();
}

public void OnPluginStart()
{
	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_Hook(LR_OnLevelChangedPost, OnLevelChanged);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);

	g_hOverlays = RegClientCookie("LR_Overlays", "LR_Overlays", CookieAccess_Private);
	LoadTranslations("lr_module_overlays.phrases");

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
	char sPathDownload[256];
	File hFile = OpenFile("addons/sourcemod/configs/levels_ranks/downloads_overlays.ini", "r");
	if(!hFile) SetFailState(PLUGIN_NAME ... " : Unable to load (addons/sourcemod/configs/levels_ranks/downloads_overlays.ini)");
	while(hFile.ReadLine(sPathDownload, sizeof(sPathDownload)))
	{
		TrimString(sPathDownload);
		if(sPathDownload[0])
		{
			AddFileToDownloadsTable(sPathDownload);
		}
	}

	hFile.Close();

	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/overlays.ini");
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT));
	KeyValues hLR_Overlay = new KeyValues("Overlays");

	if(!hLR_Overlay.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	hLR_Overlay.GotoFirstSubKey();
	hLR_Overlay.Rewind();

	if(hLR_Overlay.JumpToKey("Overlays"))
	{
		int iOverlayCount;
		hLR_Overlay.GotoFirstSubKey();

		do
		{
			hLR_Overlay.GetString("overlay", g_sOverlaysPath[iOverlayCount], 256);
			iOverlayCount++;
		}
		while(hLR_Overlay.GotoNextKey());

		if(iOverlayCount != LR_GetRankExp().Length) SetFailState(PLUGIN_NAME ... " : The number of ranks does not match the specified number in the core (%s)", sPath);
	}
	else SetFailState(PLUGIN_NAME ... " : Section Overlays is not found (%s)", sPath);
	hLR_Overlay.Close();
}

void LR_OnMenuCreated(LR_MenuType OnMenuCreated, int iClient, Menu hMenu)
{
	char sText[64];
	FormatEx(sText, sizeof(sText), "%T", !g_bOffOverlay[iClient] ? "Overlay_MenuOff" : "Overlay_MenuOn", iClient);
	hMenu.AddItem("Overlays", sText);
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuCreated, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Overlays"))
	{
		g_bOffOverlay[iClient] = !g_bOffOverlay[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

void OnLevelChanged(int iClient, int iNewLevel, int iOldLevel)
{
	if(!g_bOffOverlay[iClient])
	{
		ClientCommand(iClient, "r_screenoverlay %s", g_sOverlaysPath[iNewLevel - 1]);
		CreateTimer(3.0, DeleteOverlay, GetClientUserId(iClient));
	}
}

public Action DeleteOverlay(Handle hTimer, any iUserid)
{
	int iClient = GetClientOfUserId(iUserid);
	if(iClient && IsClientInGame(iClient))
	{
		ClientCommand(iClient, "r_screenoverlay off");
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hOverlays, sCookie, sizeof(sCookie));
	g_bOffOverlay[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bOffOverlay[iClient]);
	SetClientCookie(iClient, g_hOverlays, sCookie);
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