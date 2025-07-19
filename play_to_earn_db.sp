#include <sourcemod>
#include <json>
#include <tf2_stocks.inc>
#include <regex.inc>
#include <SteamWorks>

public Plugin myinfo =
{
    name        = "Play To Earn",
    author      = "Gxsper",
    description = "Play to Earn for Team Fortress 2",
    version     = SOURCEMOD_VERSION,
    url         = "https://github.com/Play-To-Earn-Currency/team_fortress_2"
};

static char httpServerIp[32] = "http://localhost:8000";
static char httpFrom[12]     = "tf2";
static char onlinePlayers[MAXPLAYERS][512];
static int  onlinePlayersCount           = 0;

int         currentTimestamp             = 0;
int         timestampIncomes[15]         = { 60, 120, 180, 240, 300, 360, 420, 480, 540, 600, 660, 720, 780, 840, 900 };
const int   timestampIncomesSize         = 15;
char        timestampValue[15][20]       = { "100000000000000000", "150000000000000000", "200000000000000000",
                                "250000000000000000", "300000000000000000", "350000000000000000",
                                "400000000000000000", "450000000000000000", "500000000000000000",
                                "550000000000000000", "600000000000000000", "650000000000000000",
                                "700000000000000000", "750000000000000000", "800000000000000000" };
char        timestampValueToShow[15][10] = { "0.1", "0.15", "0.2",
                                      "0.25", "0.3", "0.35",
                                      "0.4", "0.45", "0.5",
                                      "0.55", "0.6", "0.65",
                                      "0.7", "0.75", "0.8" };

char        winnerValue[20]              = "500000000000000000";
char        loserValue[20]               = "300000000000000000";
char        winnerToShow[10]             = "0.5";
char        loserToShow[10]              = "0.3";

const int   minimumTimePlayedForIncoming = 60;
const int   minimumPlayerForSoloMVP      = 16;
const int   minimumPlayerForTwoMVP       = 8;
const int   minimumPlayerForThreeMVP     = 4;

char        soloMVPValue[20]             = "50000000000000000";
char        twoMVPValue[20]              = "30000000000000000";
char        threeMVPValue[20]            = "10000000000000000";
char        soloMVPValueShow[10]         = "0.5";
char        twoMVPValueShow[10]          = "0.3";
char        threeMVPValueShow[10]        = "0.1";
const int   minimumScoreToReceiveMVP     = 5;

Regex       regex;

public void OnPluginStart()
{
    regex = CompileRegex("^0x[a-fA-F0-9]{40}$");
    if (regex == INVALID_HANDLE)
    {
        LogError("Failed to compile wallet regex.");
    }

    CreateTimer(1.0, TimestampUpdate, _, TIMER_REPEAT);

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

    // ID command
    RegConsoleCmd("id", CommandViewSteamId, "View your steam id");

    PrintToServer("[PTE] Play to Earn plugin has been initialized");
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

        RegisterPlayer(StringToInt(networkId));
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

        if (onlinePlayersCount <= 0)
        {
            cleanupOnlinePlayers();
        }
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

    int client = GetClientOfUserId(userId);

    // Check if player is already playing
    if (oldTeam != 0)
    {
        PrintToChat(client, "[PTE] Playtime reseted because you changed the team");
    }
    // First map join
    else {
        int steamId = GetSteamAccountID(client, true);
        if (steamId != 0)
        {
            RegisterPlayer(steamId);
        }
    }

    json_cleanup_and_delete(playerObj);
}

public void OnMapEnd()
{
    PrintToServer("[PTE] Map ended");
    ClearTemporaryData();
}

public void OnServerEnterHibernation()
{
    cleanupOnlinePlayers();
    ClearTemporaryData();
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

        int  steamId = GetSteamAccountID(client);

        char url[256];
        Format(url, sizeof(url), "%s/updatewallet", httpServerIp);
        Handle requestHandle = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPUT, url);

        if (requestHandle == INVALID_HANDLE)
        {
            PrintToServer("[PTE] Error while creating the http request.");
            return Plugin_Handled;
        }

        SteamWorks_SetHTTPRequestContextValue(requestHandle, client);
        SteamWorks_SetHTTPCallbacks(requestHandle, OnCommandRegisterWalletRequest);

        JSON_Object body = new JSON_Object();
        body.SetString("walletaddress", walletAddress);
        body.SetInt("uniqueid", steamId);
        char bodyStr[256];
        body.Encode(bodyStr, sizeof(bodyStr));

        SteamWorks_SetHTTPRequestHeaderValue(requestHandle, "Content-Type", "application/json");
        SteamWorks_SetHTTPRequestHeaderValue(requestHandle, "from", httpFrom);
        SteamWorks_SetHTTPRequestRawPostBody(requestHandle, "application/json", bodyStr, strlen(bodyStr));

        SteamWorks_SendHTTPRequest(requestHandle);

        json_cleanup_and_delete(playerObj);
    }
    else {
        PrintToChat(client, "The wallet address provided is invalid, if you need help you can ask in your discord: discord.gg/vGHxVsXc4Q");
    }

    return Plugin_Handled;
}

public OnCommandRegisterWalletRequest(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1, any data2)
{
    int client = data1;

    if (eStatusCode != k_EHTTPStatusCode200OK)
    {
        PrintToChat(client, "[PTE] Cannot register your address, contact server owner on: discord.gg/vGHxVsXc4Q");
    }
    else {
        PrintToChat(client, "[PTE] Wallet changed!");
    }
}

public Action CommandViewSteamId(int client, int args)
{
    if (IsClientConnected(client) && !IsFakeClient(client))
    {
        PrintToChat(client, "[PTE] Your steam id is: %d", GetSteamAccountID(client));
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

char incrementWalletRequestBodies[MAXPLAYERS][256];
void IncrementWallet(
    int client,
    char[] valueToIncrement,
    char[] valueToShow = "0 PTE",
    char[] reason      = ", for Playing")
{
    int steamId = GetSteamAccountID(client);

    if (steamId == 0)
    {
        PrintToServer("[PTE] Invalid client when incrementing wallet");
        return;
    }

    char url[256];
    Format(url, sizeof(url), "%s/increment", httpServerIp);
    Handle requestHandle = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPUT, url);

    if (requestHandle == INVALID_HANDLE)
    {
        PrintToServer("[PTE] Error while creating the http request.");
        return;
    }

    SteamWorks_SetHTTPCallbacks(requestHandle, OnIncrementRequest);

    JSON_Object body = new JSON_Object();
    body.SetString("quantity", valueToIncrement);
    body.SetString("valueToShow", valueToShow);
    body.SetString("reason", reason);
    body.SetInt("uniqueid", steamId);
    char bodyStr[256];
    body.Encode(bodyStr, sizeof(bodyStr));

    SteamWorks_SetHTTPRequestHeaderValue(requestHandle, "Content-Type", "application/json");
    SteamWorks_SetHTTPRequestHeaderValue(requestHandle, "from", httpFrom);
    SteamWorks_SetHTTPRequestRawPostBody(requestHandle, "application/json", bodyStr, strlen(bodyStr));
    SteamWorks_SetHTTPRequestContextValue(requestHandle, client);

    IncrementWalletStartRequestWaitTimer(requestHandle, client, bodyStr);
}

void IncrementWalletStartRequestWaitTimer(Handle requestHandle, int client, const char[] bodyStr)
{
    DataPack pack = new DataPack();
    pack.WriteCell(client);
    pack.WriteCell(requestHandle);
    pack.WriteString(bodyStr);

    CreateTimer(0.5, IncrementWalletWaitForEmptyQueue, pack, TIMER_REPEAT);
}

public Action IncrementWalletWaitForEmptyQueue(Handle timer, DataPack pack)
{
    pack.Reset();

    int    client        = pack.ReadCell();
    Handle requestHandle = pack.ReadCell();
    char   bodyStr[256];
    pack.ReadString(bodyStr, sizeof(bodyStr));

    if (incrementWalletRequestBodies[client][0] == EOS)
    {
        delete pack;
        strcopy(incrementWalletRequestBodies[client], sizeof(incrementWalletRequestBodies[]), bodyStr);
        SteamWorks_SendHTTPRequest(requestHandle);
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

public OnIncrementRequest(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1, any data2)
{
    int         client                      = data1;

    JSON_Object bodySended                  = json_decode(incrementWalletRequestBodies[client]);
    incrementWalletRequestBodies[client][0] = EOS;

    if (eStatusCode != k_EHTTPStatusCode200OK)
    {
        PrintToChat(client, "[PTE] Cannot increment your wallet, contact server owner on: discord.gg/vGHxVsXc4Q");
        return;
    }

    if (bodySended == null)
    {
        PrintToChat(client, "[PTE] Cannot increment your wallet, contact server owner on: discord.gg/vGHxVsXc4Q");
        PrintToServer("[PTE] [Increment] ERROR: %d (bodySended index) have any invalid bodySended object: %s", client, incrementWalletRequestBodies[client]);
        return;
    }

    char valueToShow[32];
    bodySended.GetString("valueToShow", valueToShow, sizeof(valueToShow));
    char reason[32];
    bodySended.GetString("reason", reason, sizeof(reason));

    PrintToChat(client, "[PTE] You received: %s%s", valueToShow, reason);
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

void RegisterPlayer(const int steamId)
{
    char url[256];
    Format(url, sizeof(url), "%s/register", httpServerIp);
    Handle requestHandle = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);

    if (requestHandle == INVALID_HANDLE)
    {
        PrintToServer("[PTE] Error while creating the http request.");
        return;
    }

    SteamWorks_SetHTTPCallbacks(requestHandle, OnRegisterPlayerRequest);

    JSON_Object body = new JSON_Object();
    body.SetInt("uniqueid", steamId);
    char bodyStr[256];
    body.Encode(bodyStr, sizeof(bodyStr));

    SteamWorks_SetHTTPRequestHeaderValue(requestHandle, "Content-Type", "application/json");
    SteamWorks_SetHTTPRequestHeaderValue(requestHandle, "from", httpFrom);
    SteamWorks_SetHTTPRequestRawPostBody(requestHandle, "application/json", bodyStr, strlen(bodyStr));

    SteamWorks_SendHTTPRequest(requestHandle);
}

public OnRegisterPlayerRequest(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1, any data2)
{
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
        onlinePlayers[i][0] = EOS;
    }
    onlinePlayersCount = 0;
}
//
//
//
