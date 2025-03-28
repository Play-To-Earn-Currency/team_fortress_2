# Team Fortress 2 Play To Earn
Base template for running a server with play to earn support

## Functionality
- When the round ends the winning side and losing sides will earn rewards
- When the round ends player will earn PTE based on time play
- Players will only receive if at least played during 1 minute of playtime
- MVP reward system
- Setup wallet as command ``!wallet 0x123...``

## Configuring
To configure you will need to manually change some values inside the file before compiling

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