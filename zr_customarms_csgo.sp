#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <zombiereloaded>
#include <cstrike>

public Plugin:myinfo =
{
	name = "ZR Custom CS:GO Arms",
	author = "Franc1sco franug",
	description = "",
	version = "4.0",
	url = "http://www.zeuszombie.com"
};

new Handle:kv;
new Handle:hPlayerClasses, String:sClassPath[PLATFORM_MAX_PATH] = "configs/zr/playerclasses.txt";

new Handle:trie_classes;


new String:manos[MAXPLAYERS+1][128];

public OnPluginStart() 
{
	trie_classes = CreateTrie();

	HookEvent("player_spawn", OnSpawn);
	
	HookEvent("round_start", Restart);
	
	for(new i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i)) OnClientPutInServer(i);
}

public OnClientPutInServer(client)
{
	Format(manos[client], 128, "models/weapons/ct_arms_gign.mdl");
}

public OnMapStart()
{
	PrecacheModel("models/weapons/ct_arms_gign.mdl");
}

public Action:OnSpawn(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsPlayerAlive(client) && ZR_IsClientHuman(client)) GetEntPropString(client, Prop_Send, "m_szArmsModel", manos[client], 64);
	
	Arms(client);
}

public ZR_OnClientInfected(client, attacker, bool:motherInfect, bool:respawnOverride, bool:respawn)
{
	Arms(client);
}

public ZR_OnClientHumanPost(client, bool:respawn, bool:protect)
{
	Arms(client);
}

Arms(client)
{
	if(!IsPlayerAlive(client)) return;
	
	new cindex = ZR_GetActiveClass(client);
	if(!ZR_IsValidClassIndex(cindex)) return;
	
	decl String:namet[64],String:model[128], String:currentmodel[128];
	ZR_GetClassDisplayName(cindex, namet, sizeof(namet));
	if(!GetTrieString(trie_classes, namet, model, sizeof(model))) return;
	
	GetEntPropString(client, Prop_Send, "m_szArmsModel", currentmodel, sizeof(currentmodel));
	
	if(strlen(model) > 3) 
	{
		if(!StrEqual(currentmodel, model)) SetEntPropString(client, Prop_Send, "m_szArmsModel", model);
		//PrintToChat(client, "used %s with class %i",model, cindex);
	}
	else
	{
		if(!StrEqual(currentmodel, manos[client])) SetEntPropString(client, Prop_Send, "m_szArmsModel", manos[client]);
		//PrintToChat(client, "used %s with class %i",manos[client], cindex);
	}
}

public Action:Restart(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(0.5, Cleaner);
	CreateTimer(0.75, Cleaner);
}

public Action:Cleaner(Handle:timer)
{
 	for (new i = 1; i < MaxClients; i++)
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			Arms(i);
			if(GetClientTeam(i) == CS_TEAM_T)
			{
				CS_SwitchTeam(i, CS_TEAM_CT);
			}
			else if(GetClientTeam(i) == CS_TEAM_CT)
			{
				CS_SwitchTeam(i, CS_TEAM_T);
			}
		}
}

//

public OnAllPluginsLoaded()
{
	if (hPlayerClasses != INVALID_HANDLE)
	{
		UnhookConVarChange(hPlayerClasses, OnClassPathChange);
		CloseHandle(hPlayerClasses);
	}
	if ((hPlayerClasses = FindConVar("zr_config_path_playerclasses")) == INVALID_HANDLE)
	{
		SetFailState("Zombie:Reloaded is not running on this server");
	}
	HookConVarChange(hPlayerClasses, OnClassPathChange);
}

public OnClassPathChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	strcopy(sClassPath, sizeof(sClassPath), newValue);
	OnConfigsExecuted();
}

public OnConfigsExecuted()
{
	CreateTimer(0.2, OnConfigsExecutedPost);
}

public Action:OnConfigsExecutedPost(Handle:timer)
{
	if (kv != INVALID_HANDLE)
	{
		CloseHandle(kv);
	}
	kv = CreateKeyValues("classes");
	
	decl String:buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof(buffer), "%s", sClassPath);
	
	if (!FileToKeyValues(kv, buffer))
	{
		SetFailState("Class data file \"%s\" not found", buffer);
	}
	
	if (KvGotoFirstSubKey(kv))
	{
		ClearTrie(trie_classes);
		decl String:name[64],String:model[128];
		
		do
		{
			KvGetString(kv, "name", name, sizeof(name));
			KvGetString(kv, "arms_path", model, sizeof(model), " ");
			
			SetTrieString(trie_classes, name, model);
			
			if(strlen(model) > 3 && FileExists(model) && !IsModelPrecached(model)) PrecacheModel(model);
			
		} while (KvGotoNextKey(kv));
	}
	KvRewind(kv);
}
	