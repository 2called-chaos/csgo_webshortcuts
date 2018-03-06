#if defined _csgo_motdfix_included
#endinput
#endif
#define _csgo_motdfix_included

#define CSGO_MOTDFIX_URL "https://funcs.de/ws.html"

stock void MOTDFixOpenURL(int client, const char[] wopts, const char[] url, bool visible = true)
{
  char final_url[512];
  if (visible) {
    char base_url[64];
    ConVar url_cvar = FindConVar("sm_csgo_motdfix_url");
    if(url_cvar == INVALID_HANDLE) {
      strcopy(base_url, sizeof(base_url), CSGO_MOTDFIX_URL);
    } else {
      url_cvar.GetString(base_url, sizeof(base_url));
    }
    Format(final_url, sizeof(final_url), "%s#%s#%s", base_url, wopts, url);
  }
  else
  {
    strcopy(final_url, sizeof(final_url), url);
  }

  KeyValues kv = new KeyValues("data");
  kv.SetString("title", "title"); // title never shows up anywhere
  kv.SetString("type", "2"); // url
  kv.SetString("msg", final_url);
  ShowVGUIPanel(client, "info", kv, visible);
  delete kv;
}

