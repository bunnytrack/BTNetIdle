class BTNetIdle expands Mutator config(BTNetIdle);

struct PlayerIdleInfo {
	var int     PlayerID;
	var int     SecondsIdle;
	var int     IdleCountdownRemainder;
	var vector  LastLocation;
	var rotator LastRotation;
};

// INI variables
var config bool   bIgnoreAdmin;
var config int    MaxIdleTime;
var config int    IdleCountdown;
var config string WarningMessage;
var config string KickedMessage;

// Internal
var PlayerIdleInfo PlayerIdleInfoList[32];

function PostBeginPlay() {
	local int i;

	// Initialise IDs to -1, as 0 is a valid player ID (and also the default value of an unassigned int).
	for (i = 0; i < ArrayCount(PlayerIdleInfoList); i++) {
		PlayerIdleInfoList[i].PlayerID = -1;
	}

	// In case INI has been deleted...
	SaveConfig();

	// Begin checking idle status.
	SetTimer(1, True);
}

function Timer() {
	UpdateIdleList();
	CheckIdlePlayers();
}

function UpdateIdleList() {
	local int i;
	local Pawn P;
	local PlayerPawn Player;

	// Reset entries for players who have disconnected.
	for (i = 0; i < ArrayCount(PlayerIdleInfoList); i++) {
		if (PlayerIdleInfoList[i].PlayerID > -1) {
			if (GetPlayerById(PlayerIdleInfoList[i].PlayerID) == None) {
				PlayerIdleInfoList[i].PlayerID = -1;
			}
		}
	}

	// Iterate through each player and check if they're in the global array of player info.
	// If a player isn't in the array, add them.
	for (P = Level.PawnList; P != None; P = P.NextPawn) {
		Player = PlayerPawn(P);

		if (Player != None && !Player.PlayerReplicationInfo.bIsSpectator && !bIsInIdleList(Player)) {
			i = GetIdleListSlot();

			if (i == -1) {
				Log("");
				Log("BTNetIdle: no empty array slots for idle list");
			} else {
				PlayerIdleInfoList[i].PlayerID     = Player.PlayerReplicationInfo.PlayerID;
				PlayerIdleInfoList[i].SecondsIdle  = 0;
				PlayerIdleInfoList[i].LastLocation = Player.Location;
				PlayerIdleInfoList[i].LastRotation = Player.Rotation;
			}
		}
	}
}

function CheckIdlePlayers() {
	local bool bHasMoved;
	local int i;
	local PlayerPawn Player;

	for (i = 0; i < ArrayCount(PlayerIdleInfoList); i++) {
		if (PlayerIdleInfoList[i].PlayerID > -1) {
			Player = GetPlayerById(PlayerIdleInfoList[i].PlayerID);

			if (Player != None) {
				if (bIgnoreAdmin && Player.PlayerReplicationInfo.bAdmin) {
					continue;
				}

				// For some reason, if the Player rotation isn't cast to a vector, the comparison seems to return inconsistent values...
				bHasMoved = Player.Location != PlayerIdleInfoList[i].LastLocation || vector(Player.Rotation) != vector(PlayerIdleInfoList[i].LastRotation);

				if (bHasMoved) {
					PlayerIdleInfoList[i].SecondsIdle  = 0;
					PlayerIdleInfoList[i].LastLocation = Player.Location;
					PlayerIdleInfoList[i].LastRotation = Player.Rotation;
				}

				else {
					if (PlayerIdleInfoList[i].SecondsIdle == MaxIdleTime) {
						if (PlayerIdleInfoList[i].IdleCountdownRemainder > 0) {
							Player.ClientPlaySound(Sound'NewBeep', True);
							Player.ClientMessage(FormatMessage(WarningMessage, PlayerIdleInfoList[i].IdleCountdownRemainder));
							PlayerIdleInfoList[i].IdleCountdownRemainder--;
						} else {
							ReconnectPlayer(Player);
						}
					} else {
						PlayerIdleInfoList[i].SecondsIdle++;

						if (PlayerIdleInfoList[i].SecondsIdle == MaxIdleTime) {
							PlayerIdleInfoList[i].IdleCountdownRemainder = IdleCountdown;
						}
					}
				}
			}
		}
	}
}

// Hack: rather than dealing with replication... just issue the Nexgen command for "!spec".
// Obviously this means the entire script is useless if Nexgen isn't being used.
function ReconnectPlayer(PlayerPawn Player) {
	local Pawn P;
	local PlayerPawn PP;

	// Reconnect player...
	Player.ConsoleCommand("mutate NSC SPECTATE");

	// ...and inform other players of what's just happened.
	for (P = Level.PawnList; P != None; P = P.NextPawn) {
		PP = PlayerPawn(P);

		if (PP != None && PP.PlayerReplicationInfo.PlayerID != Player.PlayerReplicationInfo.PlayerID) {
			PP.ClientMessage(FormatMessage(KickedMessage, Player.PlayerReplicationInfo.PlayerName));
		}
	}
}

function bool bIsInIdleList(PlayerPawn Player) {
	local int i;

	for (i = 0; i < ArrayCount(PlayerIdleInfoList); i++) {
		if (PlayerIdleInfoList[i].PlayerID == Player.PlayerReplicationInfo.PlayerID) {
			return True;
		}
	}

	return False;
}

function int GetIdleListSlot() {
	local int i;

	for (i = 0; i < ArrayCount(PlayerIdleInfoList); i++) {
		if (PlayerIdleInfoList[i].PlayerID == -1) {
			return i;
		}
	}

	return -1;
}

function PlayerPawn GetPlayerById(int PlayerID) {
	local Pawn P;
	local PlayerPawn Player;

	for (P = Level.PawnList; P != None; P = P.NextPawn) {
		Player = PlayerPawn(P);

		if (Player != None && Player.PlayerReplicationInfo.PlayerID == PlayerID) {
			return Player;
		}
	}

	return None;
}

function string FormatMessage(string Message, coerce string MessageVar) {
	local int i;
	local string S;

	S = Message;

	while (InStr(S, "%s") >= 0) {
		i = InStr(S, "%s");
		S = Left(S, i) $ MessageVar $ Mid(S, i + 2);
	}

	return S;
}

DefaultProperties {
	bIgnoreAdmin=False
	MaxIdleTime=300
	IdleCountdown=5
	WarningMessage="<C00>[BTNetIdle] You will be reconnected as a spectator in %s seconds..."
	KickedMessage="[BTNetIdle] %s was automatically reconnected as a spectator."
}