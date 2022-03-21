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
							Player.ClientMessage(FormatWarningMessage(PlayerIdleInfoList[i].IdleCountdownRemainder));
							PlayerIdleInfoList[i].IdleCountdownRemainder--;
						} else {
							// Hack: rather than dealing with replication... just issue the Nexgen command for "!spec".
							// Obviously this means the entire script is useless if Nexgen isn't being used.
							Player.ConsoleCommand("mutate NSC SPECTATE");
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

function string FormatWarningMessage(int Seconds) {
	local int i;
	local string S;

	S = WarningMessage;

	while (InStr(S, "%i") >= 0) {
		i = InStr(S, "%i");
		S = Left(S, i) $ Seconds $ Mid(S, i + 2);
	}

	return S;
}

DefaultProperties {
	bIgnoreAdmin=False
	MaxIdleTime=300
	IdleCountdown=5
	WarningMessage="<C00>[BTNetIdle] You will be reconnected as a spectator in %i seconds..."
}