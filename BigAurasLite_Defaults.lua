-- BigAurasLite_Defaults.lua (v1.10.1)

function BAL_Defaults()
  return {
    durationFallback = 1.2,
    blockOmniCC      = true,
    combatOnly       = false,
    tooltip          = true,
    history          = true,
    showTag          = true,
    autoDemotePrevious = true,

    -- Filtry / progi
    filter          = "enemies", -- "both" | "enemies" | "friends"
    mainMinRemain   = 0.0,       -- pomijaj bardzo krótkie resztki na głównej ikonie (0=off)

    soundLimiter = { enabled = false, sec = 2.0 },

    pos = {
      target = { point="CENTER", rel="CENTER", x=-100, y=150, scale=1.0 },
      focus  = { point="CENTER", rel="CENTER", x= 100, y=150, scale=1.0 },
    },

    ui = {
      contentSize = 64,
      inset       = 6,

      -- Classic border (useSolid=false)
      borderStyle = "tooltip", -- "tooltip" | "dialog"
      edgeSize    = 24,
      edgeSize2   = 24,

      -- Solid (useSolid=true)
      useSolid    = false,
      borderPx    = 3,
      borderPx2   = 3,
      solidInset  = 4,
      solidInset2 = 4,
      solidShape  = "square",  -- "square" | "rounded"

      strata      = "MEDIUM",
    },

    -- Style (font & timer)
    style = {
      fontPath   = "Fonts\\FRIZQT__.TTF",
      fontOutline= "OUTLINE",
      baseSize   = 26,
      cdAlpha    = 0.55,
      showSpiral = true,
    },

    -- Snap / Click-through / Pixel
    grid = { enabled=false, size=8 },
    clickThrough = { mode="off", modifier="ALT" }, -- mode: "off"|"on"|"hold"
    pixelPerfect = false,

    sounds = {
      immune   = "Sound\\Interface\\AlarmClockWarning3.wav",
      offense  = "Sound\\Spells\\PVPFlagTakenMono.wav",
      defense  = "Sound\\Interface\\RaidWarning.wav",
    },

    hardprioEnabled = false,
    hardprio = {
      [19263] = 100, [46924] = 90, [31224] = 80, [48792] = 75,
      [51690] = 65,  [48707] = 60, [19574] = 60,
    },

    second = {
      enabled   = true,
      scale     = 0.75,
      anchor    = "below",  -- "left" | "right" | "above" | "below"
      gap       = 8,
      offsetX   = 0,
      offsetY   = 0,
      minRemain = 1.0,
      tag       = true,
    },

    tracked = {
  -- ================== IMMUNE / CC-BREAK / FULL ==================
  [642]   = { dur=12, note="Paladin: Divine Shield (Bubble)",        type="immune" },
  [1022]  = { dur=10, note="Paladin: Hand of Protection",            type="immune" },
  [1044]  = { dur=10, note="Paladin: Hand of Freedom (snare immune)",type="immune" },
  [31821] = { dur=6,  note="Paladin: Aura Mastery (silence immune)", type="immune" },

  [19263] = { dur=5,  note="Hunter: Deterrence",                     type="immune" },
  [19574] = { dur=10, note="Hunter: Bestial Wrath (stun immune)",    type="immune" },
  [34471] = { dur=10, note="Hunter: The Beast Within",               type="immune" },

  [45438] = { dur=10, note="Mage: Ice Block",                        type="immune" },

  [46924] = { dur=6,  note="Warrior: Bladestorm (stun/cc immune)",   type="immune" },
  [18499] = { dur=10, note="Warrior: Berserker Rage (fear/sap break)",type="immune" },

  [31224] = { dur=5,  note="Rogue: Cloak of Shadows (magic immune)", type="immune" },

  [49039] = { dur=10, note="DK: Lichborne (fear/charm/sleep immune)",type="immune" },
  [48792] = { dur=12, note="DK: Icebound Fortitude (stun immune)",   type="immune" }, -- też DEFENSE

  [47585] = { dur=6,  note="Priest: Dispersion (massive DR/immune)", type="immune" },

  [50334] = { dur=15, note="Druid: Berserk (fear break/immune)",     type="immune" },

  -- ================== OFFENSE ==================
  [31884] = { dur=20, note="Paladin: Avenging Wrath (Wings)",        type="offense" },
  [20066]  = { dur=6,  note="Paladin: Repentance (setup) – opcj.",   type="offense" },

  [3045]   = { dur=15, note="Hunter: Rapid Fire",                    type="offense" },

  [12042]  = { dur=15, note="Mage: Arcane Power",                    type="offense" },
  [12472]  = { dur=20, note="Mage: Icy Veins",                       type="offense" },
  [28682]  = { dur=15, note="Mage: Combustion (WotLK stacks) – opcj.",type="offense" },

  [1719]   = { dur=12, note="Warrior: Recklessness",                 type="offense" },
  [12292]  = { dur=30, note="Warrior: Death Wish (jeśli aktywne)",   type="offense" },

  [51713]  = { dur=8,  note="Rogue: Shadow Dance",                   type="offense" },
  [13750]  = { dur=15, note="Rogue: Adrenaline Rush",                type="offense" },
  [51690]  = { dur=2.5,note="Rogue: Killing Spree",                  type="offense" },

  [51271]  = { dur=20, note="DK: Unbreakable Armor (Frost burst)",   type="offense" },
  [49016]  = { dur=30, note="DK: Hysteria (Unholy Frenzy, target)",  type="offense" },
  [49206]  = { dur=30, note="DK: Summon Gargoyle (pressure)",        type="offense" },

  [10060]  = { dur=15, note="Priest: Power Infusion",                type="offense" },

  [2825]   = { dur=40, note="Shaman: Bloodlust",                     type="offense" },
  [32182]  = { dur=40, note="Shaman: Heroism",                       type="offense" },
  [16166]  = { dur=15, note="Shaman: Elemental Mastery – okno burstu",type="offense" },

  [50334]  = { dur=15, note="Druid: Berserk (Cat/Bear dps)",         type="offense" }, -- też IMMUNE (fear)

  [59672]  = { dur=30, note="Warlock: Metamorphosis (Demo)",         type="offense" },

  -- ================== DEFENSE ==================
  [498]   = { dur=12, note="Paladin: Divine Protection",             type="defense" },
  [53601] = { dur=30, note="Paladin: Sacred Shield (proc aura)",     type="defense" },

  [48707] = { dur=5,  note="DK: Anti-Magic Shell",                   type="defense" },
  [49222] = { dur=60, note="DK: Bone Shield (charges)",              type="defense" },

  [871]   = { dur=12, note="Warrior: Shield Wall",                   type="defense" },
  [20230] = { dur=12, note="Warrior: Retaliation",                   type="defense" },
  [55694] = { dur=10, note="Warrior: Enraged Regeneration",          type="defense" },

  [26669] = { dur=15, note="Rogue: Evasion",                         type="defense" },
  [45182] = { dur=3,  note="Rogue: Cheat Death (proc)",              type="defense" },

  [47788] = { dur=10, note="Priest: Guardian Spirit",                type="defense" },
  [33206] = { dur=8,  note="Priest: Pain Suppression",               type="defense" },

  [30823] = { dur=15, note="Shaman: Shamanistic Rage",               type="defense" },

  [22812] = { dur=12, note="Druid: Barkskin",                        type="defense" },
  [61336] = { dur=20, note="Druid: Survival Instincts",              type="defense" },
  [22842] = { dur=20, note="Druid: Frenzied Regeneration",           type="defense" },

  [47860] = { dur=20, note="Warlock: Nether Protection (proc) – opcj.", type="defense" },
},
  }
end
