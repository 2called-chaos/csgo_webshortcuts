# [CS:GO] - Webshortcuts / MOTD fix

This project consists of:

* a [sourcemod plugin](https://github.com/2called-chaos/csgo_webshortcuts/tree/master/addons/sourcemod) that provides URL shortcuts and open URL commands
* a [HTML/JS](https://github.com/2called-chaos/csgo_webshortcuts/blob/master/html_file/ws.html) only file which provides the actual fix to the problem
* a [stock sourcemod function](https://github.com/2called-chaos/csgo_webshortcuts/blob/master/addons/sourcemod/scripting/include/csgo_motdfix.inc) which can be used to fix other plugins more easily
* a [fixed version of basetriggers](https://github.com/2called-chaos/csgo_webshortcuts/blob/master/addons/sourcemod/scripting/csgo_motdfix_basetriggers.sp), see "Fix basetriggers"

## What's the issue/fix?

It's CS:GO, what should I say? If you open an URL normally via `ShowMOTDPanel` it doesn't show a window
and what's worse it bricks the internal browser meaning every subsequent call to `ShowMOTDPanel` will call
the first page opened, or nothing ¯\\_(ツ)_/¯

**The fix consists of two parts:**

* Use `window.open` to create popups that one can actually see
* "Break" the originating hidden page by redirecting it to nothingness
* I lied, there's three: You have to prevent/fix other calls to `ShowMOTDPanel` from other plugins or they might brick the browser

## CSGO Webshortcuts

Basically a rewrite of [Franc1sco's WebShortcuts](https://github.com/Franc1sco/WebShortcuts) with the following differences:

* Provides and uses a pure HTML/JS hosted file used for redirection (no PHP or node required, just plain HTML/JS)
* `sm_hasmotd` command to check if a client has `cl_disablehtmlmotd` enabled, target will not notice
* `sm_web` now accepts keywords as well (e.g. `/web @all !rules`)
* `sm_web` now notifies the target AND the command caller if the target client has `cl_disablehtmlmotd 1`
* `sm_browse` everyone can open browser windows for themselves

#### Commands

- targets use [targeting selectors](https://wiki.alliedmods.net/Admin_Commands_(SourceMod)#How_to_Target) (e.g. @all @alive @ct)

* `sm_browse <url>`<br>
  *(all)* Opens given URL in a window
* `sm_web <target> <url|keyword>`<br>
  *(GENERIC/b flag)* Opens given page or keyword for target
* `sm_hasmotd <target>`<br>
  *(GENERIC/b flag)* Tells you in chat whether the target can open MOTD windows or has disabled it via `cl_disablehtmlmotd 1`

#### Cvars

* `sm_csgo_motdfix_url "https://funcs.de/ws.html"`<br>
  Full URL to your ws.html (you can use the default if you want, see "HTML hosting")

#### Configuration

Modify the configuration file `configs/csgo_webshortcuts.txt` according to these examples:

```
//*
// Usage: "trigger" "Javascript window options" http://www.site.com
//   * window options might be "width=800,height=600"
//   * set window options to just "hidden" for music, can be canceled with any URL or just `about:blank`
//   * possible variables: {NAME} {STEAM_ID} {USER_ID} {IP} {SERVER_IP} {SERVER_PORT}
//*
"google" "" http://www.google.com
"gametracker" "width=1024,height=720" http://www.gametracker.com/server_info/{SERVER_IP}:{SERVER_PORT}/

//"!rules" "" http://example.com/rules

// music
"!party" "hidden" https://www.youtube.com/embed/UtpOFj9aJZs?autoplay=true
"!off" "hidden" about:blank
```

## HTML hosting

Note that the URL hash (that is everything after the #) is not being send to the server but only accessible by Javascript, that means the target URLs don't show up in access logs.

* The default is `https://funcs.de/ws.html` and you can use that if you want.
* You can use RawGit which points to this repository: `https://cdn.rawgit.com/2called-chaos/csgo_webshortcuts/v1.0.0/html_file/ws.html`
* You can plonk the HTML virtually anywhere accessible and use your own URL.

## Fixing other plugins

**Reference:**

```sp
void ShowMOTDPanel(int client, const char[] title, const char[] msg, int type)
void ShowVGUIPanel(int client, const char[] name, Handle Kv, bool show);
void MOTDFixOpenURL(int client, const char[] wopts, const char[] url, bool visible = true);
```

1. Use the [stock sourcemod function](https://github.com/2called-chaos/csgo_webshortcuts/blob/master/addons/sourcemod/scripting/include/csgo_motdfix.inc) and include it in the plugin you want to fix. It will attempt to use `sm_csgo_motdfix_url` cvar as base url or fallbacks to the defined `CSGO_MOTDFIX_URL` which you might want to change, see "HTML hosting".

2. Search for all calls to `ShowMOTDPanel` and `ShowVGUIPanel` and get a grasp of what they are doing and replace them with the stock function if they open a URL or disable them if they don't (as they will brick the browser).

**Example:** (of me fixing GunGame winner display)

```sp
  // broken
  ShowMOTDPanel(i, "", url, MOTDPANEL_TYPE_URL);

  // fix
  MOTDFixOpenURL(i, "", url);
```

### Fix basetriggers

Sourcemod's default "basetriggers" plugin has a chat handler for "motd" and bricks the respective client's browser when invoked.

1. move `plugins/basetriggers.sp` into the disabled folder
2. use the [fixed version of basetriggers](https://github.com/2called-chaos/csgo_webshortcuts/blob/master/addons/sourcemod/plugins/disabled/csgo_motdfix_basetriggers.smx) (*[source](https://github.com/2called-chaos/csgo_webshortcuts/blob/master/addons/sourcemod/scripting/csgo_motdfix_basetriggers.sp)*) instead
3. set cvar `sm_motd_url` to the desired page in your `cfg/sourcemod/sourcemod.cfg`. If the cvar is not set, it will behave like normal (and brick the browser).
4. Use [CSGO Webshortcuts](https://github.com/2called-chaos/csgo_webshortcuts/blob/master/addons/sourcemod/plugins/csgo_webshortcuts.smx) plugin to get `sm_csgo_motdfix_url` cvar or you have to change the URL in the include file and compile the fix yourself, or you take the default URL see HTML hosting.

## Random facts

* CS:GO disabled motd display when joining servers, add this to your `cfg/sourcemod/sourcemod.cfg`: `sm_cvar sv_disable_motd 0` (it's a protected cvar hence the use of sm_cvar)

## Contributing

  Contributions are very welcome! Either report errors, bugs and propose features or directly submit code:

  1. Fork it ( http://github.com/2called-chaos/csgo_motdfix/fork )
  2. Create your feature branch (`git checkout -b my-new-feature`)
  3. Commit your changes (`git commit -am 'Added some feature'`)
  4. Push to the branch (`git push origin my-new-feature`)
  5. Create new Pull Request

## Legal

* This repository is licensed under the MIT license.
