/**
 * BSD 2-Clause License
 *
 * Copyright (c) 2022, tuokri / fluudah
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *
 * Periodically checks gamma and brightness and force clamps them to a certain range.
 * https://github.com/tuokri/rs2-gamma-guard
 * https://steamcommunity.com/sharedfiles/filedetails/?id=2901881626
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *
 * Thanks to Eliot van Uytfanghe for the gamma value reading idea, and for all of his
 * work on UE3 and UnrealScript tools. See the below link for more information.
 * https://eliotvu.com/blog/38/reading-and-writing-the-gamma-display-setting-in-udk
 *
 */
class GammaGuard_V1 extends Actor
    placeable;

var(GammaGuard) private float MinGamma<
Tooltip="Minimum allowed gamma. Valid gamma range could be around [0.5-2.0] depending on the map. Must be less than MaxGamma."|UIMin=0.0|UIMax=10.0>;
var(GammaGuard) private float MaxGamma<
Tooltip="Maximum allowed gamma. Valid gamma range could be around [0.5-2.0] depending on the map. Must be greater than MinGamma."|UIMin=0.0|UIMax=10.0>;

var(GammaGuard) private float MinBrightness<
Tooltip="Minimum allowed brightness. Valid brightness range could be around [0.5-1.5] depending on the map. Must be less than MaxBrightness."|UIMin=0.0|UIMax=10.0>;
var(GammaGuard) private float MaxBrightness<
Tooltip="Maximum allowed brightness. Valid brightness range could be around [0.5-1.5] depending on the map. Must be greater than MinBrightness."|UIMin=0.0|UIMax=10.0>;

// Last gamma value read from client settings.
var() private editconst float CurrentGamma;
// Last brightness value read from client settings.
var() private editconst float CurrentBrightness;

// Cached UI object reference.
var() private editconst ROUISceneSettings SettingsScene;
// Cached UI object reference.
var() private editconst GameUISceneClient GameSceneClient;

// Whether we are loading values from the real settings scene or a
// purposefully create fake temporary scene. For internal logic only.
var() private bool bUsingFakeSettingsScene;

// Time between server side checks in seconds.
// The server sends a request to every player client every
// interval defined by this value. Verifies that clients
// have their gamma and brightness check timers enabled.
// Clients should never be able to disable them so this is
// just an extra safety check. Can be kept relatively high.
// Default is 10 seconds.
var(GammaGuardAdvanced) private float ServerSideCheckInterval;
// Time between client side gamma checks in seconds.
// Can be kept relatively low due to the cheapness of the check.
// Default is 0.5 seconds.
var(GammaGuardAdvanced) private float ClientSideGammaCheckInterval;
// Time between client side brightness checks in seconds.
// Should be kept relatively high as it introduces some log
// spam. Around 10 seconds or more should be safe.
var(GammaGuardAdvanced) private float ClientSideBrightnessCheckInterval;

// Reserved for future API-breaking changes. Currently unused.
var(GammaGuardAdvanced) private int ConfigVersion;

const FALLBACK_GAMMA_MIN = 0.0;
const FALLBACK_GAMMA_MAX = 10.0;
const FALLBACK_BRIGHTNESS_MIN = 0.0;
const FALLBACK_BRIGHTNESS_MAX = 10.0;

simulated event PostBeginPlay()
{
    super.PostBeginPlay();

    switch (WorldInfo.NetMode)
    {
        case NM_DedicatedServer:
            SetTimer(ServerSideCheckInterval, True, 'CheckClients');
            break;
        case NM_Standalone:
            SetTimer(ClientSideGammaCheckInterval, True, 'CheckGamma');
            SetTimer(ClientSideBrightnessCheckInterval, True, 'CheckBrightness');
            break;
        case NM_Client:
            SetTimer(ClientSideGammaCheckInterval, True, 'CheckGamma');
            SetTimer(ClientSideBrightnessCheckInterval, True, 'CheckBrightness');
            break;
        default:
            SetTimer(ServerSideCheckInterval, True, 'CheckClients');
            SetTimer(ClientSideGammaCheckInterval, True, 'CheckGamma');
            SetTimer(ClientSideBrightnessCheckInterval, True, 'CheckBrightness');
    }

    `gglog(self @ "initialized, NetMode:" @ WorldInfo.NetMode);

    ValidateRanges();
}

final private function ValidateRanges()
{
    if (MinGamma > MaxGamma)
    {
        `gglog("WARNING: MinGamma is greater than MaxGamma:"
            @ MinGamma @ ">" @ MaxGamma @ "reverting to fallback values!");

        MinGamma = FALLBACK_GAMMA_MIN;
        MaxGamma = FALLBACK_GAMMA_MAX;
    }

    if (MinBrightness > MaxBrightness)
    {
        `gglog("WARNING: MinBrightness is greater than MaxBrightness:"
            @ MinBrightness @ ">" @ MaxBrightness @ "reverting to fallback values!");

        MinBrightness = FALLBACK_BRIGHTNESS_MIN;
        MaxBrightness = FALLBACK_BRIGHTNESS_MAX;
    }
}

// Call in server-side timer to nag to clients in case they
// somehow manage to get the timer deactivated.
final private function CheckClients()
{
    `gglog("telling clients to check their timers");
    ClientCheckTimerIsActive();
}

final private reliable client function ClientCheckTimerIsActive()
{
    `gglog("got request from server to check timers");

    if (!IsTimerActive('CheckGamma'))
    {
        `gglog("CheckGamma not active");
        SetTimer(ClientSideGammaCheckInterval, True, 'CheckGamma');
    }

    if (!IsTimerActive('CheckBrightness'))
    {
        `gglog("CheckBrightness not active");
        SetTimer(ClientSideBrightnessCheckInterval, True, 'CheckBrightness');
    }
}

final private simulated function float GetGamma()
{
    return class'Engine'.static.GetEngine().Client.DisplayGamma;
}

final private simulated function SetGamma(float NewGamma)
{
    `gglog("NewGamma:" @ NewGamma);

    ConsoleCommand("Gamma" @ NewGamma);
    class'Engine'.static.GetEngine().Client.DisplayGamma = NewGamma;
}

final private simulated function bool GetBrightness()
{
    if (SettingsScene != None)
    {
        // Always get brightness from fake scene.
        if (bUsingFakeSettingsScene)
        {
            SettingsScene.GetGFXSettings();
            CurrentBrightness = SettingsScene.CurrentGFXSettings.Brightness;
            return True;
        }
    }

    if (GameSceneClient == None)
    {
        GameSceneClient = class'UIRoot'.static.GetSceneClient();
        // `gglog("GameSceneClient:" @ GameSceneClient);
    }

    /* TODO: only use real scene when setting new values.
    if (GameSceneClient != None && bUsingFakeSettingsScene)
    {
        // Try to find directly with scene tag. Only works if the settings menu is currently open.
        SettingsScene = ROUISceneSettings(GameSceneClient.FindSceneByTag('ROUIScene_Settings'));
        if (SettingsScene != None)
        {
            // `gglog("found by tag:");
            // `gglog("SettingsScene.Name:" @ SettingsScene.Name);
            // `gglog("SettingsScene.SceneTag:" @ SettingsScene.SceneTag);
            CurrentBrightness = SettingsScene.CurrentGFXSettings.Brightness;
            bUsingFakeSettingsScene = False;
            return True;
        }

        // Search active scenes. Only works if the settings menu is currently open.
        ForEach GameSceneClient.AllActiveScenes(class'ROUISceneSettings', SettingsScene)
        {
            // `gglog("found with iterator:");
            // `gglog("SettingsScene.Name:" @ SettingsScene.Name);
            // `gglog("SettingsScene.SceneTag:" @ SettingsScene.SceneTag);
            CurrentBrightness = SettingsScene.CurrentGFXSettings.Brightness;
            bUsingFakeSettingsScene = False;
            return True;
        }
    }
    */

    if (SettingsScene == None && GameSceneClient != None)
    {
        SettingsScene = GameSceneClient.CreateScene(class'ROUISceneSettings');
        SettingsScene.GetGFXSettings();
        CurrentBrightness = SettingsScene.CurrentGFXSettings.Brightness;
        bUsingFakeSettingsScene = True;
        return True;
    }

    CurrentBrightness = 1.0;
    return False;
}

final private simulated function SetBrightness(float NewBrightness)
{
    `gglog("NewBrightness:" @ NewBrightness);

    ConsoleCommand("Brightness" @ NewBrightness);
    if (SettingsScene != None)
    {
        SettingsScene.CurrentGFXSettings.Brightness = NewBrightness;
        SettingsScene.NewGFXSettings.Brightness = NewBrightness;
        SettingsScene.SetGFXSettings(False);
    }
}

final private simulated function CheckBrightness()
{
    if (GetBrightness())
    {
        // `gglog("CurrentBrightness:" @ CurrentBrightness);

        if (CurrentBrightness < MinBrightness)
        {
            SetBrightness(MinBrightness);
        }
        else if (CurrentBrightness > MaxBrightness)
        {
            SetBrightness(MaxBrightness);
        }
    }
}

final private simulated function CheckGamma()
{
    CurrentGamma = GetGamma();

    // `gglog("CurrentGamma:" @ CurrentGamma);

    if (CurrentGamma < MinGamma)
    {
        SetGamma(MinGamma);
    }
    else if (CurrentGamma > MaxGamma)
    {
        SetGamma(MaxGamma);
    }
}

DefaultProperties
{
    Begin Object Class=SpriteComponent Name=Sprite
        Sprite=Texture2D'EditorResources.ChaosZoneInfo'
        HiddenGame=True
        AlwaysLoadOnClient=False
        AlwaysLoadOnServer=False
    End Object
    Components.Add(Sprite)

    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=100
    bHidden=True
    bOnlyDirtyReplication=True
    bAlwaysRelevant=True
    bSkipActorPropertyReplication=True
    bAlwaysTick=True

    MinGamma=0.0
    MaxGamma=10.0
    MinBrightness=0.0
    MaxBrightness=10.0

    bUsingFakeSettingsScene=False

    ServerSideCheckInterval=10.0
    ClientSideGammaCheckInterval=0.5
    ClientSideBrightnessCheckInterval=10.0

    ConfigVersion=`GAMMA_GUARD_V1_CFG_VERSION
}
