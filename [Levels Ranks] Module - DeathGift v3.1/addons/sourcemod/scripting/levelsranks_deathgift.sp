#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - DeathGift"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int				g_iCvarChance,
				g_iCvarLifeTime,
				g_iCvarValue;
bool				g_bCvarRotate;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void LR_OnCoreIsReady()
{
	ConfigLoad();
}

public void OnPluginStart()
{
	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	HookEvent("player_death", PlayerDeath);
	LoadTranslations("lr_module_deathgift.phrases");
}

public void OnMapStart()
{
	AddFileToDownloadsTable("sound/levels_ranks/deathgift_drop.mp3");
	AddFileToDownloadsTable("sound/levels_ranks/deathgift_pickup.mp3");

	switch(GetEngineVersion())
	{
		case Engine_CSGO:
		{
			int iStringTable = FindStringTable("soundprecache");
			AddToStringTable(iStringTable, "levels_ranks/deathgift_drop.mp3");
			AddToStringTable(iStringTable, "levels_ranks/deathgift_pickup.mp3");
		}

		default:
		{
			PrecacheSound("levels_ranks/deathgift_drop.mp3");
			PrecacheSound("levels_ranks/deathgift_pickup.mp3");
		}
	}

	PrecacheModel("models/props/cs_italy/bananna_bunch.mdl", true);
	ConfigLoad();
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/deathgift.ini");
	KeyValues hLR_DeathGift = new KeyValues("DeathGift");
	g_iCvarChance = 0;

	if(!hLR_DeathGift.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	if(!LR_GetSettingsValue(LR_TypeStatistics))
	{
		g_iCvarChance = hLR_DeathGift.GetNum("lr_gifts_chance", 40);
		if(g_iCvarChance > 100) g_iCvarChance = 40;
	}

	g_iCvarLifeTime = hLR_DeathGift.GetNum("lr_gifts_lifetime", 10);
	g_iCvarValue = hLR_DeathGift.GetNum("lr_gifts_value", 1);
	g_bCvarRotate = view_as<bool>(hLR_DeathGift.GetNum("lr_gifts_rotate", 1));

	hLR_DeathGift.Close();
}

public void PlayerDeath(Handle event, char[] name, bool dontBroadcast)
{
	if(g_iCvarChance > 0 && g_iCvarLifeTime > 0 && g_iCvarValue > 0 && LR_CheckCountPlayers())
	{
		int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
		if(GetRandomInt(1, 100) <= g_iCvarChance)
		{
			float fPos[3];
			GetClientAbsOrigin(iClient, fPos); fPos[2] -= 20.0;
			SpawnGift(iClient, fPos, "models/props/cs_italy/bananna_bunch.mdl");
		}
	}
}

void SpawnGift(int iClient, float fPos[3], const char[] sModel)
{
	int iEntity = CreateEntityByName("prop_physics_override");
	if(iEntity)
	{
		static char sTargetName[32];
		FormatEx(sTargetName, sizeof(sTargetName), "gift_%i", iEntity);
		DispatchKeyValue(iEntity, "physicsmode", "2");
		DispatchKeyValue(iEntity, "massScale", "1.0");
		DispatchKeyValue(iEntity, "classname", "gift");
		DispatchKeyValue(iEntity, "model", sModel);
		DispatchKeyValue(iEntity, "targetname", sTargetName);
		DispatchKeyValueVector(iEntity, "origin", fPos);

		if(DispatchSpawn(iEntity))
		{
			static char sBuffer[256];
			SetEntProp(iEntity, Prop_Send, "m_usSolidFlags", 8);
			SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 1);

			FormatEx(sBuffer, sizeof(sBuffer), "OnUser1 !self:kill::%i:-1", g_iCvarLifeTime);
			SetVariantString(sBuffer);
			AcceptEntityInput(iEntity, "AddOutput"); 
			AcceptEntityInput(iEntity, "FireUser1");
			SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", iClient);

			if(g_bCvarRotate)
			{
				int iRotating = CreateEntityByName("func_rotating");
				DispatchKeyValueVector(iRotating, "origin", fPos);
				FormatEx(sTargetName, sizeof(sTargetName), "rotating_%i", iRotating);
				DispatchKeyValue(iRotating, "targetname", sTargetName);
				DispatchKeyValue(iRotating, "maxspeed", "160");
				DispatchKeyValue(iRotating, "friction", "0");
				DispatchKeyValue(iRotating, "dmg", "0");
				DispatchKeyValue(iRotating, "solid", "0");
				DispatchKeyValue(iRotating, "spawnflags", "64");
				DispatchSpawn(iRotating);
				
				SetEntPropEnt(iRotating, Prop_Send, "m_hOwnerEntity", iEntity);

				SetVariantString("!activator");
				AcceptEntityInput(iEntity, "SetParent", iRotating, iRotating);

				FormatEx(sBuffer, sizeof(sBuffer), "%s,Kill,,0,-1", sTargetName);
				DispatchKeyValue(iEntity, "OnKilled", sBuffer);
				AcceptEntityInput(iRotating, "Start");
			}
			else SetEntityMoveType(iEntity, MOVETYPE_NONE);

			SDKHook(iEntity, SDKHook_StartTouch, OnStartTouchPost);
			EmitAmbientSound("levels_ranks/deathgift_drop.mp3", fPos, iEntity, SNDLEVEL_NORMAL);
		}
	}
}

public void OnStartTouchPost(int iEntity, int iClient)
{
	if(iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient) || IsFakeClient(iClient))
		return;

	float fPos[3];
	GetClientAbsOrigin(iClient, fPos);
	LR_ChangeClientValue(iClient, g_iCvarValue);
	LR_PrintToChat(iClient, true, "%T", "TouchGiftExp", iClient, LR_GetClientInfo(iClient, ST_EXP), g_iCvarValue);

	EmitAmbientSound("levels_ranks/deathgift_pickup.mp3", fPos, iEntity, SNDLEVEL_NORMAL);
	if(IsValidEntity(iEntity))
	{
		AcceptEntityInput(iEntity, "Kill");
	}
	SDKUnhook(iEntity, SDKHook_StartTouch, OnStartTouchPost);
}