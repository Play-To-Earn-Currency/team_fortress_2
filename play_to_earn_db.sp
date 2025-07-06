#include <sourcemod>
#include <json>
#include <tf2_stocks.inc>
#include <regex.inc>

public Plugin myinfo =
{
    name        = "Play To Earn",
    author      = "Gxsper",
    description = "Play to Earn for Team Fortress 2",
    version     = SOURCEMOD_VERSION,
    url         = "https://github.com/Play-To-Earn-Currency/team_fortress_2"
};

static Database walletsDB;

static char     onlinePlayers[MAXPLAYERS][512];
static int      onlinePlayersCount           = 0;

int             currentTimestamp             = 0;
int             timestampIncomes[15]         = { 60, 120, 180, 240, 300, 360, 420, 480, 540, 600, 660, 720, 780, 840, 900 };
const int       timestampIncomesSize         = 15;
char            timestampValue[15][20]       = { "100000000000000000", "150000000000000000", "200000000000000000",
                                "250000000000000000", "300000000000000000", "350000000000000000",
                                "400000000000000000", "450000000000000000", "500000000000000000",
                                "550000000000000000", "600000000000000000", "650000000000000000",
                                "700000000000000000", "750000000000000000", "800000000000000000" };
char            timestampValueToShow[15][10] = { "0.1", "0.15", "0.2",
                                      "0.25", "0.3", "0.35",
                                      "0.4", "0.45", "0.5",
                                      "0.55", "0.6", "0.65",
                                      "0.7", "0.75", "0.8" };

char            winnerValue[20]              = "500000000000000000";
char            loserValue[20]               = "300000000000000000";
char            winnerToShow[10]             = "0.5";
char            loserToShow[10]              = "0.3";

bool            alertPlayerIncomings         = true;

const int       minimumTimePlayedForIncoming = 60;
const int       minimumPlayerForSoloMVP      = 16;
const int       minimumPlayerForTwoMVP       = 8;
const int       minimumPlayerForThreeMVP     = 4;

char            soloMVPValue[20]             = "50000000000000000";
char            twoMVPValue[20]              = "30000000000000000";
char            threeMVPValue[20]            = "10000000000000000";
char            soloMVPValueShow[10]         = "0.5";
char            twoMVPValueShow[10]          = "0.3";
char            threeMVPValueShow[10]        = "0.1";
const int       minimumScoreToReceiveMVP     = 5;

Regex           regex;

DBStatement     statement_GetWalletRegistered;
DBStatement     statement_GetPlayerRegistered;
DBStatement     statement_RegisterPlayer;
DBStatement     statement_IncrementWallet;
DBStatement     statement_RegisterWallet_Exists;
DBStatement     statement_RegisterWallet;
char            dbStatementError[524];

public void OnPluginStart()
{
    regex = CompileRegex("^[a-zA-Z0-9]{42}$");

    PrintToServer("[PTE] Play to Earn plugin has been initialized");
    CreateTimer(1.0, TimestampUpdate, _, TIMER_REPEAT);

    char walletDBError[32];
    walletsDB = SQL_Connect("default", true, walletDBError, sizeof(walletDBError));
    if (walletsDB == null)
    {
        PrintToServer("[PTE] ERROR Connecting to the database: %s", walletDBError);
        PrintToServer("[PTE] The plugin will stop now...");
        return;
    }

    statement_GetWalletRegistered   = SQL_PrepareQuery(walletsDB, "SELECT walletaddress FROM tf2 WHERE uniqueid = ?;", dbStatementError, sizeof(dbStatementError));
    statement_GetPlayerRegistered   = SQL_PrepareQuery(walletsDB, "SELECT COUNT(*) FROM tf2 WHERE uniqueid = ?;", dbStatementError, sizeof(dbStatementError));
    statement_RegisterPlayer        = SQL_PrepareQuery(walletsDB, "INSERT INTO tf2 (uniqueid) VALUES (?);", dbStatementError, sizeof(dbStatementError));
    statement_IncrementWallet       = SQL_PrepareQuery(walletsDB, "UPDATE tf2 SET value = value + ? WHERE uniqueid = ?;", dbStatementError, sizeof(dbStatementError));
    statement_RegisterWallet_Exists = SQL_PrepareQuery(walletsDB, "UPDATE tf2 SET walletaddress = ? WHERE uniqueid = ?;", dbStatementError, sizeof(dbStatementError));
    statement_RegisterWallet        = SQL_PrepareQuery(walletsDB, "INSERT INTO tf2 (uniqueid, walletaddress) VALUES (?, ?);", dbStatementError, sizeof(dbStatementError));

    // Match Finish Event
    HookEvent("teamplay_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);

    // Player connected
    HookEvent("player_connect", OnPlayerConnect, EventHookMode_Post);

    // Player disconnected
    HookEventEx("player_disconnect", OnPlayerDisconnect, EventHookMode_Post);

    // Wallet command
    RegConsoleCmd("wallet", CommandRegisterWallet, "Set up your Wallet address");

    // Player team changed
    HookEventEx("player_team", OnPlayerChangeTeam, EventHookMode_Post);

    // Round started
    HookEventEx("teamplay_round_start", OnRoundStart, EventHookMode_Post);
}

//
// EVENTS
//
public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    // 3 == blue
    // 2 == red
    int winningTeam = event.GetInt("winning_team");

    PrintToServer("[PTE] Calculating player incomings... the winner is: %d", winningTeam);

    // Stores players ids that will be checked
    ArrayList scoresToCheckIds = new ArrayList();

    int       length           = onlinePlayersCount;
    for (int i = 0; i < length; i += 1)
    {
        PrintToServer("[PTE] Player online index: %d", i);
        PrintToServer("----------------------------------");
        JSON_Object playerObj = json_decode(onlinePlayers[i]);
        if (playerObj == null)
        {
            PrintToServer("[PTE] [OnRoundEnd] ERROR: %d (online index) have any invalid player object: %s", i, onlinePlayers[i]);
            continue;
        }

        int client = GetClientOfUserId(playerObj.GetInt("userId"));
        if (!IsClientInGame(client) || IsFakeClient(client))
        {
            continue;
        }
        int clientTeam = GetClientTeam(client);

        playerObj.SetInt("score", GetClientFrags(client));

        if (clientTeam != 2 && clientTeam != 3)
        {
            PrintToServer("Wrong Team");
            PrintToServer("----------------------------------");
            continue;
        }
        char playerNetwork[32];
        playerObj.GetString("networkId", playerNetwork, sizeof(playerNetwork));

        int  steamId                     = GetSteamAccountID(client);

        // Getting PTE earned by playtime
        int  timePlayed                  = currentTimestamp - playerObj.GetInt("teamTimestamp", 0);
        int  timestampIndex              = -1;
        char timestampCurrentEarning[20] = "0";
        for (int j = 0; j < timestampIncomesSize; j++)
        {
            if (timePlayed >= timestampIncomes[j])
            {
                timestampIndex = j;
            }
            else {
                break;
            }
        }
        if (timestampIndex > -1)
        {
            timestampCurrentEarning = timestampValue[timestampIndex];
        }

        if (timePlayed < minimumTimePlayedForIncoming)
        {
            PrintToServer("Not enough playtime: %d", timePlayed);
            PrintToServer("----------------------------------");
            continue;
        }

        PrintToServer("Client: %d", client);
        PrintToServer("Steam Id: %d", steamId);
        PrintToServer("Team: %d", clientTeam);
        PrintToServer("Winner: %d", winningTeam == clientTeam);
        PrintToServer("TimePlayed: %d", timePlayed);

        if (winningTeam == clientTeam)
        {
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", winnerToShow);
            IncrementWallet(client, winnerValue, outputText, ", for Winning");
        }
        else {
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", loserToShow);
            IncrementWallet(client, loserValue, outputText, ", for Losing");
        }

        if (!StrEqual(timestampCurrentEarning, "0"))
        {
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", timestampValueToShow[timestampIndex]);
            IncrementWallet(client, timestampValue[timestampIndex], outputText, ", for Playing");
        }

        playerObj.SetInt("teamTimestamp", currentTimestamp);

        updateOnlinePlayerByUserId(playerObj.GetInt("userId"), playerObj);
        json_cleanup_and_delete(playerObj);

        scoresToCheckIds.Push(steamId);

        PrintToServer("----------------------------------");
    }

    PrintToServer("[PTE] Calculating player MVP");
    PrintToServer("############################");
    if (onlinePlayersCount >= minimumPlayerForSoloMVP)
    {
        PrintToServer("Solo MVP");
        int redSoloScore  = -1;
        int redToRemove   = -1;
        int redClient     = -1;

        int blueSoloScore = -1;
        int blueToRemove  = -1;
        int blueClient    = -1;

        for (int i = 0; i < scoresToCheckIds.Length; i++)
        {
            int         playerId  = scoresToCheckIds.Get(i);

            JSON_Object playerObj = getPlayerByUserId(playerId);
            if (playerObj == null)
            {
                PrintToServer("[PTE] [MVP] ERROR: %d have any invalid player object", playerId);
                continue;
            }

            int score = playerObj.GetInt("score");
            int team  = playerObj.GetInt("team");
            if (team == 2)
            {
                if (redSoloScore < score)
                {
                    redSoloScore = score;
                    redClient    = GetClientOfUserId(playerObj.GetInt("userId"));
                    redToRemove  = i;
                }
            }
            else if (team == 3)
            {
                if (blueSoloScore < score)
                {
                    blueSoloScore = score;
                    blueClient    = GetClientOfUserId(playerObj.GetInt("userId"));
                    blueToRemove  = i;
                }
            }
        }

        if (redSoloScore >= minimumScoreToReceiveMVP)
        {
            scoresToCheckIds.Erase(redToRemove);
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", soloMVPValueShow);
            IncrementWallet(redClient, soloMVPValue, outputText, ", by Performance");
        }
        if (blueSoloScore >= minimumScoreToReceiveMVP)
        {
            scoresToCheckIds.Erase(blueToRemove);
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", soloMVPValueShow);
            IncrementWallet(blueClient, soloMVPValue, outputText, ", by Performance");
        }
    }
    if (onlinePlayersCount >= minimumPlayerForTwoMVP)
    {
        PrintToServer("Two MVP");
        int redTwoScore  = -1;
        int redToRemove  = -1;
        int redClient    = -1;

        int blueTwoScore = -1;
        int blueToRemove = -1;
        int blueClient   = -1;

        for (int i = 0; i < scoresToCheckIds.Length; i++)
        {
            int         playerId  = scoresToCheckIds.Get(i);

            JSON_Object playerObj = getPlayerByUserId(playerId);
            if (playerObj == null)
            {
                PrintToServer("[PTE] [MVP] ERROR: %d have any invalid player object", playerId);
                continue;
            }

            int score = playerObj.GetInt("score");
            int team  = playerObj.GetInt("team");
            if (team == 2)
            {
                if (redTwoScore < score)
                {
                    redTwoScore = score;
                    redClient   = GetClientOfUserId(playerObj.GetInt("userId"));
                    redToRemove = i;
                }
            }
            else if (team == 3)
            {
                if (blueTwoScore < score)
                {
                    blueTwoScore = score;
                    blueClient   = GetClientOfUserId(playerObj.GetInt("userId"));
                    blueToRemove = i;
                }
            }
        }

        if (redTwoScore >= minimumScoreToReceiveMVP)
        {
            scoresToCheckIds.Erase(redToRemove);
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", twoMVPValueShow);
            IncrementWallet(redClient, twoMVPValue, outputText, ", by Performance");
        }
        if (blueTwoScore >= minimumScoreToReceiveMVP)
        {
            scoresToCheckIds.Erase(blueToRemove);
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", twoMVPValueShow);
            IncrementWallet(blueClient, twoMVPValue, outputText, ", by Performance");
        }
    }
    if (onlinePlayersCount >= minimumPlayerForThreeMVP)
    {
        PrintToServer("Three MVP");
        int redThreeScore  = -1;
        int redToRemove    = -1;
        int redClient      = -1;

        int blueThreeScore = -1;
        int blueToRemove   = -1;
        int blueClient     = -1;

        for (int i = 0; i < scoresToCheckIds.Length; i++)
        {
            int         playerId  = scoresToCheckIds.Get(i);

            JSON_Object playerObj = getPlayerByUserId(playerId);
            if (playerObj == null)
            {
                PrintToServer("[PTE] [MVP] ERROR: %d have any invalid player object", playerId);
                continue;
            }

            int score = playerObj.GetInt("score");
            int team  = playerObj.GetInt("team");
            if (team == 2)
            {
                if (redThreeScore < score)
                {
                    redThreeScore = score;
                    redClient     = GetClientOfUserId(playerObj.GetInt("userId"));
                    redToRemove   = i;
                }
            }
            else if (team == 3)
            {
                if (blueThreeScore < score)
                {
                    blueThreeScore = score;
                    blueClient     = GetClientOfUserId(playerObj.GetInt("userId"));
                    blueToRemove   = i;
                }
            }
        }

        if (redThreeScore >= minimumScoreToReceiveMVP)
        {
            scoresToCheckIds.Erase(redToRemove);
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", threeMVPValueShow);
            IncrementWallet(redClient, threeMVPValue, outputText, ", by Performance");
        }
        if (blueThreeScore >= minimumScoreToReceiveMVP)
        {
            scoresToCheckIds.Erase(blueToRemove);
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", threeMVPValueShow);
            IncrementWallet(blueClient, threeMVPValue, outputText, ", by Performance");
        }
    }
    PrintToServer("############################");

    PrintToServer("[PTE] Round Ended");
    ClearTemporaryData();
}

public void OnPlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
    char playerName[32];
    char networkId[32];
    char address[32];
    int  index  = event.GetInt("index");
    int  userId = event.GetInt("userid");
    bool isBot  = event.GetBool("bot");

    event.GetString("name", playerName, sizeof(playerName));
    event.GetString("networkid", networkId, sizeof(networkId));
    event.GetString("address", address, sizeof(address));

    if (!isBot)
    {
        JSON_Object playerObj = new JSON_Object();
        playerObj.SetString("playerName", playerName);
        playerObj.SetString("networkId", networkId);
        playerObj.SetString("address", address);
        playerObj.SetInt("userId", userId);
        playerObj.SetInt("index", index);
        playerObj.SetInt("walletStatus", -1);

        char userData[256];
        playerObj.Encode(userData, sizeof(userData));
        json_cleanup_and_delete(playerObj);

        onlinePlayers[onlinePlayersCount] = userData;
        onlinePlayersCount++;

        PrintToServer("[PTE] Player Connected: Name: %s | ID: %d | Index: %d | SteamID: %s | IP: %s | Bot: %d",
                      playerName, userId, index, networkId, address, isBot);

        PrintToServer("[PTE] Online Players: %d", onlinePlayersCount);
    }
}

public void OnPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    char playerName[64];
    char networkId[32];
    char reason[128];
    int  userId = event.GetInt("userid");
    bool isBot  = event.GetBool("bot");

    event.GetString("name", playerName, sizeof(playerName));
    event.GetString("networkid", networkId, sizeof(networkId));
    event.GetString("reason", reason, sizeof(reason));

    if (!isBot)
    {
        removePlayerByUserId(userId);
        onlinePlayersCount--;
        PrintToServer("[PTE] Player Disconnected: Name: %s | ID: %d | SteamID: %s | Reason: %s | Bot: %d",
                      playerName, userId, networkId, reason, isBot);

        PrintToServer("[PTE] Online Players: %d", onlinePlayersCount);
    }
}

public void OnPlayerChangeTeam(Event event, const char[] name, bool dontBroadcast)
{
    bool disconnected = event.GetBool("disconnect");
    if (disconnected) return;

    int         userId    = event.GetInt("userid");
    int         team      = event.GetInt("team");
    int         oldTeam   = event.GetInt("oldteam");

    JSON_Object playerObj = getPlayerByUserId(userId);
    if (playerObj == null)
    {
        PrintToServer("[PTE] [OnPlayerChangeTeam] Warning: %d have any invalid player object, a bot?", userId);
        return;
    }

    char playerName[32];
    playerObj.GetString("playerName", playerName, sizeof(playerName));

    PrintToServer("[PTE] %s changed their team: %d, previously: %d, timestamp: %d", playerName, team, oldTeam, playerObj.GetInt("teamTimestamp", 0));

    playerObj.SetInt("team", team);
    playerObj.SetInt("teamTimestamp", currentTimestamp);

    int client  = GetClientOfUserId(userId);
    int steamId = GetSteamAccountID(client);

    // Check if player is already playing
    if (oldTeam == 0)
    {
        if (!PlayerRegistered(steamId))
        {
            RegisterPlayer(steamId);
        }
    }
    else {
        PrintToChat(client, "[PTE] Playtime reseted because you changed the team");
    }

    // Check wallet status
    if (playerObj.GetInt("walletStatus") == -1)
    {
        if (WalletRegistered(steamId))
        {
            playerObj.SetInt("walletStatus", 1);
            updateOnlinePlayerByUserId(userId, playerObj);
        }
        else {
            playerObj.SetInt("walletStatus", 0);
            updateOnlinePlayerByUserId(userId, playerObj);
        }
    }

    json_cleanup_and_delete(playerObj);
}

public void OnMapEnd()
{
    PrintToServer("[PTE] Map ended");
    ClearTemporaryData();

    if (walletsDB != null)
    {
        walletsDB.Close();
        walletsDB = null;

        PrintToServer("[PTE] Map ended, database closed");
    }
}

public void OnMapStart()
{
    if (walletsDB == null)
    {
        char walletDBError[32];
        walletsDB = SQL_Connect("default", true, walletDBError, sizeof(walletDBError));
        if (walletDBError[0] != '\0')
        {
            PrintToServer("[PTE] ERROR Connecting to the database: %s", walletDBError);
            return;
        }
        else {
            PrintToServer("[PTE] Map started, database re-connection successfully");
        }
    }
}

public void OnServerEnterHibernation()
{
    cleanupOnlinePlayers();
    if (walletsDB != null)
    {
        walletsDB.Close();
        walletsDB = null;
        PrintToServer("[PTE] Server hibernating, database closed");
    }
}

public void OnServerExitHibernation()
{
    if (walletsDB == null)
    {
        char walletDBError[256];
        walletsDB = SQL_Connect("default", true, walletDBError, sizeof(walletDBError));

        if (walletDBError[0] != '\0')
        {
            PrintToServer("[PTE] ERROR Connecting to the database: %s", walletDBError);
            return;
        }
        else {
            PrintToServer("[PTE] Exited from hibernation, database re-connection successfully");
        }
    }
    else {
        PrintToServer("[PTE] ???? Server exit from hibernation but the database is not null");
    }
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    PrintToServer("[PTE] Round started");
    ClearTemporaryData();
}
//
//
//

//
// Commands
//
public Action CommandRegisterWallet(int client, int args)
{
    Format(dbStatementError, sizeof(dbStatementError), "");

    if (!IsClientConnected(client) || IsFakeClient(client))
    {
        return Plugin_Handled;
    }

    if (args < 1)
    {
        PrintToChat(client, "You can set your wallet in your discord: discord.gg/vGHxVsXc4Q");
        PrintToChat(client, "Or you can setup using !wallet 0x123...");
        return Plugin_Handled;
    }
    char walletAddress[256];
    GetCmdArgString(walletAddress, sizeof(walletAddress));

    if (ValidAddress(walletAddress))
    {
        JSON_Object playerObj = getPlayerByUserId(GetClientUserId(client));
        if (playerObj == null)
        {
            PrintToServer("[PTE] [CommandRegisterWallet] ERROR: %d have any invalid player object", client);
            return Plugin_Handled;
        }

        int steamId = GetSteamAccountID(client);

        if (PlayerRegistered(steamId))
        {
            SQL_BindParamString(statement_RegisterWallet_Exists, 0, walletAddress, false);
            SQL_BindParamInt(statement_RegisterWallet_Exists, 1, steamId);

            if (!SQL_Execute(statement_RegisterWallet_Exists))
            {
                PrintToServer("[PTE] Update %d wallet to: %s", steamId, walletAddress);
                PrintToServer(dbStatementError);
            }
            else {
                if (SQL_GetAffectedRows(statement_RegisterWallet_Exists) == 0)
                {
                    PrintToServer("[PTE] ERROR No rows affected while updating player %d wallet", steamId);
                }
            }
        }
        else {
            SQL_BindParamString(statement_RegisterWallet, 0, walletAddress, false);
            SQL_BindParamInt(statement_RegisterWallet, 1, steamId);

            if (!SQL_Execute(statement_RegisterWallet))
            {
                PrintToServer("[PTE] Update %d wallet to: %s", steamId, walletAddress);
                PrintToServer(dbStatementError);

                PrintToChat(client, "Cannot update your wallet, please contact server administrator!");
            }
            else {
                if (SQL_GetAffectedRows(statement_RegisterWallet) == 0)
                {
                    PrintToServer("[PTE] ERROR No rows affected while adding player %d wallet", steamId);

                    PrintToChat(client, "Cannot update your wallet, please contact server administrator!");
                }
                else {
                    PrintToServer("[PTE] Updated %d wallet to: %s", steamId, walletAddress);

                    PrintToChat(client, "Wallet updated!");
                }
            }
        }

        json_cleanup_and_delete(playerObj);
    }
    else {
        PrintToChat(client, "The wallet address provided is invalid, if you need help you can ask in your discord: discord.gg/vGHxVsXc4Q");
    }

    return Plugin_Handled;
}

//
//
//

//
// Utils
//
public Action TimestampUpdate(Handle timer)
{
    currentTimestamp++;
    return Plugin_Continue;
}

void IncrementWallet(
    int client,
    char[] valueToIncrement,
    char[] valueToShow = "0 PTE",
    char[] reason      = ", for Playing")
{
    Format(dbStatementError, sizeof(dbStatementError), "");

    int steamId = GetSteamAccountID(client);

    SQL_BindParamString(statement_IncrementWallet, 0, valueToIncrement, false);
    SQL_BindParamInt(statement_IncrementWallet, 1, steamId);

    if (!SQL_Execute(statement_IncrementWallet))
    {
        PrintToServer("[PTE] Cannot increment %d values", steamId);
        PrintToServer(dbStatementError);
    }
    else {
        if (SQL_GetAffectedRows(statement_IncrementWallet) > 0)
        {
            if (alertPlayerIncomings)
            {
                PrintToChat(client, "[PTE] You received: %s%s", valueToShow, reason);
            }
            PrintToServer("[PTE] Incremented %d value: %s, reason: '%s'", steamId, valueToIncrement, reason);
        }
        else {
            PrintToServer("[PTE] ERROR No rows affected while incrementing player %d", steamId);
        }
    }
}

void ClearTemporaryData()
{
    PrintToServer("[PTE] Clear Data was called, resetting player values...");
    currentTimestamp = 0;

    int length       = onlinePlayersCount;
    for (int i = 0; i < length; i += 1)
    {
        JSON_Object playerObj = json_decode(onlinePlayers[i]);
        if (playerObj == null)
        {
            PrintToServer("[PTE] [ClearTemporaryData] ERROR: %d (online index) have any invalid player object: %s", i, onlinePlayers[i]);
            continue;
        }
        playerObj.SetInt("teamTimestamp", currentTimestamp);
        playerObj.SetInt("score", 0);

        updateOnlinePlayerByUserId(playerObj.GetInt("userId"), playerObj);
        json_cleanup_and_delete(playerObj);
    }
}

bool ValidAddress(const char[] address)
{
    return regex.Match(address) > 0;
}

stock bool WalletRegistered(const int steamId)
{
    Format(dbStatementError, sizeof(dbStatementError), "");
    SQL_BindParamInt(statement_GetWalletRegistered, 0, steamId);

    if (!SQL_Execute(statement_GetWalletRegistered))
    {
        char error[128];
        SQL_GetError(walletsDB, error, sizeof(error));
        PrintToServer("[PTE] [WalletRegistered] Error checking if %d exists: %s", steamId, error);
        return false;
    }
    else {
        while (SQL_FetchRow(statement_GetWalletRegistered))
        {
            char walletAddress[68];
            if (!SQL_IsFieldNull(statement_GetWalletRegistered, 0))
            {
                SQL_FetchString(statement_GetWalletRegistered, 0, walletAddress, sizeof(walletAddress));
            }
            if (strlen(walletAddress) > 0)
            {
                return true;
            }
            else {
                return false;
            }
        }
        return false;
    }
}

bool PlayerRegistered(const int steamId)
{
    Format(dbStatementError, sizeof(dbStatementError), "");
    SQL_BindParamInt(statement_GetPlayerRegistered, 0, steamId);

    if (!SQL_Execute(statement_GetPlayerRegistered))
    {
        char error[128];
        SQL_GetError(walletsDB, error, sizeof(error));
        PrintToServer("[PTE] [PlayerRegistered] Error checking if %d exists: %s", steamId, error);
        return false;
    }
    else {
        while (SQL_FetchRow(statement_GetPlayerRegistered))
        {
            int rows = SQL_FetchInt(statement_GetPlayerRegistered, 0);
            if (rows == 0)
            {
                return false;
            }
            else if (rows > 1) {
                PrintToServer("[PTE] ERROR: uniqueid \"%d\" is on multiples rows, your database is incorrectly configured, please check it. from: %d, rows: %d", steamId, rows);
                return false;
            }
            else {
                return true;
            }
        }
        return false;
    }
}

bool RegisterPlayer(const int steamId)
{
    Format(dbStatementError, sizeof(dbStatementError), "");
    SQL_BindParamInt(statement_RegisterPlayer, 0, steamId);

    if (!SQL_Execute(statement_RegisterPlayer))
    {
        char error[128];
        SQL_GetError(walletsDB, error, sizeof(error));
        PrintToServer("[PTE] Error checking if %d exists: %s", steamId, error);
        return false;
    }
    else {
        int affectedRows = SQL_GetAffectedRows(statement_RegisterPlayer);
        if (affectedRows == 0)
        {
            PrintToServer("[PTE] ERROR: No rows affected when registering for player: %d", steamId);
            return false;
        }
        else if (affectedRows > 1) {
            PrintToServer("[PTE] ERROR: MULTIPLES ROWS AFFECTED WHILE INSERTING PLAYERS: %d, rows: %d", steamId, affectedRows);
            return false;
        }
        else {
            return true;
        }
    }
}

JSON_Object getPlayerByUserId(int userId)
{
    for (int i = 0; i < onlinePlayersCount; i++)
    {
        if (strlen(onlinePlayers[i]) > 0)
        {
            JSON_Object playerObj = json_decode(onlinePlayers[i]);
            if (playerObj == null)
            {
                PrintToServer("[PTE] [getPlayerByUserId] ERROR: %d (online index) have any invalid player object: %s", i, onlinePlayers[i]);
                continue;
            }

            if (playerObj.GetInt("userId") == userId)
            {
                return playerObj;
            }
        }
    }
    return null;
}

void removePlayerByUserId(int userId)
{
    // Getting player index to remove
    int playerIndex = -1;
    for (int i = 0; i < onlinePlayersCount; i++)
    {
        if (strlen(onlinePlayers[i]) > 0)
        {
            JSON_Object playerObj = json_decode(onlinePlayers[i]);
            if (playerObj == null)
            {
                PrintToServer("[PTE] [removePlayerByUserId] ERROR: %d (online index) have any invalid player object: %s", i, onlinePlayers[i]);
                continue;
            }

            if (playerObj.GetInt("userId") == userId)
            {
                playerIndex = i;
                break;
            }
        }
    }
    if (playerIndex == -1)
    {
        PrintToServer("[PTE] [removePlayerByUserId] ERROR: %d player index no longer exists", userId);
        return;
    }

    // Moving values to back
    for (int i = playerIndex; i < onlinePlayersCount - 1; i++)
    {
        strcopy(onlinePlayers[i], onlinePlayersCount, onlinePlayers[i + 1]);
    }

    // Cleaning last element
    onlinePlayers[onlinePlayersCount - 1][0] = '\0';
}

stock JSON_Object getPlayerByClient(int client)
{
    for (int i = 0; i < onlinePlayersCount; i++)
    {
        if (strlen(onlinePlayers[i]) > 0)
        {
            JSON_Object playerObj = json_decode(onlinePlayers[i]);
            if (playerObj == null)
            {
                PrintToServer("[PTE] [getPlayerByClient] ERROR: %d (online index) have any invalid player object: %s", i, onlinePlayers[i]);
                continue;
            }

            if (playerObj.GetInt("index") == client)
            {
                return playerObj;
            }
        }
    }
    return null;
}

void updateOnlinePlayerByUserId(int userId, JSON_Object updatedPlayerObj)
{
    for (int i = 0; i < onlinePlayersCount; i++)
    {
        if (strlen(onlinePlayers[i]) > 0)
        {
            JSON_Object playerObj = json_decode(onlinePlayers[i]);
            if (playerObj == null)
            {
                PrintToServer("[PTE] [updateOnlinePlayerByUserId] ERROR: %d (online index) have any invalid player object: %s", i, onlinePlayers[i]);
                continue;
            }

            if (playerObj.GetInt("userId") == userId)
            {
                char encodedPlayer[256];
                updatedPlayerObj.Encode(encodedPlayer, sizeof(encodedPlayer));
                onlinePlayers[i] = encodedPlayer;
            }
        }
    }
}

void cleanupOnlinePlayers()
{
    for (int i = 0; i < MAXPLAYERS; i++)
    {
        strcopy(onlinePlayers[i], 256, "");
    }
    onlinePlayersCount = 0;
}
//
//
//
