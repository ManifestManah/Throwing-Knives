// List of Includes
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

// The code formatting rules we wish to follow
#pragma semicolon 1;
#pragma newdecls required;

// The retrievable information about the plugin itself 
public Plugin myinfo =
{
	name		= "[CS:GO] Throwing Knives",
	author		= "Manifest @Road To Glory & Bacardi & meng",
	description	= "Using left attack while holding a knife, will let the player throw a knife.",
	version		= "V. 1.0.0 [Beta]",
	url			= ""
};


// Global Bools
bool attackIsAHeadshot[MAXPLAYERS + 1];
bool playerHasAccessCustom1[MAXPLAYERS + 1];

// Global Integers
int effectBeamMaterial = 0;
int playerCarryingThrowingKnives[MAXPLAYERS + 1];

// Global Handles
Handle arrayKnivesThrown; // Store thrown knives
Handle knifeCreationTimerHandle[MAXPLAYERS + 1];

// Global ConVar Handles
Handle cvar_throwingknives_count;
Handle cvar_throwingknives_steal;
Handle cvar_throwingknives_velocity;
Handle cvar_throwingknives_damage;
Handle cvar_throwingknives_hsdamage;
Handle cvar_throwingknives_modelscale;
Handle cvar_throwingknives_gravity;
Handle cvar_throwingknives_elasticity;
Handle cvar_throwingknives_maxlifetime;
Handle cvar_throwingknives_trails;
Handle cvar_throwingknives_admins;



//////////////////////////
// - Forwards & Hooks - //
//////////////////////////


// This happens when the plugin is loaded
public void OnPluginStart()
{
	// If the game is anything else than CS:GO then execute this section
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("[CS:GO] This version of throwing knives only supports Counter-Strike: Global Offensive.");

		return;
	}

	// Defines the values of the ConVars the plugin will be making use of
	cvar_throwingknives_count 		= CreateConVar("sm_throwingknives_count", 			"3", 		"Amount of knives players spawn with. 0 = Disable, -1 = infinite", _, true, -1.0);
	cvar_throwingknives_steal 		= CreateConVar("sm_throwingknives_steal", 			"1", 		"If enabled, knife kills get the victims remaining knives.", _, true, 0.0, true, 1.0);
	cvar_throwingknives_velocity 	= CreateConVar("sm_throwingknives_velocity", 		"2250", 	"Velocity (speed) adjustment.");
	cvar_throwingknives_damage 		= CreateConVar("sm_throwingknives_damage", 			"100", 		"Damage adjustment.", _, true, 0.0);
	cvar_throwingknives_hsdamage 	= CreateConVar("sm_throwingknives_hsdamage", 		"100", 		"Headshot damage adjustment.", _, true, 0.0);
	cvar_throwingknives_modelscale 	= CreateConVar("sm_throwingknives_modelscale", 		"1.0", 		"Knife size scale", _, true, 0.0);
	cvar_throwingknives_gravity 	= CreateConVar("sm_throwingknives_gravity", 		"1.0", 		"Knife gravity scale", _, true, 0.0);
	cvar_throwingknives_elasticity 	= CreateConVar("sm_throwingknives_elasticity", 		"0.2", 		"Knife elasticity", _, true, 0.0);
	cvar_throwingknives_maxlifetime = CreateConVar("sm_throwingknives_maxlifetime", 	"3.0", 		"Knife max life time", _, true, 1.0, true, 30.0);
	cvar_throwingknives_trails 		= CreateConVar("sm_throwingknives_trails", 			"1", 		"Knife leave trail effect", _, true, 0.0, true, 1.0);
	cvar_throwingknives_admins 		= CreateConVar("sm_throwingknives_admins", 			"0", 		"Admins only when enabled, who have access to admin override \"throwingknives\"", _, true, 0.0, true, 1.0);

	// Automatically generates a config file that contains our variables
	AutoExecConfig(true, "custom_ThrowingKnives");

	arrayKnivesThrown = CreateArray();

	// Hooks the events which we intend to use
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);

	// Allows the modification to be loaded while the server is running, without giving gameplay issues
	LateLoadSupport();

	// Adds files to the download list, and precaches them
	DownloadAndPrecacheFiles();
}


// This happens when a new map is loaded
public void OnMapStart()
{
	// Adds files to the download list, and precaches them
	DownloadAndPrecacheFiles();
}


// This happens after a playr has had their admin flags checked
public void OnClientPostAdminCheck(int client)
{
	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return;
	}

	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnDamageTaken);

	playerHasAccessCustom1[client] = CheckCommandAccess(client, "throwingknives", ADMFLAG_CUSTOM1);
}


// This happens when a player leaves the server
public void OnClientDisconnect(int client)
{
	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return;
	}

	// If plugin reloaded, give ammo again
	playerCarryingThrowingKnives[client] = GetConVarInt(cvar_throwingknives_count);

	// Hooks the OnTakeDamage function to check when the player takes damage
	SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnDamageTaken);
}


// This happns when a player takes damage
public Action Hook_OnDamageTaken(int client, int &attacker, int &inflictor, float &damage, int &damagetype) 
{
	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	// If the attacker does not meet our validation criteria then execute this section
	if(!IsValidClient(attacker))
	{
		return Plugin_Continue;
	}

	// IF the inflictor is not a client index
	if(inflictor < 0 && inflictor > MaxClients)
	{
		return Plugin_Continue;
	}

	// IF the inflictor is not the attacker then execute this section
	if(inflictor != attacker)
	{
		return Plugin_Continue;
	}

	// If the damage type is not slash or headshot then execute this section
	if((damagetype != 4) | (damagetype != 1073741824))
	{
		return Plugin_Continue;
	}

	attackIsAHeadshot[attacker] = false;

	if(knifeCreationTimerHandle[attacker] == INVALID_HANDLE)
	{
		return Plugin_Continue;
	}

	KillTimer(knifeCreationTimerHandle[attacker]);

	knifeCreationTimerHandle[attacker] = INVALID_HANDLE;

	attackIsAHeadshot[attacker] = false;

	return Plugin_Continue;
}



public void Hook_ThrowingKnifeCollision(int knife, int other)
{
	if(!IsValidEntity(knife))
	{
		return;
	}

	// If the entity that the throwing knife collided with is not a player index then execute this section
	if(other < 0 || other > MaxClients)
	{
		float entityPosition[3];
		float sparkDirection[3];

		GetEntPropVector(knife, Prop_Data, "m_vecOrigin", entityPosition);

		TE_SetupArmorRicochet(entityPosition, sparkDirection);

		TE_SendToAll();

		return;
	}

	if(!IsValidClient(other))
	{
		return;
	}

	int attacker = GetEntPropEnt(knife, Prop_Send, "m_hThrower");

	if(!IsValidClient(attacker))
	{
		return;
	}

	if(attacker == other)
	{
		return;
	}

	// Obtains the index of the attacker and store the value within the inflictor variable
	int inflictor = attacker;

	// If the client is alive then execute this section
	if(IsPlayerAlive(attacker))
	{
		// Obtains the attacker's knife weapon and store it within the inflictor variable
		inflictor = GetPlayerWeaponSlot(attacker, CS_SLOT_KNIFE);

		// If the entity meets the criteria of validation then execute this section
		if(!IsValidEntity(inflictor))
		{
			// Changes the inflictor to be the attacker
			inflictor = attacker;
		}
	}

	float damageForce[3];

	float damagePosition[3];

	float playerEyePosition[3];

	GetClientEyePosition(other, playerEyePosition);

	GetEntPropVector(knife, Prop_Data, "m_vecVelocity", damageForce);

	GetEntPropVector(knife, Prop_Data, "m_vecOrigin", damagePosition);
	
	if(GetVectorLength(damageForce) == 0.0)
	{
		return;
	}

	// damage values
	float damage;

	int damageType;

	// Headshot - shitty way check it, clienteyeposition almost player back...
	float distance = GetVectorDistance(damagePosition, playerEyePosition);

	// If within close range to the player's head then execute this section
	if(distance <= 20.0)
	{
		attackIsAHeadshot[attacker] = true;

		// Headshot damage type
		damageType = 1073741824;

		damage = GetConVarFloat(cvar_throwingknives_hsdamage);
	}

	// If not very close to the player's head then execute this section
	else
	{
		attackIsAHeadshot[attacker] = false;

		// Slashing damage type
		damageType = 4;

		damage = GetConVarFloat(cvar_throwingknives_damage);
	}

	// create damage
	SDKHooks_TakeDamage(other, inflictor, attacker, damage, damageType, knife, damageForce, damagePosition);

	// Temp Entity visual blood effect
	int effectColor[] = {255, 0, 0, 255};

	float effectDirection[3];

	TE_SetupBloodSprite(damagePosition, effectDirection, effectColor, 1, PrecacheDecal("sprites/blood.vmt"), PrecacheDecal("sprites/blood.vmt"));
	
	TE_SendToAll();

/* - Removed th old ragdoll effect as it may be partial reason for the crashes
	// ragdoll effect
	new ragdoll = GetEntPropEnt(other, Prop_Send, "m_hRagdoll");
	if(ragdoll != -1)
	{
		ScaleVector(damageForce, 50.0);
		damageForce[2] = FloatAbs(damageForce[2]); // push up!
		SetEntPropVector(ragdoll, Prop_Send, "m_vecForce", damageForce);
		SetEntPropVector(ragdoll, Prop_Send, "m_vecRagdollVelocity", damageForce);
	}
*/
}



////////////////
// - Events - //
////////////////


// This happens when a player spawns
public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	// Obtains the client's userid and converts it to an index and store it within our client variable
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return;
	}

	// If only administrators have access to use throwing knives, and the attacker is not an administrator then execute this section
	if(GetConVarBool(cvar_throwingknives_admins) && !playerHasAccessCustom1[client])
	{
		return;
	}

	playerCarryingThrowingKnives[client] = GetConVarInt(cvar_throwingknives_count);

	return;
}


// This happens when a player dies
public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	// Obtains the client's userid and converts it to an index and store it within our client variable
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	// Obtains the attacker's userid and converts it to an index and store it within our client variable
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	// If the attacker does not meet our validation criteria then execute this section
	if(!IsValidClient(attacker))
	{
		return Plugin_Continue;
	}
	// Creates a variable which we use to store the attacker's weapon name within
	char attackerWeapon[32];

	// Obtains the name of the weapon that was used, and store it within the attackerWeapon variable 
	GetEventString(event, "weapon", attackerWeapon, sizeof(attackerWeapon));

	// If the weapon used does not contain the string "knife" then execute this section
	if(StrContains(attackerWeapon, "knife") == -1)
	{
		return Plugin_Continue;
	}

	// If only administrators have access to use throwing knives, and the attacker is not an administrator then execute this section
	if(GetConVarBool(cvar_throwingknives_admins) && !playerHasAccessCustom1[attacker])
	{
		return Plugin_Continue;
	}

	// If the amount of throwing knives a player spawns is 0 or less then execute this section
	if(GetConVarInt(cvar_throwingknives_count) <= 0)
	{
		return Plugin_Continue;
	}

	SetEventBool(event, "headshot", attackIsAHeadshot[attacker]);

	attackIsAHeadshot[attacker] = false;

	if(!GetConVarBool(cvar_throwingknives_steal))
	{
		return Plugin_Continue;
	}

	// If the client have more than 0 knives then execute this section
	if(playerCarryingThrowingKnives[client] > 0)
	{
		playerCarryingThrowingKnives[attacker] += playerCarryingThrowingKnives[client];
	}

	// If the client is not a bot then execute this section
	if(!IsFakeClient(attacker))
	{
		// Sends a html colored hint text message to the client
		PrintHintText(attacker, "<font color='#ff8000'>Throwing Knives Left:</font><font color='#FFFFFF'>%i</font>", playerCarryingThrowingKnives[attacker]);
	}

	return Plugin_Continue;
}


// This happens when a player fires his weapon or uses the left attack
public void Event_WeaponFire(Handle event, const char[] name, bool dontBroadcast)
{
	// Obtains the client's userid and converts it to an index and store it within our client variable
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return;
	}

	// Creates a variable which we use to store the attacker's weapon name within
	char attackerWeapon[32];

	// Obtains the name of the weapon that was used, and store it within the attackerWeapon variable 
	GetEventString(event, "weapon", attackerWeapon, sizeof(attackerWeapon));

	// If the weapon used does not contain the string "knife" then execute this section
	if(StrContains(attackerWeapon, "knife") == -1)
	{
		return;
	}

	// If only administrators have access to use throwing knives, and the attacker is not an administrator then execute this section
	if(GetConVarBool(cvar_throwingknives_admins) && !playerHasAccessCustom1[client])
	{
		return;
	}

	// If the amount of throwing knives a player spawns is 0 or less then execute this section
	if(GetConVarInt(cvar_throwingknives_count) <= 0)
	{
		return;
	}

	// If the client have 0 or less knives then execute this section
	if(playerCarryingThrowingKnives[client] <= 0)
	{
		return;
	}

	knifeCreationTimerHandle[client] = CreateTimer(0.0, Timer_CreateThrowingKnife, client, TIMER_FLAG_NO_MAPCHANGE);

	return;
}



///////////////////////////
// - Regular Functions - //
///////////////////////////


public void LateLoadSupport()
{
	// Loops through all of the clients
	for (int client = 1; client <= MaxClients; client++)
	{
		// If the client does not meet our validation criteria then execute this section
		if(!IsValidClient(client))
		{
			continue;
		}

		// If plugin reloaded, give ammo again
		playerCarryingThrowingKnives[client] = GetConVarInt(cvar_throwingknives_count);

		// Hooks the OnTakeDamage function to check when the player takes damage
		SDKHook(client, SDKHook_OnTakeDamage, Hook_OnDamageTaken);


		playerHasAccessCustom1[client] = CheckCommandAccess(client, "throwingknives", ADMFLAG_CUSTOM1);
	}
}


public void SetMatchingKnifeModel(int entityThrowingKnife, int client)
{
	// Obtains the knife weapon slot and store it within the 
	int entity = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);
	
	// Creates a variable which we will use to store data within
	char modelName[PLATFORM_MAX_PATH];

	// If the entity does not meet our validation criteria then execute this section
	if(!IsValidEntity(entity))
	{
		// If the client is on the terrorist team then execute this section
		if(GetClientTeam(client) == 2)
		{
			// Changes the model's name to the default knife for the terrorist team
			modelName = "models/weapons/w_knife_default_t_dropped.mdl";
		}

		// If the client is on the counter-terrorist team then execute this section
		else if(GetClientTeam(client) == 3)
		{
			// Changes the model's name to the default knife for the counter-terrorist team
			modelName = "models/weapons/w_knife_default_ct_dropped.mdl";
		}
	}

	else
	{
		// Obtains the name of the entity's model and store it within the modelName variable
		GetEntPropString(entity, Prop_Data, "m_ModelName", modelName, sizeof(modelName));

		// If the weapon used does not contain the string "knife" then execute this section
		if(StrContains(modelName, "v_knife_") != -1)
		{
			// Replaces the path defining the view model of the knife with the path defining the world model 
			ReplaceString(modelName, sizeof(modelName), "v_knife_", "w_knife_", true);
			ReplaceString(modelName, sizeof(modelName), ".mdl", "_dropped.mdl", true);
		}

		// If there doesn't exist a file by this name within valve's file system then execute this section
		if(!FileExists(modelName, true))
		{
			// If the client is on the terrorist team then execute this section
			if(GetClientTeam(client) == 2)
			{
				// Changes the model's name to the default knife for the terrorist team
				modelName = "models/weapons/w_knife_default_t_dropped.mdl";
			}

			// If the client is on the counter-terrorist team then execute this section
			else if(GetClientTeam(client) == 3)
			{
				// Changes the model's name to the default knife for the counter-terrorist team
				modelName = "models/weapons/w_knife_default_ct_dropped.mdl";
			}
		}
	}

	// Check if the model we intend to use is already precached, if not then execute this section
	if(!IsModelPrecached(modelName))
	{
		// Precache the model we intend to use
		PrecacheModel(modelName);
	}	

	// Changes the entity's model
	SetEntityModel(entityThrowingKnife, modelName);
}


public void OnEntityDestroyed(int entity)
{
	if(!IsValidEdict(entity))
	{
		return;
	}

	int index = FindValueInArray(arrayKnivesThrown, EntIndexToEntRef(entity));

	if(index != -1)
	{
		RemoveFromArray(arrayKnivesThrown, index);
	}
}


// This happen when the plugin is loaded and when a new map starts
public void DownloadAndPrecacheFiles()
{
	// Power - Laser Gun
	AddFileToDownloadsTable("materials/sprites/laser.vtf");
	AddFileToDownloadsTable("materials/sprites/laser.vmt");

	effectBeamMaterial = PrecacheModel("materials/sprites/laser.vmt");
}



///////////////////////////////
// - Timer Based Functions - //
///////////////////////////////


public Action Timer_RemoveEntity(Handle timer, int entity)
{
	// If the entity does not meet our criteria validation then execute this section
	if(!IsValidEntity(entity))
	{
		return Plugin_Continue;
	}

	SDKUnhook(entity, SDKHook_StartTouch, Hook_ThrowingKnifeCollision);

	// Kills the entity thereby removing it from the game
	AcceptEntityInput(entity, "Kill");

	return Plugin_Continue;
}



public Action Timer_CreateThrowingKnife(Handle timer, int client)
{
	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	knifeCreationTimerHandle[client] = INVALID_HANDLE;

	// If the client is not alive then execute this section
	if(!IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	if(GetClientTeam(client) <= 1)
	{
		return Plugin_Continue;
	}

	int knife = CreateEntityByName("smokegrenade_projectile");

	// If the entity does not meet our validation criteria then execute this section
	if(!IsValidEntity(knife))
	{
		return Plugin_Continue;
	}

	DispatchSpawn(knife);

	int playerTeam = GetClientTeam(client);

	float playerOrigin[3];
	float playerVelocity[3];
	float playerEyeAngles[3];
	float entityPosition[3];
	float throwingVelocity[3];

	SetEntProp(knife, Prop_Send, "m_iTeamNum", playerTeam);
	SetEntPropEnt(knife, Prop_Send, "m_hOwnerEntity", client);
	SetEntPropEnt(knife, Prop_Send, "m_hThrower", client);

	SetEntPropFloat(knife, Prop_Send, "m_flModelScale", GetConVarFloat(cvar_throwingknives_modelscale));
	SetEntPropFloat(knife, Prop_Send, "m_flElasticity", GetConVarFloat(cvar_throwingknives_elasticity));
	SetEntPropFloat(knife, Prop_Data, "m_flGravity", GetConVarFloat(cvar_throwingknives_gravity));

	// Changes the entity's model to best possibly match the knife model the client is using
	SetMatchingKnifeModel(knife, client);

	// Changes the amount of angular velocity of the grenade to make spin when thrown
	SetEntPropVector(knife, Prop_Data, "m_vecAngVelocity", {4000.0, 0.0, 0.0});

	// Obtains and sets the required origin data of the client
	GetClientEyePosition(client, playerOrigin);
	GetClientEyeAngles(client, playerEyeAngles);
	GetAngleVectors(playerEyeAngles, entityPosition, NULL_VECTOR, NULL_VECTOR);
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", playerVelocity);
	GetAngleVectors(playerEyeAngles, throwingVelocity, NULL_VECTOR, NULL_VECTOR);

	// Calculates the information used to determine the throwing knife's throwing speed and direction
	ScaleVector(entityPosition, 50.0);
	AddVectors(entityPosition, playerOrigin, entityPosition);
	ScaleVector(throwingVelocity, GetConVarFloat(cvar_throwingknives_velocity));
	AddVectors(throwingVelocity, playerVelocity, throwingVelocity);

	// Prevents the smoke grenadee from detonating
	SetEntProp(knife, Prop_Data, "m_nNextThinkTick", -1);

	// Modifies the location, angle and velocity of the entity
	TeleportEntity(knife, entityPosition, playerEyeAngles, throwingVelocity);

	SDKHook(knife, SDKHook_StartTouch, Hook_ThrowingKnifeCollision);

	PushArrayCell(arrayKnivesThrown, EntIndexToEntRef(knife));

	playerCarryingThrowingKnives[client]--;

	// If the client is not a bot then execute this section
	if(!IsFakeClient(client))
	{
		// Sends a html colored hint text message to the client
		PrintHintText(client, "<font color='#ff8000'>Throwing Knives Left:</font><font color='#FFFFFF'>%i</font>", playerCarryingThrowingKnives[client]);
	}

	// trail effect
	if(GetConVarBool(cvar_throwingknives_trails))
	{
		if(GetClientTeam(client) == 2)
		{
			TE_SetupBeamFollow(knife, effectBeamMaterial, effectBeamMaterial, 0.45, 6.0, 1.0, 0, {220, 10, 6, 220});
			TE_SendToAll();

			TE_SetupBeamFollow(knife, effectBeamMaterial, effectBeamMaterial, 0.4, 3.5, 0.5, 0, {220, 220, 220, 145});
			TE_SendToAll();
		}

		else if(GetClientTeam(client) == 3)
		{
			TE_SetupBeamFollow(knife, effectBeamMaterial, effectBeamMaterial, 0.45, 6.0, 1.0, 0, {5, 7, 230, 220});
			TE_SendToAll();

			TE_SetupBeamFollow(knife, effectBeamMaterial, effectBeamMaterial, 0.4, 3.5, 0.5, 0, {220, 220, 220, 145});
			TE_SendToAll();
		}
	}

	// Removes the thrown knife after some seconds has passed
	CreateTimer(GetConVarFloat(cvar_throwingknives_maxlifetime), Timer_RemoveEntity, knife, TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}



////////////////////////////////
// - Return Based Functions - //
////////////////////////////////


// Returns true if the client meets the validation criteria. elsewise returns false
public bool IsValidClient(int client)
{
	if (!(1 <= client <= MaxClients) || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}

	return true;
}
