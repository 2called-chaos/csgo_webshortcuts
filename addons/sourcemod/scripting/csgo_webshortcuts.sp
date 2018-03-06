#include <sourcemod>
#include <csgo_motdfix>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_AUTHOR      "2called-chaos"
#define PLUGIN_NAME        "CS:GO Webshortcuts"
#define PLUGIN_VERSION     "1.0.1"
#define PLUGIN_DESCRIPTION "Provides chat/command triggered web shortcuts"
#define PLUGIN_URL         "https://github.com/2called-chaos/csgo_webshortcuts"

public Plugin myinfo = { name = PLUGIN_NAME, author = PLUGIN_AUTHOR, description = PLUGIN_DESCRIPTION, version = PLUGIN_VERSION, url = PLUGIN_URL };

// Server IP/Port cache
char g_ServerIp [32];
char g_ServerPort [16];

// config storage arrays
Handle g_LinkNames;
Handle g_LinkOpts;
Handle g_LinkURLs;

public void OnPluginStart()
{
  CreateConVar("sm_csgo_motdfix_url", CSGO_MOTDFIX_URL, "Full URL to your hosted ws.html");
  RegConsoleCmd("say", Event_OnSay);
  RegConsoleCmd("say_team", Event_OnSay);
  RegConsoleCmd("sm_browse", Command_Browse, "Open URL or keyword for caller");
  RegAdminCmd("sm_web", Command_Web, ADMFLAG_GENERIC, "Open URL or keyword for target");
  RegAdminCmd("sm_hasmotd", Command_Hasmotd, ADMFLAG_GENERIC, "Checks if target has motd enabled");

  // initialize config storage arrays
  g_LinkNames = CreateArray(32);
  g_LinkOpts  = CreateArray(64);
  g_LinkURLs  = CreateArray(512);

  CacheServerIp();
  LoadPluginConfig();
}

public void OnMapStart()
{
  LoadPluginConfig();
}

public Action Event_OnSay(int client, int args)
{
  if (!client) return Plugin_Continue;

  char text [512];
  GetCmdArgString(text, sizeof(text));
  StripQuotes(text);
  TrimString(text);
  int link_index = LookupLinkIndex(text);

  if (link_index == -1)
  {
    return Plugin_Continue;
  }
  else
  {
    OpenLinkIndexToClient(client, link_index, -1, false);
    return Plugin_Handled;
  }
}

public Action Command_Browse(int client, int args)
{
  if (args < 1)
  {
    ReplyToCommand(client, "[SM] Usage: sm_browse <url>");
    return Plugin_Handled;
  }

  // read url
  char url[512];
  GetCmdArgString(url, sizeof(url));
  StripQuotes(url);
  TrimString(url);

  if(StrContains(url, "http://", false) != 0 && StrContains(url, "https://", false) != 0)
    Format(url, sizeof(url), "http://%s", url);

  OpenURLToClient(client, "", url, client, false);

  return Plugin_Handled;
}

public Action Command_Web(int client, int args)
{
  if (args < 2)
  {
    ReplyToCommand(client, "[SM] Usage: sm_web <target> <url|keyword>");
    return Plugin_Handled;
  }

  // read arguments
  char pattern[96], url[512];
  GetCmdArg(1, pattern, sizeof(pattern));
  GetCmdArgString(url, sizeof(url));
  ReplaceString(url, sizeof(url), pattern, "");
  StripQuotes(url);
  TrimString(url);

  // find targets
  int targets[129];
  char buffer[64];
  bool ml = false;
  int count = ProcessTargetString(pattern, client, targets, sizeof(targets), 0, buffer, sizeof(buffer), ml);

  // no targets
  if (count <= 0)
  {
    ReplyToCommand(client, "Bad target");
    return Plugin_Handled;
  }

  // lookup index
  int link_index = LookupLinkIndex(url);
  if (link_index == -1)
  {
    if(StrContains(url, "http://", false) != 0 && StrContains(url, "https://", false) != 0)
      Format(url, sizeof(url), "http://%s", url);

    for (int i = 0; i < count; i++)
      OpenURLToClient(targets[i], "", url, client, false);
  }
  else
  {
    for (int i = 0; i < count; i++)
      OpenLinkIndexToClient(targets[i], link_index, client, false);
  }
  return Plugin_Handled;
}

public Action Command_Hasmotd(int client, int args)
{
  if (args != 1)
  {
    ReplyToCommand(client, "[SM] Usage: sm_hasmotd <target>");
    return Plugin_Handled;
  }

  char pattern[96];
  GetCmdArg(1, pattern, sizeof(pattern));

  // find targets
  int targets[129];
  char buffer[64];
  bool ml = false;
  int count = ProcessTargetString(pattern, client, targets, sizeof(targets), 0, buffer, sizeof(buffer), ml);

  // no targets
  if (count <= 0)
  {
    ReplyToCommand(client, "Bad target");
    return Plugin_Handled;
  }

  // origin DP
  DataPack dpOrigin = new DataPack();
  dpOrigin.WriteCell(client);
  dpOrigin.WriteCell(1);

  for (int i = 0; i < count; i++)
    QueryClientConVar(targets[i], "cl_disablehtmlmotd", view_as<ConVarQueryFinished>(NotifyClientMotdDisabled), dpOrigin);

  return Plugin_Handled;
}

public int LookupLinkIndex(char [] text)
{
  char name[512];
  int size = GetArraySize(g_LinkNames);
  for (int i; i != size; ++i)
  {
    GetArrayString(g_LinkNames, i, name, sizeof(name));
    if (StrEqual(text, name, false)) return i;
  }
  return -1;
}

public void OpenLinkIndexToClient(int client, int link_index, int origin_client, bool snoop)
{
  char wopts[64], url[512];
  GetArrayString(g_LinkOpts, link_index, wopts, sizeof(wopts));
  GetArrayString(g_LinkURLs, link_index, url, sizeof(url));
  OpenURLToClient(client, wopts, url, origin_client, snoop);
}

public void OpenURLToClient(int client, char [] wopts, char [] url, int origin_client, bool snoop)
{
  // origin DP
  DataPack dpOrigin = new DataPack();
  dpOrigin.WriteCell(client);
  dpOrigin.WriteCell(0);
  QueryClientConVar(client, "cl_disablehtmlmotd", view_as<ConVarQueryFinished>(NotifyClientMotdDisabled), dpOrigin);

  char urlcopy[512];
  strcopy(urlcopy, sizeof(urlcopy), url);

  bool visible = true;
  if (StrEqual(wopts, "hidden", false))
  {
    wopts[0] = '\0';
    visible = false;
  }

  ReplaceURLVariables(client, urlcopy, sizeof(urlcopy));
  MOTDFixOpenURL(client, wopts, urlcopy, visible);
}

public void ReplaceURLVariables(int client, char [] url, int url_size)
{
  char steam_id[64], user_id[16], name[64], client_ip[32];
  GetClientAuthId(client, AuthId_Steam2, steam_id, sizeof(steam_id));
  FormatEx(user_id, sizeof(user_id), "%u", GetClientUserId(client));
  GetClientName(client, name, sizeof(name));
  GetClientIP(client, client_ip, sizeof(client_ip));

  ReplaceString(url, url_size, "{SERVER_IP}", g_ServerIp);
  ReplaceString(url, url_size, "{SERVER_PORT}", g_ServerPort);
  ReplaceString(url, url_size, "{STEAM_ID}", steam_id);
  ReplaceString(url, url_size, "{USER_ID}", user_id);
  ReplaceString(url, url_size, "{NAME}", name);
  ReplaceString(url, url_size, "{IP}", client_ip);
}

void CacheServerIp()
{
  Handle cvar = FindConVar("hostip");
  int hostip = GetConVarInt(cvar);
  FormatEx(g_ServerIp, sizeof(g_ServerIp), "%u.%u.%u.%u",
    (hostip >> 24) & 0x000000FF, (hostip >> 16) & 0x000000FF, (hostip >> 8) & 0x000000FF, hostip & 0x000000FF);

  cvar = FindConVar("hostport");
  GetConVarString(cvar, g_ServerPort, sizeof(g_ServerPort));
}

public void NotifyClientMotdDisabled(QueryCookie cookie, int client, ConVarQueryResult result, char [] cvarName, char [] cvarValue, DataPack dpOrigin)
{
  // read origin DP
  dpOrigin.Reset();
  int origin_client = dpOrigin.ReadCell();
  int snoop = dpOrigin.ReadCell();

  char name[64];
  GetClientName(client, name, sizeof(name));
  if (origin_client > -1 && snoop)
  {
    PrintToChat(origin_client, "[%s] %s", name, (StrEqual(cvarValue, "1") ? "NOT SUPPORTED" : "supported"));
  }
  else if (StringToInt(cvarValue) > 0)
  {
    if (origin_client > -1 && origin_client != client)
      PrintToChat(origin_client, "[%s] could not open page (NOT SUPPORTED)", name);

    PrintToChat(client, "---------------------------------------------------------------");
    PrintToChat(client, "We cannot display the requested content because you have disabled MOTD functionality. Type in console and try again:");
    PrintToChat(client, "cl_disablehtmlmotd 0");
    PrintToChat(client, "---------------------------------------------------------------");
  }
}

void LoadPluginConfig()
{
  char buffer [1024];
  BuildPath(Path_SM, buffer, sizeof(buffer), "configs/csgo_webshortcuts.txt");

  if (!FileExists(buffer))
  {
    LogError("[CSGO webshortcuts] Could not open file: %s (does not exist)", buffer);
    return;
  }

  Handle f = OpenFile(buffer, "r");
  if (f == INVALID_HANDLE)
  {
    LogError("[CSGO webshortcuts] Could not open file: %s", buffer);
    return;
  }

  // clear config storage arrays
  ClearArray(g_LinkNames);
  ClearArray(g_LinkOpts);
  ClearArray(g_LinkURLs);

  // buffers
  char name [32];
  char opts [256];
  char url  [512];

  // read file
  while (!IsEndOfFile(f) && ReadFileLine(f, buffer, sizeof(buffer)))
  {
    TrimString(buffer);

    // ignore terminations and comments
    if (buffer[0] == '\0' || buffer[0] == ';' || (buffer[0] == '/' && buffer[1] == '/')) continue;

    // ignore lines without name argument
    int name_pos = BreakString(buffer, name, sizeof(name));
    if (name_pos == -1) continue;

    // ignore lines without option argument
    int opts_pos = BreakString(buffer[name_pos], opts, sizeof(opts));
    if (opts_pos == -1) continue;

    // copy rest of line as link
    strcopy(url, sizeof(url), buffer[name_pos + opts_pos]);
    TrimString(url);

    // save in array
    PushArrayString(g_LinkNames, name);
    PushArrayString(g_LinkOpts, opts);
    PushArrayString(g_LinkURLs, url);
  }

  CloseHandle(f);
}
