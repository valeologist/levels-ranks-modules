#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <lvl_ranks>
#include <clientprefs>

#define PLUGIN_NAME "[LR] Module - Unlimited Ammo"
#define PLUGIN_AUTHOR "RoadSide Romeo & Kaneki"

int		g_iLevel;
bool		g_bActive[MAXPLAYERS+1];
Handle	g_hTrie,
		g_hUnlimitedAmmo;
ConVar	g_iType;

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
		case Engine_CSGO: LoadTranslations("lr_module_unlimitedammo.phrases");
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);

	g_hTrie = CreateTrie();
	
	g_iType = CreateConVar("lr_unlim_type", "1", "1 = бесконечные патроны в запасе, 0 = бесконечная обойма.");
	g_hUnlimitedAmmo = RegClientCookie("LR_Unlim", "LR_Unlim", CookieAccess_Private);
	
	HookEvent("weapon_fire", WeaponFire);
	AutoExecConfig(true, "LR_UnlimAmmo", "levels_ranks");

	for(int iClient = 1; iClient <= MaxClients; iClient++)
    {
		if(IsClientInGame(iClient))
		{
			OnClientPutInServer(iClient);
			OnClientCookiesCached(iClient);
		}
	}
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/unlimited_ammo.ini");
	KeyValues hLR_UA = new KeyValues("UnlimitedAmmo");

	if(!hLR_UA.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR_UA.GetNum("rank", 0);

	hLR_UA.Close();
}

public void WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));

	if(g_iType.IntValue == 0 && !g_bActive[iClient] && LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		Type1(iClient);
	}
	else if(g_iType.IntValue == 1 && !g_bActive[iClient] && LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		if(IsPlayerAlive(iClient))
		{
			int weapon = GetEntPropEnt(iClient, Prop_Data, "m_hActiveWeapon");
			if(weapon > 0 && (weapon == GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY) || weapon == GetPlayerWeaponSlot(iClient, CS_SLOT_SECONDARY)))
			{
				int warray;
				char classname[4];
				Format(classname, 4, "%i", GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"));
			
				if(GetTrieValue(g_hTrie, classname, warray))
				{
					if(GetReserveAmmo(weapon) != warray) SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", warray);
				}
			}
		}
	}
}

public void OnClientPutInServer(int iClient) 
{
	SDKHook(iClient, SDKHook_WeaponEquipPost, EventItemPickup2);
}

void Type1(int iClient)
{
	int WeaponIndex = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (WeaponIndex == -1) 
		return;
	int ClipAmmo = GetEntProp(WeaponIndex, Prop_Send, "m_iClip1");
	if (!ClipAmmo) 
		return;
	SetEntProp(WeaponIndex, Prop_Send, "m_iClip1", 100);
}

stock int GetReserveAmmo(int weapon)
{
    return GetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
}

public Action EventItemPickup2(int iClient, int weapon)
{
	if(weapon == GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY) || weapon == GetPlayerWeaponSlot(iClient, CS_SLOT_SECONDARY))
	{
		int warray;
		char classname[4];
		Format(classname, 4, "%i", GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"));
	
		if(!GetTrieValue(g_hTrie, classname, warray))
		{
			warray = GetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
		
			SetTrieValue(g_hTrie, classname, warray);
		}
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "Unlim_On" : "Unlim_Off", iClient);
		hMenu.AddItem("UnlimitedAmmo", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "Unlim_Closed", iClient, g_iLevel);
		hMenu.AddItem("UnlimitedAmmo", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "UnlimitedAmmo"))
	{
		g_bActive[iClient] = !g_bActive[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hUnlimitedAmmo, sCookie, sizeof(sCookie));
	g_bActive[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bActive[iClient]);
	SetClientCookie(iClient, g_hUnlimitedAmmo, sCookie);
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