#include <sourcemod>
#include <tf2_stocks.inc>
#include <play_to_earn>

public Plugin myinfo =
{
    name        = "Play To Earn",
    author      = "Gxsper",
    description = "Play to Earn for Team Fortress 2",
    version     = SOURCEMOD_VERSION,
    url         = "https://github.com/Play-To-Earn-Currency/team_fortress_2"
};

static int  playersTimestamp[MAXPLAYERS];

static int  currentTimestamp             = 0;

static int  timestampIncomesSize         = 15;
static int  timestampIncomes[15]         = { 60, 120, 180, 240, 300, 360, 420, 480, 540, 600, 660, 720, 780, 840, 900 };
static char timestampValue[15][20]       = { "100000000000000000", "150000000000000000", "200000000000000000",
                                       "250000000000000000", "300000000000000000", "350000000000000000",
                                       "400000000000000000", "450000000000000000", "500000000000000000",
                                       "550000000000000000", "600000000000000000", "650000000000000000",
                                       "700000000000000000", "750000000000000000", "800000000000000000" };
static char timestampValueToShow[15][10] = { "0.1", "0.15", "0.2",
                                             "0.25", "0.3", "0.35",
                                             "0.4", "0.45", "0.5",
                                             "0.55", "0.6", "0.65",
                                             "0.7", "0.75", "0.8" };

static char winnerValue[20]              = "500000000000000000";
static char loserValue[20]               = "300000000000000000";
static char winnerToShow[10]             = "0.5";
static char loserToShow[10]              = "0.3";

static int  minimumTimePlayedForIncoming = 60;
static int  minimumPlayerForSoloMVP      = 16;
static int  minimumPlayerForTwoMVP       = 8;
static int  minimumPlayerForThreeMVP     = 4;

static char soloMVPValue[20]             = "500000000000000000";
static char twoMVPValue[20]              = "300000000000000000";
static char threeMVPValue[20]            = "100000000000000000";
static char soloMVPValueShow[10]         = "0.5";
static char twoMVPValueShow[10]          = "0.3";
static char threeMVPValueShow[10]        = "0.1";
static int  minimumScoreToReceiveMVP     = 5;

public void OnPluginStart()
{
    // Configuration Load
    {
        char configPath[PLATFORM_MAX_PATH] = "addons/sourcemod/configs/play_to_earn.cfg";

        if (!FileExists(configPath))
        {
            Handle file = OpenFile(configPath, "w");
            if (file != null)
            {
                WriteFileLine(file, "\"PlayToEarn\"");
                WriteFileLine(file, "{");

                WriteFileLine(file, "    \"timestampIncomesSize\"       \"15\"");
                WriteFileLine(file, "");

                WriteFileLine(file, "    \"timestampIncomes\"");
                WriteFileLine(file, "    {");
                WriteFileLine(file, "        \"0\"  \"60\"");
                WriteFileLine(file, "        \"1\"  \"120\"");
                WriteFileLine(file, "        \"2\"  \"180\"");
                WriteFileLine(file, "        \"3\"  \"240\"");
                WriteFileLine(file, "        \"4\"  \"300\"");
                WriteFileLine(file, "        \"5\"  \"360\"");
                WriteFileLine(file, "        \"6\"  \"420\"");
                WriteFileLine(file, "        \"7\"  \"480\"");
                WriteFileLine(file, "        \"8\"  \"540\"");
                WriteFileLine(file, "        \"9\"  \"600\"");
                WriteFileLine(file, "        \"10\" \"660\"");
                WriteFileLine(file, "        \"11\" \"720\"");
                WriteFileLine(file, "        \"12\" \"780\"");
                WriteFileLine(file, "        \"13\" \"840\"");
                WriteFileLine(file, "        \"14\" \"900\"");
                WriteFileLine(file, "    }");
                WriteFileLine(file, "");

                WriteFileLine(file, "    \"timestampValue\"");
                WriteFileLine(file, "    {");
                WriteFileLine(file, "        \"0\"  \"100000000000000000\"");
                WriteFileLine(file, "        \"1\"  \"150000000000000000\"");
                WriteFileLine(file, "        \"2\"  \"200000000000000000\"");
                WriteFileLine(file, "        \"3\"  \"250000000000000000\"");
                WriteFileLine(file, "        \"4\"  \"300000000000000000\"");
                WriteFileLine(file, "        \"5\"  \"350000000000000000\"");
                WriteFileLine(file, "        \"6\"  \"400000000000000000\"");
                WriteFileLine(file, "        \"7\"  \"450000000000000000\"");
                WriteFileLine(file, "        \"8\"  \"500000000000000000\"");
                WriteFileLine(file, "        \"9\"  \"550000000000000000\"");
                WriteFileLine(file, "        \"10\" \"600000000000000000\"");
                WriteFileLine(file, "        \"11\" \"650000000000000000\"");
                WriteFileLine(file, "        \"12\" \"700000000000000000\"");
                WriteFileLine(file, "        \"13\" \"750000000000000000\"");
                WriteFileLine(file, "        \"14\" \"800000000000000000\"");
                WriteFileLine(file, "    }");
                WriteFileLine(file, "");

                WriteFileLine(file, "    \"timestampValueToShow\"");
                WriteFileLine(file, "    {");
                WriteFileLine(file, "        \"0\"  \"0.1\"");
                WriteFileLine(file, "        \"1\"  \"0.15\"");
                WriteFileLine(file, "        \"2\"  \"0.2\"");
                WriteFileLine(file, "        \"3\"  \"0.25\"");
                WriteFileLine(file, "        \"4\"  \"0.3\"");
                WriteFileLine(file, "        \"5\"  \"0.35\"");
                WriteFileLine(file, "        \"6\"  \"0.4\"");
                WriteFileLine(file, "        \"7\"  \"0.45\"");
                WriteFileLine(file, "        \"8\"  \"0.5\"");
                WriteFileLine(file, "        \"9\"  \"0.55\"");
                WriteFileLine(file, "        \"10\" \"0.6\"");
                WriteFileLine(file, "        \"11\" \"0.65\"");
                WriteFileLine(file, "        \"12\" \"0.7\"");
                WriteFileLine(file, "        \"13\" \"0.75\"");
                WriteFileLine(file, "        \"14\" \"0.8\"");
                WriteFileLine(file, "    }");
                WriteFileLine(file, "");

                WriteFileLine(file, "    \"winnerValue\"       \"500000000000000000\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"loserValue\"       \"300000000000000000\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"winnerToShow\"       \"0.5\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"loserToShow\"       \"0.3\"");
                WriteFileLine(file, "");

                WriteFileLine(file, "    \"minimumTimePlayedForIncoming\"       \"60\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"minimumPlayerForSoloMVP\"       \"16\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"minimumPlayerForTwoMVP\"       \"8\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"minimumPlayerForThreeMVP\"       \"4\"");
                WriteFileLine(file, "");

                WriteFileLine(file, "    \"soloMVPValue\"       \"500000000000000000\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"twoMVPValue\"       \"300000000000000000\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"threeMVPValue\"       \"100000000000000000\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"soloMVPValueShow\"       \"0.5\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"twoMVPValueShow\"       \"0.3\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"threeMVPValueShow\"       \"0.1\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"minimumScoreToReceiveMVP\"       \"5\"");                

                WriteFileLine(file, "}");
                CloseHandle(file);
                PrintToServer("[PTE] Configuration file created: %s", configPath);
            }
            else
            {
                PrintToServer("[PTE] Cannot create default file.");
                return;
            }
        }

        KeyValues kv = new KeyValues("PlayToEarn");
        if (!kv.ImportFromFile(configPath))
        {
            delete kv;
            PrintToServer("[PTE] Cannot load configuration file: %s", configPath);
        }
        // Loading from file
        else {
            timestampIncomesSize = kv.GetNum("timestampIncomesSize", 15);
            if (kv.JumpToKey("timestampIncomes"))
            {
                for (int i = 0; i < timestampIncomesSize; i++)
                {
                    char key[8];
                    Format(key, sizeof(key), "%d", i);
                    timestampIncomes[i] = kv.GetNum(key, 0);
                }
                kv.GoBack();
                PrintToServer("[PTE] timestampIncomes Loaded!");
            }
            if (kv.JumpToKey("timestampValue"))
            {
                for (int i = 0; i < timestampIncomesSize; i++)
                {
                    char key[8];
                    Format(key, sizeof(key), "%d", i);
                    char value[32];
                    kv.GetString(key, value, sizeof(value), "100000000000000000");
                    strcopy(timestampValue[i], sizeof(timestampValue[i]), value);
                }
                kv.GoBack();
                PrintToServer("[PTE] timestampValue Loaded!");
            }
            if (kv.JumpToKey("timestampValueToShow"))
            {
                for (int i = 0; i < timestampIncomesSize; i++)
                {
                    char key[8];
                    Format(key, sizeof(key), "%d", i);
                    char value[32];
                    kv.GetString(key, value, sizeof(value), "0.1");
                    strcopy(timestampValueToShow[i], sizeof(timestampValueToShow[i]), value);
                }
                kv.GoBack();
                PrintToServer("[PTE] timestampValueToShow Loaded!");
            }

            kv.GetString("winnerValue", winnerValue, sizeof(winnerValue), "500000000000000000");
            kv.GetString("loserValue", loserValue, sizeof(loserValue), "300000000000000000");
            kv.GetString("winnerToShow", winnerToShow, sizeof(winnerToShow), "0.5");
            kv.GetString("loserToShow", loserToShow, sizeof(loserToShow), "0.3");

            minimumTimePlayedForIncoming = kv.GetNum("minimumTimePlayedForIncoming", 60);
            minimumPlayerForSoloMVP      = kv.GetNum("minimumPlayerForSoloMVP", 16);
            minimumPlayerForTwoMVP       = kv.GetNum("minimumPlayerForTwoMVP", 8);
            minimumPlayerForThreeMVP     = kv.GetNum("minimumPlayerForThreeMVP", 4);

            kv.GetString("soloMVPValue", soloMVPValue, sizeof(soloMVPValue), "500000000000000000");
            kv.GetString("twoMVPValue", twoMVPValue, sizeof(twoMVPValue), "300000000000000000");
            kv.GetString("threeMVPValue", threeMVPValue, sizeof(threeMVPValue), "100000000000000000");
            kv.GetString("soloMVPValueShow", soloMVPValueShow, sizeof(soloMVPValueShow), "0.5");
            kv.GetString("twoMVPValueShow", twoMVPValueShow, sizeof(twoMVPValueShow), "0.3");
            kv.GetString("threeMVPValueShow", threeMVPValueShow, sizeof(threeMVPValueShow), "0.1");
            minimumScoreToReceiveMVP = kv.GetNum("minimumScoreToReceiveMVP", 5);
        }
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

    // Menu command
    RegConsoleCmd("menu", CommandOpenMenu, "Open PTE menu");

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

    int       onlinePlayers[MAXPLAYERS];
    GetOnlinePlayers(onlinePlayers, sizeof(onlinePlayers));
    for (int i = 0; i < MAXPLAYERS; i++)
    {
        int client = onlinePlayers[i];
        if (client == 0) break;    // End of the list

        PrintToServer("[PTE] Player online index: %d", i);
        PrintToServer("----------------------------------");

        int clientTeam = GetClientTeam(client);
        if (clientTeam != 2 && clientTeam != 3)
        {
            PrintToServer("Wrong Team");
            PrintToServer("----------------------------------");
            continue;
        }

        int  steamid                     = GetSteamAccountID(client);
        int  timePlayed                  = currentTimestamp - playersTimestamp[client];

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
        PrintToServer("Steam Id: %d", steamid);
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

        scoresToCheckIds.Push(client);

        PrintToServer("----------------------------------");
    }

    int onlinePlayersCount = GetOnlinePlayersCount();

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

        // Getting Solo MVP
        {
            for (int i = 0; i < scoresToCheckIds.Length; i++)
            {
                int client = scoresToCheckIds.Get(i);

                int score  = GetClientFrags(client);
                int team   = GetClientTeam(client);
                if (team == 2)
                {
                    if (redSoloScore < score)
                    {
                        redSoloScore = score;
                        redClient    = client;
                        redToRemove  = i;
                    }
                }
                else if (team == 3)
                {
                    if (blueSoloScore < score)
                    {
                        blueSoloScore = score;
                        blueClient    = client;
                        blueToRemove  = i;
                    }
                }
            }
        }

        // Incrementing MVPs
        {
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

        // Getting Two MVP
        {
            for (int i = 0; i < scoresToCheckIds.Length; i++)
            {
                int client = scoresToCheckIds.Get(i);

                int score  = GetClientFrags(client);
                int team   = GetClientTeam(client);
                if (team == 2)
                {
                    if (redTwoScore < score)
                    {
                        redTwoScore = score;
                        redClient   = client;
                        redToRemove = i;
                    }
                }
                else if (team == 3)
                {
                    if (blueTwoScore < score)
                    {
                        blueTwoScore = score;
                        blueClient   = client;
                        blueToRemove = i;
                    }
                }
            }
        }

        // Incrementing MVPs
        {
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

        // Getting Three MVP
        {
            for (int i = 0; i < scoresToCheckIds.Length; i++)
            {
                int client = scoresToCheckIds.Get(i);

                int score  = GetClientFrags(client);
                int team   = GetClientTeam(client);
                if (team == 2)
                {
                    if (redThreeScore < score)
                    {
                        redThreeScore = score;
                        redClient     = client;
                        redToRemove   = i;
                    }
                }
                else if (team == 3)
                {
                    if (blueThreeScore < score)
                    {
                        blueThreeScore = score;
                        blueClient     = client;
                        blueToRemove   = i;
                    }
                }
            }
        }

        // Incrementing MVPs
        {
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
    }
    PrintToServer("############################");

    PrintToServer("[PTE] Round Ended");

    for (int i = 0; i < MAXPLAYERS; i++)
    {
        playersTimestamp[i] = 0;
    }
    currentTimestamp = 0;
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
        PrintToServer("[PTE] Player Connected: Name: %s | ID: %d | Index: %d | SteamID: %s | IP: %s | Bot: %d",
                      playerName, userId, index, networkId, address, isBot);
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
        PrintToServer("[PTE] Player Disconnected: Name: %s | ID: %d | SteamID: %s | Reason: %s | Bot: %d",
                      playerName, userId, networkId, reason, isBot);
    }
}

public void OnPlayerChangeTeam(Event event, const char[] name, bool dontBroadcast)
{
    bool disconnected = event.GetBool("disconnect");
    if (disconnected) return;

    int userid  = event.GetInt("userid");
    int team    = event.GetInt("team");
    int oldTeam = event.GetInt("oldteam");

    int client  = GetClientOfUserId(userid);
    if (!IsValidClient(client))
    {
        PrintToServer("[PTE] Fake client %d, ignoring team change", userid);
        return;
    }

    PrintToServer("[PTE] %d changed their team: %d, previously: %d, timestamp: %d", client, team, oldTeam, playersTimestamp[client]);

    if (oldTeam != 0)
    {
        PrintToChat(client, "[PTE] Playtime reseted because you changed the team");
        playersTimestamp[client] = currentTimestamp;
    }
    else {
        playersTimestamp[client] = currentTimestamp;

        PrintToServer("[PTE] Player started playing %d", client);

        RegisterPlayer(client);
        ShowMenu(client);
    }
}

public void OnServerEnterHibernation()
{
    for (int i = 0; i < MAXPLAYERS; i++)
    {
        playersTimestamp[i] = 0;
    }
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    PrintToServer("[PTE] Round started");
    for (int i = 0; i < MAXPLAYERS; i++)
    {
        playersTimestamp[i] = 0;
    }
    currentTimestamp = 0;
}
//
//
//

//
// Commands
//
public Action CommandRegisterWallet(int client, int args)
{
    if (args < 1)
    {
        PrintToChat(client, "[PTE] You can set your wallet using !wallet 0x123");
        return Plugin_Handled;
    }

    char walletAddress[256];
    GetCmdArgString(walletAddress, sizeof(walletAddress));

    UpdateWallet(client, walletAddress);

    return Plugin_Handled;
}

public Action CommandViewSteamId(int client, int args)
{
    PrintToChat(client, "[PTE] Your steam id is: %d", GetSteamAccountID(client));

    return Plugin_Handled;
}

public Action CommandOpenMenu(int client, int args)
{
    ShowMenu(client);

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
//
//
//