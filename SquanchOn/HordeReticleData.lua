-- Selected live aura data; function strings are evidence and are never executed.
local _, addon = ...
addon.HordeReticleData = {
  ["Combat"] = {
    ["actions"] = {
      ["finish"] = {
        ["do_glow"] = false,
        ["glow_action"] = "hide",
      },
      ["init"] = {
        ["custom"] = "",
        ["do_custom"] = false,
      },
      ["start"] = {
        ["do_glow"] = false,
        ["do_message"] = false,
        ["do_sound"] = false,
        ["sound"] = " custom",
      },
    },
    ["alpha"] = 0.5,
    ["anchorFrameType"] = "SCREEN",
    ["anchorPoint"] = "CENTER",
    ["animation"] = {
      ["finish"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "fade",
        ["type"] = "none",
      },
      ["main"] = {
        ["alpha"] = 0.5,
        ["alphaType"] = "alphaPulse",
        ["colorA"] = 1,
        ["colorB"] = 0,
        ["colorG"] = 0,
        ["colorR"] = 0,
        ["colorType"] = "pulseHSV",
        ["duration"] = "2",
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "alphaPulse",
        ["rotate"] = 0,
        ["rotateType"] = "wobble",
        ["scaleType"] = "pulse",
        ["scalex"] = 1.1,
        ["scaley"] = 1.1,
        ["translateType"] = "spiralandpulse",
        ["type"] = "preset",
        ["use_alpha"] = false,
        ["use_color"] = true,
        ["use_rotate"] = false,
        ["use_scale"] = false,
        ["use_translate"] = false,
        ["x"] = 0,
        ["y"] = 0,
      },
      ["start"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "shrink",
        ["type"] = "none",
      },
    },
    ["blendMode"] = "ADD",
    ["color"] = {
      [1] = 0.3921568627451,
      [2] = 0,
      [3] = 0,
      [4] = 0.75,
    },
    ["conditions"] = {
    },
    ["frameStrata"] = 4,
    ["height"] = 35,
    ["id"] = "Combat",
    ["information"] = {
      ["forceEvents"] = true,
      ["ignoreOptionsEventErrors"] = true,
    },
    ["load"] = {
      ["class"] = {
        ["multi"] = {
        },
      },
      ["size"] = {
        ["multi"] = {
        },
      },
      ["spec"] = {
        ["multi"] = {
        },
      },
      ["talent"] = {
        ["multi"] = {
        },
      },
      ["zoneIds"] = "",
    },
    ["parent"] = "The Terminator",
    ["regionType"] = "texture",
    ["rotation"] = 0,
    ["selfPoint"] = "CENTER",
    ["texture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura105",
    ["textureWrapMode"] = "CLAMP",
    ["triggers"] = {
      [1] = {
        ["trigger"] = {
          ["buffShowOn"] = "showOnActive",
          ["debuffType"] = "HELPFUL",
          ["duration"] = "1",
          ["event"] = "Conditions",
          ["names"] = {
          },
          ["spellIds"] = {
          },
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
          ["type"] = "unit",
          ["unevent"] = "auto",
          ["unit"] = "player",
          ["use_alwaystrue"] = true,
          ["use_incombat"] = true,
          ["use_unit"] = true,
        },
        ["untrigger"] = {
        },
      },
      ["activeTriggerMode"] = -10,
      ["disjunctive"] = "any",
    },
    ["uid"] = "5)GB45K5wLs",
    ["width"] = 35,
    ["xOffset"] = 0,
    ["yOffset"] = 0,
  },
  ["Cursor GCD "] = {
    ["actions"] = {
      ["finish"] = {
      },
      ["init"] = {
        ["custom"] = "",
        ["do_custom"] = false,
      },
      ["start"] = {
      },
    },
    ["alpha"] = 0.5,
    ["anchorFrameParent"] = false,
    ["anchorFrameType"] = "SCREEN",
    ["anchorPoint"] = "CENTER",
    ["animation"] = {
      ["finish"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "shrink",
        ["type"] = "preset",
      },
      ["main"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["type"] = "none",
      },
      ["start"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "shrink",
        ["type"] = "preset",
      },
    },
    ["auraRotation"] = 0,
    ["backgroundColor"] = {
      [1] = 0,
      [2] = 0,
      [3] = 0,
      [4] = 0.3400000333786,
    },
    ["backgroundTexture"] = "450915",
    ["blendMode"] = "BLEND",
    ["color"] = {
    },
    ["compress"] = false,
    ["conditions"] = {
    },
    ["crop_x"] = 0.5,
    ["crop_y"] = 0.5,
    ["foregroundColor"] = {
      [1] = 1,
      [2] = 0,
      [3] = 0.035294117647059,
      [4] = 0.75,
    },
    ["foregroundTexture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura105",
    ["frameStrata"] = 5,
    ["height"] = 23.5,
    ["id"] = "Cursor GCD ",
    ["information"] = {
      ["forceEvents"] = true,
      ["ignoreOptionsEventErrors"] = true,
    },
    ["inverse"] = false,
    ["load"] = {
      ["class"] = {
        ["multi"] = {
        },
      },
      ["size"] = {
        ["multi"] = {
        },
      },
      ["spec"] = {
        ["multi"] = {
        },
      },
      ["talent"] = {
        ["multi"] = {
        },
      },
      ["use_combat"] = true,
      ["use_never"] = false,
      ["zoneIds"] = "",
    },
    ["orientation"] = "VERTICAL",
    ["parent"] = "The Terminator",
    ["regionType"] = "progresstexture",
    ["rotation"] = 0,
    ["sameTexture"] = true,
    ["selfPoint"] = "CENTER",
    ["smoothProgress"] = true,
    ["textureWrapMode"] = "CLAMP",
    ["triggers"] = {
      [1] = {
        ["trigger"] = {
          ["debuffType"] = "HELPFUL",
          ["duration"] = "1",
          ["event"] = "Global Cooldown",
          ["hand"] = "main",
          ["names"] = {
          },
          ["spellIds"] = {
          },
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
          ["type"] = "spell",
          ["unevent"] = "auto",
          ["unit"] = "player",
          ["use_absorbMode"] = true,
          ["use_alwaystrue"] = true,
          ["use_hand"] = true,
          ["use_unit"] = true,
        },
        ["untrigger"] = {
        },
      },
      [2] = {
        ["trigger"] = {
          ["duration"] = "1",
          ["event"] = "Conditions",
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
          ["type"] = "unit",
          ["unevent"] = "auto",
          ["unit"] = "player",
          ["use_alwaystrue"] = true,
          ["use_incombat"] = true,
          ["use_unit"] = true,
        },
        ["untrigger"] = {
        },
      },
      [3] = {
        ["trigger"] = {
          ["event"] = "Health",
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
        },
        ["untrigger"] = {
        },
      },
      ["activeTriggerMode"] = -10,
      ["disjunctive"] = "any",
    },
    ["uid"] = "8YLX6LVC0aT",
    ["url"] = "https://wago.io/OWg3rTo0a/3",
    ["user_x"] = 0,
    ["user_y"] = 0,
    ["width"] = 23.5,
    ["xOffset"] = 0,
    ["yOffset"] = 0,
  },
  ["Execute"] = {
    ["actions"] = {
      ["finish"] = {
        ["do_glow"] = false,
        ["do_message"] = false,
        ["do_sound"] = true,
        ["hide_all_glows"] = true,
        ["message"] = "%i",
        ["message_type"] = "COMBAT",
        ["sound"] = "Interface\\Quiet.ogg",
      },
      ["init"] = {
        ["custom"] = "",
        ["do_custom"] = false,
      },
      ["start"] = {
        ["do_custom"] = false,
        ["do_glow"] = true,
        ["do_message"] = false,
        ["do_sound"] = true,
        ["glow_action"] = "show",
        ["glow_color"] = {
          [1] = 1,
          [2] = 0,
          [3] = 0,
          [4] = 1,
        },
        ["glow_frame"] = "ActionButton8",
        ["glow_frame_type"] = "NAMEPLATE",
        ["glow_type"] = "Pixel",
        ["message"] = "KILL",
        ["message_type"] = "ERROR",
        ["sound"] = "Interface\\AddOns\\M33kAuras\\PowerAurasMedia\\Sounds\\throwknife.ogg",
        ["sound_channel"] = "Master",
        ["use_glow_color"] = true,
      },
    },
    ["alpha"] = 1,
    ["anchorFrameParent"] = true,
    ["anchorFrameType"] = "SCREEN",
    ["anchorPoint"] = "CENTER",
    ["animation"] = {
      ["finish"] = {
        ["alpha"] = 0,
        ["alphaType"] = "straight",
        ["colorA"] = 1,
        ["colorB"] = 1,
        ["colorG"] = 1,
        ["colorR"] = 1,
        ["colorType"] = "pulseColor",
        ["duration"] = "1",
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "easeOut",
        ["preset"] = "shrink",
        ["rotate"] = 216,
        ["rotateType"] = "straight",
        ["scaleType"] = "straightScale",
        ["scalex"] = 0,
        ["scaley"] = 0,
        ["translateType"] = "straightTranslate",
        ["type"] = "custom",
        ["use_alpha"] = true,
        ["use_color"] = false,
        ["use_rotate"] = false,
        ["use_scale"] = false,
        ["use_translate"] = false,
        ["x"] = 0,
        ["y"] = 0,
      },
      ["main"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "pulse",
        ["type"] = "preset",
      },
      ["start"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "shrink",
        ["type"] = "preset",
      },
    },
    ["auraRotation"] = 0,
    ["backgroundColor"] = {
      [1] = 0,
      [2] = 0,
      [3] = 0,
      [4] = 0,
    },
    ["backgroundTexture"] = "450915",
    ["blendMode"] = "ADD",
    ["color"] = {
    },
    ["compress"] = false,
    ["conditions"] = {
    },
    ["crop_x"] = 0.5,
    ["crop_y"] = 1.5,
    ["foregroundColor"] = {
      [1] = 1,
      [2] = 0,
      [3] = 0.035294117647059,
      [4] = 1,
    },
    ["foregroundTexture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura22",
    ["frameStrata"] = 2,
    ["height"] = 49.999938964844,
    ["id"] = "Execute",
    ["information"] = {
      ["forceEvents"] = true,
      ["ignoreOptionsEventErrors"] = true,
    },
    ["inverse"] = false,
    ["load"] = {
      ["class"] = {
        ["multi"] = {
        },
      },
      ["size"] = {
        ["multi"] = {
        },
      },
      ["spec"] = {
        ["multi"] = {
        },
      },
      ["talent"] = {
        ["multi"] = {
        },
      },
      ["use_combat"] = true,
      ["use_never"] = false,
      ["zoneIds"] = "",
    },
    ["orientation"] = "VERTICAL",
    ["parent"] = "The Terminator",
    ["regionType"] = "progresstexture",
    ["rotation"] = 0,
    ["sameTexture"] = true,
    ["selfPoint"] = "CENTER",
    ["smoothProgress"] = true,
    ["textureWrapMode"] = "CLAMP",
    ["triggers"] = {
      [1] = {
        ["trigger"] = {
          ["debuffType"] = "HELPFUL",
          ["duration"] = "1",
          ["event"] = "Action Usable",
          ["hand"] = "main",
          ["names"] = {
          },
          ["realSpellName"] = 53351,
          ["spellIds"] = {
          },
          ["spellName"] = 53351,
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
          ["type"] = "spell",
          ["unevent"] = "auto",
          ["unit"] = "player",
          ["use_absorbMode"] = true,
          ["use_alwaystrue"] = true,
          ["use_charges"] = false,
          ["use_exact_spellName"] = true,
          ["use_hand"] = true,
          ["use_spellName"] = true,
          ["use_unit"] = true,
        },
        ["untrigger"] = {
        },
      },
      ["activeTriggerMode"] = -10,
      ["disjunctive"] = "any",
    },
    ["uid"] = "QRsilLjTjod",
    ["url"] = "https://wago.io/OWg3rTo0a/3",
    ["user_x"] = 0,
    ["user_y"] = 0,
    ["width"] = 74.999908447266,
    ["xOffset"] = 0,
    ["yOffset"] = -3.0517578125e-05,
  },
  ["Low Health"] = {
    ["actions"] = {
      ["finish"] = {
        ["do_glow"] = false,
        ["do_message"] = false,
        ["do_sound"] = false,
        ["hide_all_glows"] = false,
        ["message"] = "%i",
        ["message_type"] = "COMBAT",
        ["sound"] = "Interface\\Quiet.ogg",
      },
      ["init"] = {
        ["custom"] = "",
        ["do_custom"] = false,
      },
      ["start"] = {
        ["b"] = 0,
        ["do_custom"] = false,
        ["do_glow"] = false,
        ["do_loop"] = false,
        ["do_message"] = false,
        ["do_sound"] = false,
        ["g"] = 1,
        ["glow_action"] = "show",
        ["glow_border"] = true,
        ["glow_color"] = {
          [1] = 1,
          [2] = 1,
          [3] = 1,
          [4] = 1,
        },
        ["glow_frame"] = "MultiBarLeftButton5",
        ["glow_frame_type"] = "FRAMESELECTOR",
        ["glow_thickness"] = 1.5,
        ["glow_type"] = "buttonOverlay",
        ["message"] = "KILL",
        ["message_type"] = "ERROR",
        ["r"] = 1,
        ["sound"] = "Interface\\AddOns\\M33kAuras\\Media\\Sounds\\Drums.ogg",
        ["sound_channel"] = "Master",
        ["use_glow_color"] = true,
      },
    },
    ["alpha"] = 1,
    ["anchorFrameParent"] = true,
    ["anchorFrameType"] = "SCREEN",
    ["anchorPoint"] = "CENTER",
    ["animation"] = {
      ["finish"] = {
        ["alpha"] = 0,
        ["alphaType"] = "straight",
        ["colorA"] = 1,
        ["colorB"] = 1,
        ["colorG"] = 1,
        ["colorR"] = 1,
        ["colorType"] = "pulseColor",
        ["duration"] = "1",
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "easeOut",
        ["preset"] = "fade",
        ["rotate"] = 216,
        ["rotateType"] = "straight",
        ["scaleType"] = "straightScale",
        ["scalex"] = 0,
        ["scaley"] = 0,
        ["translateType"] = "straightTranslate",
        ["type"] = "preset",
        ["use_alpha"] = true,
        ["use_color"] = false,
        ["use_rotate"] = false,
        ["use_scale"] = false,
        ["use_translate"] = false,
        ["x"] = 0,
        ["y"] = 0,
      },
      ["main"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "pulse",
        ["type"] = "preset",
      },
      ["start"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "shrink",
        ["type"] = "preset",
      },
    },
    ["auraRotation"] = 0,
    ["backgroundColor"] = {
      [1] = 1,
      [2] = 0,
      [3] = 0,
      [4] = 0.33734887838364,
    },
    ["backgroundTexture"] = "450915",
    ["blendMode"] = "ADD",
    ["color"] = {
    },
    ["compress"] = false,
    ["conditions"] = {
    },
    ["crop_x"] = 0,
    ["crop_y"] = 0,
    ["foregroundColor"] = {
      [1] = 1,
      [2] = 0,
      [3] = 0,
      [4] = 0.49999988079071,
    },
    ["foregroundTexture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura4",
    ["frameStrata"] = 2,
    ["height"] = 75,
    ["id"] = "Low Health",
    ["information"] = {
      ["forceEvents"] = true,
      ["ignoreOptionsEventErrors"] = true,
    },
    ["inverse"] = false,
    ["load"] = {
      ["class"] = {
        ["multi"] = {
        },
      },
      ["size"] = {
        ["multi"] = {
        },
      },
      ["spec"] = {
        ["multi"] = {
        },
      },
      ["talent"] = {
        ["multi"] = {
        },
      },
      ["use_combat"] = true,
      ["use_never"] = false,
      ["zoneIds"] = "",
    },
    ["orientation"] = "VERTICAL",
    ["parent"] = "The Terminator",
    ["regionType"] = "progresstexture",
    ["rotation"] = 180,
    ["sameTexture"] = true,
    ["selfPoint"] = "CENTER",
    ["smoothProgress"] = true,
    ["textureWrapMode"] = "CLAMP",
    ["triggers"] = {
      [1] = {
        ["trigger"] = {
          ["debuffType"] = "HELPFUL",
          ["duration"] = "2",
          ["event"] = "Conditions",
          ["hand"] = "main",
          ["health"] = {
            [1] = "20",
          },
          ["health_operator"] = {
            [1] = "<",
          },
          ["names"] = {
          },
          ["percentpower"] = "15",
          ["percentpower_operator"] = "<",
          ["realSpellName"] = 781,
          ["spellIds"] = {
          },
          ["spellName"] = 781,
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
          ["type"] = "unit",
          ["unevent"] = "auto",
          ["unit"] = "player",
          ["use_absorbMode"] = true,
          ["use_alwaystrue"] = true,
          ["use_charges"] = false,
          ["use_exact_spellName"] = true,
          ["use_hand"] = true,
          ["use_health"] = true,
          ["use_percentpower"] = false,
          ["use_spellName"] = true,
          ["use_targetRequired"] = false,
          ["use_unit"] = true,
        },
        ["untrigger"] = {
        },
      },
      ["activeTriggerMode"] = -10,
      ["disjunctive"] = "any",
    },
    ["uid"] = "xs4aHtHB2Ic",
    ["url"] = "https://wago.io/OWg3rTo0a/3",
    ["user_x"] = 0,
    ["user_y"] = 0,
    ["width"] = 75,
    ["xOffset"] = 0,
    ["yOffset"] = 2.5,
  },
  ["Low Mana"] = {
    ["actions"] = {
      ["finish"] = {
        ["do_glow"] = false,
        ["do_message"] = false,
        ["do_sound"] = false,
        ["hide_all_glows"] = false,
        ["message"] = "%i",
        ["message_type"] = "COMBAT",
        ["sound"] = "Interface\\Quiet.ogg",
      },
      ["init"] = {
        ["custom"] = "",
        ["do_custom"] = false,
      },
      ["start"] = {
        ["b"] = 0,
        ["do_custom"] = false,
        ["do_glow"] = false,
        ["do_loop"] = false,
        ["do_message"] = false,
        ["do_sound"] = false,
        ["g"] = 1,
        ["glow_action"] = "show",
        ["glow_border"] = true,
        ["glow_color"] = {
          [1] = 1,
          [2] = 1,
          [3] = 1,
          [4] = 1,
        },
        ["glow_frame"] = "MultiBarLeftButton5",
        ["glow_frame_type"] = "FRAMESELECTOR",
        ["glow_thickness"] = 1.5,
        ["glow_type"] = "buttonOverlay",
        ["message"] = "KILL",
        ["message_type"] = "ERROR",
        ["r"] = 1,
        ["sound"] = "Interface\\AddOns\\M33kAuras\\Media\\Sounds\\Drums.ogg",
        ["sound_channel"] = "Master",
        ["use_glow_color"] = true,
      },
    },
    ["alpha"] = 1,
    ["anchorFrameParent"] = true,
    ["anchorFrameType"] = "SCREEN",
    ["anchorPoint"] = "CENTER",
    ["animation"] = {
      ["finish"] = {
        ["alpha"] = 0,
        ["alphaType"] = "straight",
        ["colorA"] = 1,
        ["colorB"] = 1,
        ["colorG"] = 1,
        ["colorR"] = 1,
        ["colorType"] = "pulseColor",
        ["duration"] = "1",
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "easeOut",
        ["preset"] = "fade",
        ["rotate"] = 216,
        ["rotateType"] = "straight",
        ["scaleType"] = "straightScale",
        ["scalex"] = 0,
        ["scaley"] = 0,
        ["translateType"] = "straightTranslate",
        ["type"] = "preset",
        ["use_alpha"] = true,
        ["use_color"] = false,
        ["use_rotate"] = false,
        ["use_scale"] = false,
        ["use_translate"] = false,
        ["x"] = 0,
        ["y"] = 0,
      },
      ["main"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "pulse",
        ["type"] = "preset",
      },
      ["start"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "shrink",
        ["type"] = "preset",
      },
    },
    ["auraRotation"] = 0,
    ["backgroundColor"] = {
      [1] = 0,
      [2] = 0,
      [3] = 1,
      [4] = 1,
    },
    ["backgroundTexture"] = "450915",
    ["blendMode"] = "ADD",
    ["color"] = {
    },
    ["compress"] = false,
    ["conditions"] = {
    },
    ["crop_x"] = 0,
    ["crop_y"] = 0,
    ["foregroundColor"] = {
      [1] = 0,
      [2] = 0,
      [3] = 1,
      [4] = 1,
    },
    ["foregroundTexture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura17",
    ["frameStrata"] = 2,
    ["height"] = 200,
    ["id"] = "Low Mana",
    ["information"] = {
      ["forceEvents"] = true,
      ["ignoreOptionsEventErrors"] = true,
    },
    ["inverse"] = false,
    ["load"] = {
      ["class"] = {
        ["multi"] = {
        },
      },
      ["size"] = {
        ["multi"] = {
        },
      },
      ["spec"] = {
        ["multi"] = {
        },
      },
      ["talent"] = {
        ["multi"] = {
        },
      },
      ["use_combat"] = true,
      ["use_never"] = false,
      ["zoneIds"] = "",
    },
    ["orientation"] = "VERTICAL",
    ["parent"] = "The Terminator",
    ["regionType"] = "progresstexture",
    ["rotation"] = 180,
    ["sameTexture"] = true,
    ["selfPoint"] = "CENTER",
    ["smoothProgress"] = true,
    ["textureWrapMode"] = "CLAMP",
    ["triggers"] = {
      [1] = {
        ["trigger"] = {
          ["debuffType"] = "HELPFUL",
          ["duration"] = "2",
          ["event"] = "Power",
          ["hand"] = "main",
          ["names"] = {
          },
          ["percentpower"] = {
            [1] = "15",
          },
          ["percentpower_operator"] = {
            [1] = "<",
          },
          ["realSpellName"] = 781,
          ["spellIds"] = {
          },
          ["spellName"] = 781,
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
          ["type"] = "unit",
          ["unevent"] = "auto",
          ["unit"] = "player",
          ["use_absorbMode"] = true,
          ["use_alwaystrue"] = true,
          ["use_charges"] = false,
          ["use_exact_spellName"] = true,
          ["use_hand"] = true,
          ["use_health"] = false,
          ["use_percentpower"] = true,
          ["use_spellName"] = true,
          ["use_targetRequired"] = false,
          ["use_unit"] = true,
        },
        ["untrigger"] = {
        },
      },
      ["activeTriggerMode"] = -10,
      ["disjunctive"] = "any",
    },
    ["uid"] = "7y5M)IuaQZ2",
    ["url"] = "https://wago.io/OWg3rTo0a/3",
    ["user_x"] = 0,
    ["user_y"] = 0,
    ["width"] = 200,
    ["xOffset"] = 0,
    ["yOffset"] = 2.5,
  },
  ["Mouseover Dot"] = {
    ["actions"] = {
      ["finish"] = {
      },
      ["init"] = {
        ["custom"] = "",
        ["do_custom"] = false,
      },
      ["start"] = {
      },
    },
    ["alpha"] = 1,
    ["anchorFrameParent"] = true,
    ["anchorFrameType"] = "MOUSE",
    ["anchorPoint"] = "CENTER",
    ["animation"] = {
      ["finish"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "fade",
        ["type"] = "preset",
      },
      ["main"] = {
        ["alpha"] = 0.5,
        ["alphaType"] = "alphaPulse",
        ["colorA"] = 1,
        ["colorB"] = 0,
        ["colorG"] = 0,
        ["colorR"] = 0,
        ["colorType"] = "pulseHSV",
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "alphaPulse",
        ["rotate"] = 0,
        ["scaleType"] = "pulse",
        ["scalex"] = 1.2,
        ["scaley"] = 1.2,
        ["translateType"] = "straightTranslate",
        ["type"] = "none",
        ["use_alpha"] = false,
        ["use_color"] = false,
        ["use_scale"] = false,
        ["use_translate"] = false,
        ["x"] = 0,
        ["y"] = 0,
      },
      ["start"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "fade",
        ["type"] = "preset",
        ["use_scale"] = false,
      },
    },
    ["backgroundColor"] = {
      [1] = 0.5,
      [2] = 0.5,
      [3] = 0.5,
      [4] = 0.5,
    },
    ["backgroundTexture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura3",
    ["blendMode"] = "BLEND",
    ["color"] = {
      [1] = 0.69019607843137,
      [2] = 0,
      [3] = 0.003921568627451,
      [4] = 1,
    },
    ["compress"] = false,
    ["conditions"] = {
      [1] = {
        ["changes"] = {
          [1] = {
            ["property"] = "color",
            ["value"] = {
              [1] = 1,
              [2] = 1,
              [3] = 1,
              [4] = 0,
            },
          },
        },
        ["check"] = {
          ["checks"] = {
            [1] = {
              ["trigger"] = 1,
              ["value"] = 1,
              ["variable"] = "show",
            },
            [2] = {
              ["trigger"] = 2,
              ["value"] = 0,
              ["variable"] = "show",
            },
          },
          ["trigger"] = -2,
          ["variable"] = "AND",
        },
      },
    },
    ["crop_x"] = 0.41,
    ["crop_y"] = 0.41,
    ["foregroundColor"] = {
      [1] = 1,
      [2] = 1,
      [3] = 1,
      [4] = 1,
    },
    ["foregroundTexture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura3",
    ["frameStrata"] = 9,
    ["height"] = 31,
    ["id"] = "Mouseover Dot",
    ["information"] = {
      ["forceEvents"] = true,
      ["ignoreOptionsEventErrors"] = true,
    },
    ["inverse"] = false,
    ["load"] = {
      ["class"] = {
        ["multi"] = {
        },
        ["single"] = "HUNTER",
      },
      ["size"] = {
        ["multi"] = {
        },
      },
      ["spec"] = {
        ["multi"] = {
        },
      },
      ["spellknown"] = 2974,
      ["talent"] = {
        ["multi"] = {
        },
      },
      ["use_class"] = true,
      ["use_level"] = false,
      ["use_never"] = false,
      ["use_spellknown"] = false,
      ["zoneIds"] = "",
    },
    ["orientation"] = "VERTICAL",
    ["parent"] = "The Terminator",
    ["regionType"] = "texture",
    ["rotation"] = 0,
    ["sameTexture"] = true,
    ["selfPoint"] = "CENTER",
    ["texture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura104",
    ["textureWrapMode"] = "CLAMP",
    ["triggers"] = {
      [1] = {
        ["trigger"] = {
          ["check"] = "update",
          ["custom"] = "function()    \
    if UnitExists(\"mouseover\") and UnitIsVisible(\"mouseover\") and UnitCanAttack(\"player\", \"mouseover\") and (not UnitIsDead(\"mouseover\")) then\
        return true\
    else \
        return false\
    end\
end",
          ["custom_hide"] = "timed",
          ["custom_type"] = "status",
          ["debuffType"] = "HELPFUL",
          ["event"] = "Health",
          ["names"] = {
          },
          ["spellIds"] = {
          },
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
          ["type"] = "custom",
          ["unit"] = "player",
          ["use_alwaystrue"] = true,
        },
        ["untrigger"] = {
        },
      },
      [2] = {
        ["trigger"] = {
          ["check"] = "update",
          ["custom"] = "function()\
    local unit = \"mouseover\"\
    if UnitExists(unit) and UnitIsVisible(unit) and UnitCanAttack(\"player\", unit) and not UnitIsDead(unit) then\
        local result\
        if IsSpellInRange then\
            result = IsSpellInRange(\"Auto Shot\", unit)\
        end\
        if result == nil and C_Spell and C_Spell.IsSpellInRange then\
            result = C_Spell.IsSpellInRange(75, unit)\
        end\
        return result == 1 or result == true\
    end\
    return false\
end\
\
\
",
          ["custom_type"] = "status",
          ["debuffType"] = "HELPFUL",
          ["type"] = "custom",
          ["unit"] = "player",
        },
        ["untrigger"] = {
        },
      },
      ["activeTriggerMode"] = 1,
      ["disjunctive"] = "any",
    },
    ["uid"] = "b30)WnkvUq6",
    ["url"] = "https://wago.io/jxJdu2yc6/1",
    ["user_x"] = 0,
    ["user_y"] = 0,
    ["width"] = 28,
    ["xOffset"] = 1.1,
    ["yOffset"] = 1.8,
  },
  ["Mouseover Glow"] = {
    ["actions"] = {
      ["finish"] = {
      },
      ["init"] = {
        ["custom"] = "",
        ["do_custom"] = false,
      },
      ["start"] = {
      },
    },
    ["alpha"] = 0.35,
    ["anchorFrameParent"] = true,
    ["anchorFrameType"] = "MOUSE",
    ["anchorPoint"] = "CENTER",
    ["animation"] = {
      ["finish"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "fade",
        ["type"] = "preset",
      },
      ["main"] = {
        ["alpha"] = 0.5,
        ["alphaType"] = "alphaPulse",
        ["colorA"] = 1,
        ["colorB"] = 0,
        ["colorG"] = 0,
        ["colorR"] = 0,
        ["colorType"] = "pulseHSV",
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "alphaPulse",
        ["rotate"] = 0,
        ["scaleType"] = "pulse",
        ["scalex"] = 1.2,
        ["scaley"] = 1.2,
        ["translateType"] = "straightTranslate",
        ["type"] = "none",
        ["use_alpha"] = false,
        ["use_color"] = false,
        ["use_scale"] = false,
        ["use_translate"] = false,
        ["x"] = 0,
        ["y"] = 0,
      },
      ["start"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "shrink",
        ["type"] = "preset",
        ["use_scale"] = false,
      },
    },
    ["backgroundColor"] = {
      [1] = 0.5,
      [2] = 0.5,
      [3] = 0.5,
      [4] = 0.5,
    },
    ["backgroundTexture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura3",
    ["blendMode"] = "ADD",
    ["color"] = {
      [1] = 0.69019607843137,
      [2] = 0,
      [3] = 0.003921568627451,
      [4] = 1,
    },
    ["compress"] = false,
    ["conditions"] = {
      [1] = {
        ["changes"] = {
          [1] = {
            ["property"] = "color",
            ["value"] = {
              [1] = 1,
              [2] = 1,
              [3] = 1,
              [4] = 0,
            },
          },
        },
        ["check"] = {
          ["checks"] = {
            [1] = {
              ["trigger"] = 1,
              ["value"] = 1,
              ["variable"] = "show",
            },
            [2] = {
              ["trigger"] = 2,
              ["value"] = 0,
              ["variable"] = "show",
            },
          },
          ["trigger"] = -2,
          ["variable"] = "AND",
        },
      },
    },
    ["crop_x"] = 0.41,
    ["crop_y"] = 0.41,
    ["foregroundColor"] = {
      [1] = 1,
      [2] = 1,
      [3] = 1,
      [4] = 1,
    },
    ["foregroundTexture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura3",
    ["frameStrata"] = 2,
    ["height"] = 50,
    ["id"] = "Mouseover Glow",
    ["information"] = {
      ["forceEvents"] = true,
      ["ignoreOptionsEventErrors"] = true,
    },
    ["inverse"] = false,
    ["load"] = {
      ["class"] = {
        ["multi"] = {
        },
        ["single"] = "HUNTER",
      },
      ["size"] = {
        ["multi"] = {
        },
      },
      ["spec"] = {
        ["multi"] = {
        },
      },
      ["spellknown"] = 2974,
      ["talent"] = {
        ["multi"] = {
        },
      },
      ["use_class"] = true,
      ["use_level"] = false,
      ["use_never"] = false,
      ["use_spellknown"] = false,
      ["zoneIds"] = "",
    },
    ["orientation"] = "VERTICAL",
    ["parent"] = "The Terminator",
    ["regionType"] = "texture",
    ["rotation"] = 0,
    ["sameTexture"] = true,
    ["selfPoint"] = "CENTER",
    ["texture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura22",
    ["textureWrapMode"] = "CLAMP",
    ["triggers"] = {
      [1] = {
        ["trigger"] = {
          ["check"] = "update",
          ["custom"] = "function()    \
    if UnitExists(\"mouseover\") and UnitIsVisible(\"mouseover\") and UnitCanAttack(\"player\", \"mouseover\") and (not UnitIsDead(\"mouseover\")) then\
        return true\
    else \
        return false\
    end\
end",
          ["custom_hide"] = "timed",
          ["custom_type"] = "status",
          ["debuffType"] = "HELPFUL",
          ["event"] = "Health",
          ["names"] = {
          },
          ["spellIds"] = {
          },
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
          ["type"] = "custom",
          ["unit"] = "player",
          ["use_alwaystrue"] = true,
        },
        ["untrigger"] = {
        },
      },
      [2] = {
        ["trigger"] = {
          ["check"] = "update",
          ["custom"] = "function()\
    local unit = \"mouseover\"\
    if UnitExists(unit) and UnitIsVisible(unit) and UnitCanAttack(\"player\", unit) and not UnitIsDead(unit) then\
        local result\
        if IsSpellInRange then\
            result = IsSpellInRange(\"Auto Shot\", unit)\
        end\
        if result == nil and C_Spell and C_Spell.IsSpellInRange then\
            result = C_Spell.IsSpellInRange(75, unit)\
        end\
        return result == 1 or result == true\
    end\
    return false\
end\
\
\
",
          ["custom_type"] = "status",
          ["debuffType"] = "HELPFUL",
          ["type"] = "custom",
          ["unit"] = "player",
        },
        ["untrigger"] = {
        },
      },
      ["activeTriggerMode"] = 1,
      ["disjunctive"] = "any",
    },
    ["uid"] = "hR5pi0cLIHe",
    ["url"] = "https://wago.io/jxJdu2yc6/1",
    ["user_x"] = 0,
    ["user_y"] = 0,
    ["width"] = 50,
    ["xOffset"] = 0,
    ["yOffset"] = 3,
  },
  ["No Combat"] = {
    ["actions"] = {
      ["finish"] = {
        ["do_glow"] = false,
        ["glow_action"] = "hide",
      },
      ["init"] = {
        ["custom"] = "",
        ["do_custom"] = false,
      },
      ["start"] = {
        ["do_glow"] = false,
        ["do_message"] = false,
        ["do_sound"] = false,
        ["sound"] = " custom",
      },
    },
    ["alpha"] = 0.75,
    ["anchorFrameType"] = "SCREEN",
    ["anchorPoint"] = "CENTER",
    ["animation"] = {
      ["finish"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "fade",
        ["type"] = "none",
      },
      ["main"] = {
        ["alpha"] = 0.5,
        ["alphaType"] = "alphaPulse",
        ["colorA"] = 1,
        ["colorB"] = 0,
        ["colorG"] = 0,
        ["colorR"] = 0,
        ["colorType"] = "pulseHSV",
        ["duration"] = "2",
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "pulse",
        ["rotate"] = 0,
        ["rotateType"] = "wobble",
        ["scaleType"] = "pulse",
        ["scalex"] = 1.1,
        ["scaley"] = 1.1,
        ["translateType"] = "spiralandpulse",
        ["type"] = "custom",
        ["use_alpha"] = false,
        ["use_color"] = true,
        ["use_rotate"] = false,
        ["use_scale"] = false,
        ["use_translate"] = false,
        ["x"] = 0,
        ["y"] = 0,
      },
      ["start"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "shrink",
        ["type"] = "none",
      },
    },
    ["blendMode"] = "BLEND",
    ["color"] = {
      [1] = 0,
      [2] = 0,
      [3] = 0,
      [4] = 0.75395312905312,
    },
    ["conditions"] = {
    },
    ["frameStrata"] = 4,
    ["height"] = 35,
    ["id"] = "No Combat",
    ["information"] = {
      ["forceEvents"] = true,
      ["ignoreOptionsEventErrors"] = true,
    },
    ["load"] = {
      ["class"] = {
        ["multi"] = {
        },
      },
      ["size"] = {
        ["multi"] = {
        },
      },
      ["spec"] = {
        ["multi"] = {
        },
      },
      ["talent"] = {
        ["multi"] = {
        },
      },
      ["zoneIds"] = "",
    },
    ["parent"] = "The Terminator",
    ["regionType"] = "texture",
    ["rotation"] = 0,
    ["selfPoint"] = "CENTER",
    ["texture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura105",
    ["textureWrapMode"] = "CLAMP",
    ["triggers"] = {
      [1] = {
        ["trigger"] = {
          ["buffShowOn"] = "showOnActive",
          ["debuffType"] = "HELPFUL",
          ["duration"] = "1",
          ["event"] = "Conditions",
          ["names"] = {
          },
          ["spellIds"] = {
          },
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
          ["type"] = "unit",
          ["unevent"] = "auto",
          ["unit"] = "player",
          ["use_alwaystrue"] = true,
          ["use_unit"] = true,
        },
        ["untrigger"] = {
        },
      },
      ["activeTriggerMode"] = -10,
      ["disjunctive"] = "any",
    },
    ["uid"] = "qfyqTNmnlFG",
    ["width"] = 35,
    ["xOffset"] = 0,
    ["yOffset"] = 0,
  },
  ["Pet Tracker"] = {
    ["actions"] = {
      ["finish"] = {
      },
      ["init"] = {
        ["custom"] = "",
        ["do_custom"] = false,
      },
      ["start"] = {
        ["do_custom"] = false,
        ["do_glow"] = false,
        ["do_message"] = false,
      },
    },
    ["alpha"] = 1,
    ["anchorFrameParent"] = false,
    ["anchorFrameType"] = "NAMEPLATE",
    ["anchorPoint"] = "CENTER",
    ["animation"] = {
      ["finish"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["type"] = "none",
      },
      ["main"] = {
        ["alpha"] = 0,
        ["alphaType"] = "straight",
        ["colorA"] = 1,
        ["colorB"] = 1,
        ["colorG"] = 1,
        ["colorR"] = 1,
        ["colorType"] = "straightColor",
        ["duration"] = "2",
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "easeOutIn",
        ["rotate"] = 0,
        ["scalex"] = 1,
        ["scaley"] = 1,
        ["translateType"] = "straightTranslate",
        ["type"] = "none",
        ["use_alpha"] = true,
        ["use_color"] = true,
        ["use_translate"] = true,
        ["x"] = 0,
        ["y"] = 50,
      },
      ["start"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["type"] = "none",
      },
    },
    ["blendMode"] = "BLEND",
    ["color"] = {
      [1] = 1,
      [2] = 1,
      [3] = 1,
      [4] = 0.76000000536442,
    },
    ["conditions"] = {
    },
    ["frameStrata"] = 2,
    ["height"] = 50,
    ["id"] = "Pet Tracker",
    ["information"] = {
      ["forceEvents"] = true,
    },
    ["load"] = {
      ["class"] = {
        ["multi"] = {
        },
      },
      ["size"] = {
        ["multi"] = {
        },
      },
      ["spec"] = {
        ["multi"] = {
        },
      },
      ["talent"] = {
        ["multi"] = {
        },
      },
    },
    ["parent"] = "The Terminator",
    ["regionType"] = "texture",
    ["rotation"] = 0,
    ["selfPoint"] = "CENTER",
    ["texture"] = "Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-99",
    ["textureWrapMode"] = "CLAMP",
    ["triggers"] = {
      [1] = {
        ["trigger"] = {
          ["auranames"] = {
            [1] = "Arcane Intellect",
          },
          ["behavior"] = "passive",
          ["character"] = "npc",
          ["class"] = "WARLOCK",
          ["classification"] = {
            ["multi"] = {
            },
            ["single"] = "normal",
          },
          ["debuffType"] = "HELPFUL",
          ["event"] = "Unit Characteristics",
          ["hostility"] = "friendly",
          ["nameplateType"] = "hostile",
          ["namerealm"] = "Squanch",
          ["names"] = {
          },
          ["percenthealth"] = "0",
          ["percenthealth_operator"] = ">=",
          ["showClones"] = true,
          ["spellIds"] = {
          },
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
          ["type"] = "unit",
          ["unit"] = "nameplate",
          ["unitisunit"] = "pet",
          ["useHostility"] = false,
          ["useName"] = true,
          ["use_alwaystrue"] = true,
          ["use_attackable"] = false,
          ["use_behavior"] = false,
          ["use_character"] = true,
          ["use_class"] = false,
          ["use_hostility"] = true,
          ["use_ignoreSelf"] = false,
          ["use_nameplateType"] = true,
          ["use_namerealm"] = false,
          ["use_percenthealth"] = false,
          ["use_petspec"] = false,
          ["use_unit"] = true,
          ["use_unitisunit"] = true,
        },
        ["untrigger"] = {
        },
      },
      ["activeTriggerMode"] = -10,
    },
    ["uid"] = "zDqvkCGJSqG",
    ["width"] = 50,
    ["xOffset"] = 0,
    ["yOffset"] = 40,
  },
  ["Target"] = {
    ["actions"] = {
      ["finish"] = {
        ["do_glow"] = false,
        ["glow_action"] = "hide",
      },
      ["init"] = {
        ["custom"] = "",
        ["do_custom"] = false,
      },
      ["start"] = {
        ["do_glow"] = false,
        ["do_message"] = false,
        ["do_sound"] = false,
        ["sound"] = " custom",
      },
    },
    ["alpha"] = 0.5,
    ["anchorFrameType"] = "SCREEN",
    ["anchorPoint"] = "CENTER",
    ["animation"] = {
      ["finish"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "fade",
        ["type"] = "none",
      },
      ["main"] = {
        ["alpha"] = 0.5,
        ["alphaType"] = "alphaPulse",
        ["colorA"] = 1,
        ["colorB"] = 0,
        ["colorG"] = 0,
        ["colorR"] = 0,
        ["colorType"] = "pulseColor",
        ["duration"] = "2",
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "pulse",
        ["rotate"] = 0,
        ["rotateType"] = "wobble",
        ["scaleType"] = "pulse",
        ["scalex"] = 1.1,
        ["scaley"] = 1.1,
        ["translateType"] = "spiralandpulse",
        ["type"] = "custom",
        ["use_alpha"] = false,
        ["use_color"] = true,
        ["use_rotate"] = false,
        ["use_scale"] = false,
        ["use_translate"] = false,
        ["x"] = 0,
        ["y"] = 0,
      },
      ["start"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "shrink",
        ["type"] = "none",
      },
    },
    ["blendMode"] = "BLEND",
    ["color"] = {
      [1] = 0,
      [2] = 0,
      [3] = 0,
      [4] = 0.75,
    },
    ["conditions"] = {
      [1] = {
        ["changes"] = {
          [1] = {
            ["property"] = "color",
            ["value"] = {
              [1] = 0.7843137254902,
              [2] = 0.16470588235294,
              [3] = 0.13333333333333,
              [4] = 0.75395312905312,
            },
          },
        },
        ["check"] = {
          ["checks"] = {
          },
          ["trigger"] = -1,
          ["value"] = 1,
          ["variable"] = "attackabletarget",
        },
      },
      [2] = {
        ["changes"] = {
          [1] = {
            ["property"] = "color",
            ["value"] = {
              [1] = 0,
              [2] = 0.7843137254902,
              [3] = 0,
              [4] = 0.75395312905312,
            },
          },
        },
        ["check"] = {
          ["trigger"] = -1,
          ["value"] = 0,
          ["variable"] = "attackabletarget",
        },
      },
    },
    ["frameStrata"] = 4,
    ["height"] = 35,
    ["id"] = "Target",
    ["information"] = {
      ["forceEvents"] = true,
      ["ignoreOptionsEventErrors"] = true,
    },
    ["load"] = {
      ["class"] = {
        ["multi"] = {
        },
      },
      ["size"] = {
        ["multi"] = {
        },
      },
      ["spec"] = {
        ["multi"] = {
        },
      },
      ["talent"] = {
        ["multi"] = {
        },
      },
      ["use_combat"] = false,
      ["zoneIds"] = "",
    },
    ["parent"] = "The Terminator",
    ["regionType"] = "texture",
    ["rotation"] = 0,
    ["selfPoint"] = "CENTER",
    ["texture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura105",
    ["textureWrapMode"] = "CLAMP",
    ["triggers"] = {
      [1] = {
        ["trigger"] = {
          ["buffShowOn"] = "showOnActive",
          ["check"] = "event",
          ["custom_hide"] = "timed",
          ["custom_type"] = "event",
          ["debuffType"] = "HELPFUL",
          ["duration"] = "1",
          ["event"] = "Unit Characteristics",
          ["names"] = {
          },
          ["spellIds"] = {
          },
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
          ["type"] = "unit",
          ["unevent"] = "auto",
          ["unit"] = "target",
          ["use_alwaystrue"] = true,
          ["use_unit"] = true,
        },
        ["untrigger"] = {
          ["unit"] = "target",
        },
      },
      ["activeTriggerMode"] = -10,
      ["disjunctive"] = "all",
    },
    ["uid"] = "Lrz8sZnB77M",
    ["width"] = 35,
    ["xOffset"] = 0,
    ["yOffset"] = 0,
  },
  ["Target Range"] = {
    ["actions"] = {
      ["finish"] = {
      },
      ["init"] = {
        ["custom"] = "",
        ["do_custom"] = false,
      },
      ["start"] = {
      },
    },
    ["alpha"] = 1,
    ["anchorFrameParent"] = true,
    ["anchorFrameType"] = "SCREEN",
    ["anchorPoint"] = "CENTER",
    ["animation"] = {
      ["finish"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "fade",
        ["type"] = "preset",
      },
      ["main"] = {
        ["alpha"] = 0.5,
        ["alphaType"] = "alphaPulse",
        ["colorA"] = 1,
        ["colorB"] = 0,
        ["colorG"] = 0,
        ["colorR"] = 0,
        ["colorType"] = "pulseHSV",
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "alphaPulse",
        ["rotate"] = 0,
        ["scaleType"] = "pulse",
        ["scalex"] = 1.2,
        ["scaley"] = 1.2,
        ["translateType"] = "straightTranslate",
        ["type"] = "none",
        ["use_alpha"] = false,
        ["use_color"] = false,
        ["use_scale"] = false,
        ["use_translate"] = false,
        ["x"] = 0,
        ["y"] = 0,
      },
      ["start"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["preset"] = "shrink",
        ["type"] = "preset",
        ["use_scale"] = false,
      },
    },
    ["backgroundColor"] = {
      [1] = 0.5,
      [2] = 0.5,
      [3] = 0.5,
      [4] = 0.5,
    },
    ["backgroundTexture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura3",
    ["blendMode"] = "BLEND",
    ["color"] = {
      [1] = 1,
      [2] = 0,
      [3] = 0.007843137254902,
      [4] = 1,
    },
    ["compress"] = false,
    ["conditions"] = {
      [1] = {
        ["changes"] = {
          [1] = {
            ["property"] = "color",
            ["value"] = {
              [1] = 1,
              [2] = 1,
              [3] = 1,
              [4] = 0,
            },
          },
        },
        ["check"] = {
          ["checks"] = {
            [1] = {
              ["trigger"] = 1,
              ["value"] = 1,
              ["variable"] = "show",
            },
            [2] = {
              ["trigger"] = 2,
              ["value"] = 0,
              ["variable"] = "show",
            },
          },
          ["trigger"] = -2,
          ["variable"] = "AND",
        },
      },
    },
    ["crop_x"] = 0.41,
    ["crop_y"] = 0.41,
    ["foregroundColor"] = {
      [1] = 1,
      [2] = 1,
      [3] = 1,
      [4] = 1,
    },
    ["foregroundTexture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura3",
    ["frameStrata"] = 9,
    ["height"] = 26,
    ["id"] = "Target Range",
    ["information"] = {
      ["forceEvents"] = true,
      ["ignoreOptionsEventErrors"] = true,
    },
    ["inverse"] = false,
    ["load"] = {
      ["class"] = {
        ["multi"] = {
        },
        ["single"] = "HUNTER",
      },
      ["size"] = {
        ["multi"] = {
        },
      },
      ["spec"] = {
        ["multi"] = {
        },
      },
      ["spellknown"] = 2974,
      ["talent"] = {
        ["multi"] = {
        },
      },
      ["use_class"] = true,
      ["use_level"] = false,
      ["use_never"] = false,
      ["use_spellknown"] = false,
      ["zoneIds"] = "",
    },
    ["orientation"] = "VERTICAL",
    ["parent"] = "The Terminator",
    ["regionType"] = "texture",
    ["rotation"] = 0,
    ["sameTexture"] = true,
    ["selfPoint"] = "CENTER",
    ["texture"] = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\Aura104",
    ["textureWrapMode"] = "CLAMP",
    ["triggers"] = {
      [1] = {
        ["trigger"] = {
          ["check"] = "update",
          ["custom"] = "function()    \
    if UnitExists(\"target\") and UnitIsVisible(\"target\") and UnitCanAttack(\"player\", \"target\") and (not UnitIsDead(\"target\")) then\
        return true\
    else \
        return false\
    end\
end",
          ["custom_hide"] = "timed",
          ["custom_type"] = "status",
          ["debuffType"] = "HELPFUL",
          ["event"] = "Health",
          ["names"] = {
          },
          ["spellIds"] = {
          },
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
          ["type"] = "custom",
          ["unit"] = "player",
          ["use_alwaystrue"] = true,
        },
        ["untrigger"] = {
        },
      },
      [2] = {
        ["trigger"] = {
          ["check"] = "update",
          ["custom"] = "function()\
    local unit = \"target\"\
    if UnitExists(unit) and UnitIsVisible(unit) and UnitCanAttack(\"player\", unit) and not UnitIsDead(unit) then\
        local result\
        if IsSpellInRange then\
            result = IsSpellInRange(\"Auto Shot\", unit)\
        end\
        if result == nil and C_Spell and C_Spell.IsSpellInRange then\
            result = C_Spell.IsSpellInRange(75, unit)\
        end\
        return result == 1 or result == true\
    end\
    return false\
end\
\
\
",
          ["custom_type"] = "status",
          ["debuffType"] = "HELPFUL",
          ["type"] = "custom",
          ["unit"] = "player",
        },
        ["untrigger"] = {
        },
      },
      ["activeTriggerMode"] = 1,
      ["disjunctive"] = "any",
    },
    ["uid"] = "N0iDxOl()NU",
    ["url"] = "https://wago.io/jxJdu2yc6/1",
    ["user_x"] = 0,
    ["user_y"] = 0,
    ["width"] = 25,
    ["xOffset"] = 0,
    ["yOffset"] = 1,
  },
  ["The Terminator"] = {
    ["actions"] = {
      ["finish"] = {
      },
      ["init"] = {
      },
      ["start"] = {
      },
    },
    ["alpha"] = 1,
    ["anchorFrameType"] = "SCREEN",
    ["anchorPoint"] = "CENTER",
    ["animation"] = {
      ["finish"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["type"] = "none",
      },
      ["main"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["type"] = "none",
      },
      ["start"] = {
        ["duration_type"] = "seconds",
        ["easeStrength"] = 3,
        ["easeType"] = "none",
        ["type"] = "none",
      },
    },
    ["conditions"] = {
    },
    ["controlledChildren"] = {
      [1] = "Pet Tracker",
      [2] = "No Combat",
      [3] = "Combat",
      [4] = "Target",
      [5] = "Cursor GCD ",
      [6] = "Low Mana",
      [7] = "Low Health",
      [8] = "Execute",
      [9] = "Mouseover Glow",
      [10] = "Mouseover Dot",
      [11] = "Target Range",
    },
    ["frameStrata"] = 1,
    ["id"] = "The Terminator",
    ["information"] = {
      ["forceEvents"] = true,
      ["groupOffset"] = true,
      ["ignoreOptionsEventErrors"] = true,
    },
    ["load"] = {
      ["affixes"] = {
        ["multi"] = {
        },
      },
      ["class"] = {
        ["multi"] = {
        },
      },
      ["class_and_spec"] = {
        ["multi"] = {
        },
      },
      ["difficulty"] = {
        ["multi"] = {
        },
      },
      ["faction"] = {
        ["multi"] = {
        },
      },
      ["ingroup"] = {
        ["multi"] = {
        },
      },
      ["pvptalent"] = {
        ["multi"] = {
        },
      },
      ["race"] = {
        ["multi"] = {
        },
      },
      ["role"] = {
        ["multi"] = {
        },
      },
      ["size"] = {
        ["multi"] = {
        },
      },
      ["spec"] = {
        ["multi"] = {
        },
      },
      ["talent"] = {
        ["multi"] = {
        },
      },
      ["talent2"] = {
        ["multi"] = {
        },
      },
      ["talent3"] = {
        ["multi"] = {
        },
      },
      ["zoneIds"] = "",
    },
    ["regionType"] = "group",
    ["scale"] = 1,
    ["selfPoint"] = "BOTTOMLEFT",
    ["triggers"] = {
      [1] = {
        ["trigger"] = {
          ["buffShowOn"] = "showOnActive",
          ["debuffType"] = "HELPFUL",
          ["event"] = "Conditions",
          ["names"] = {
          },
          ["spellIds"] = {
          },
          ["subeventPrefix"] = "SPELL",
          ["subeventSuffix"] = "_CAST_START",
          ["type"] = "unit",
          ["unit"] = "player",
          ["use_alwaystrue"] = false,
        },
        ["untrigger"] = {
        },
      },
      ["activeTriggerMode"] = 1,
    },
    ["uid"] = "MwjIft7G5vi",
    ["xOffset"] = 0,
    ["yOffset"] = 0,
  },
}
