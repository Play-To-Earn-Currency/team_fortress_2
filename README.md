# Team Fortress 2 Play To Earn
Base template for running a server with play to earn support

## Functionality
- When the round ends the winning side will earn 0.5 PTE, the losing side will earn 0.3 PTE
- When the round ends player will earn PTE based on time play, maximum 0.8 at 15 minutes
- Players will only receive if at least played during 1 minute of playtime
- MVP players will receive 0.5 PTE coins
- SVP players will receive 0.3 PTE coins
- TVP players will receive 0.1 PTE coins
- Setup wallet as command ``!wallet 0x123...``

## Configuring
To configure you will need to manually change some values inside the file before compiling

``Database Version``
```cpp
int         currentTimestamp             = 0;
int         timestampIncomes[15]         = { 60, 120, 180, 240, 300, 360, 420, 480, 540, 600, 660, 720, 780, 840, 900 };
const int   timestampIncomesSize         = 15;
char        timestampValue[15][20]       = { "100000000000000000", "200000000000000000", "300000000000000000",
                                "400000000000000000", "500000000000000000", "600000000000000000",
                                "700000000000000000", "800000000000000000", "900000000000000000",
                                "1000000000000000000", "1100000000000000000", "1200000000000000000",
                                "1300000000000000000", "1400000000000000000", "1500000000000000000" };
char        timestampValueToShow[15][10] = { "0.1", "0.15", "0.2",
                                      "0.25", "0.3", "0.35",
                                      "0.4", "0.45", "0.5",
                                      "0.55", "0.6", "0.65",
                                      "0.7", "0.75", "0.8" };

char        winnerValue[20]              = "500000000000000000";
char        loserValue[20]               = "300000000000000000";
char        winnerToShow[10]             = "0.5";
char        loserToShow[10]              = "0.3";

bool        alertPlayerIncomings         = true;

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
```

## Using Database
- Download Team Fortress 2 server files
- Install [sourcemod](https://www.sourcemod.net/downloads.php) and [metamod](https://www.sourcemm.net/downloads.php/?branch=stable)
- Install [sm_json](https://github.com/clugg/sm-json) for [sourcemod](https://www.sourcemod.net/downloads.php), just place the addons folder inside TeamFortress2/tf
- Install a database like mysql or mariadb
- Create a user for the database: GRANT ALL PRIVILEGES ON pte_wallets.* TO 'pte_admin'@'localhost' IDENTIFIED BY 'supersecretpassword' WITH GRANT OPTION; FLUSH PRIVILEGES;
- Create a table named ``tf2``:
```sql
CREATE TABLE tf2 (
    uniqueid VARCHAR(255) NOT NULL PRIMARY KEY,
    walletaddress VARCHAR(255) DEFAULT null,
    value DECIMAL(50, 0) NOT NULL DEFAULT 0
);
```
- Copy the play_to_earn_db.sp inside TeamFortress2/tf/addons/sourcemod/scripting
- Inside the TeamFortress2/tf/addons/sourcemod/scripting should be a file to compile, compile it giving the play_to_earn_db.sp as parameter
- The file should be in TeamFortress2/tf/addons/sourcemod/scripting/compiled folder, copy the file compiled and place it in TeamFortress2/tf/addons/sourcemod/plugins folder
- Now you need to configure your database, go to TeamFortress2/tf/addons/sourcemod/databases.cfg, and add the database credentials
- Run the server normally