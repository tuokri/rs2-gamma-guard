// Periodically checks gamma and brightness and force clamps them to a certain range.
// https://eliotvu.com/blog/38/reading-and-writing-the-gamma-display-setting-in-udk
class GammaGuard_V1 extends Actor
    placeable;

var(GammaGuard) private float MinGamma<Tooltip="Minimum allowed gamma. Should be less than MaxGamma."|UIMin=0.0|UIMax=10.0>;
var(GammaGuard) private float MaxGamma<Tooltip="Maximum allowed gamma. Should be greater than MinGamma."|UIMin=0.0|UIMax=10.0>;

var(GammaGuard) private float MinBrightness<Tooltip="Minimum allowed brightness. Should be less than MaxBrightness."|UIMin=0.0|UIMax=10.0>;
var(GammaGuard) private float MaxBrightness<Tooltip="Maximum allowed brightness. Should be greater than MinBrightness."|UIMin=0.0|UIMax=10.0>;

var private float CurrentGamma;
var private float CurrentBrightness;

// Cached UI object references.
var private ROUISceneSettings SettingsScene;
var private GameUISceneClient GameSceneClient;
var private GFXSettings CurrentGFXSettings;

simulated event PostBeginPlay()
{
    super.PostBeginPlay();

    `gglog("NetMode:" @ WorldInfo.NetMode);

    switch (WorldInfo.NetMode)
    {
        case NM_DedicatedServer:
            SetTimer(1.0, True, 'CheckClients');
            break;
        case NM_Standalone:
            SetTimer(0.5, True, 'CheckGamma');
            break;
        case NM_Client:
            SetTimer(0.5, True, 'CheckGamma');
            break;
        default:
            SetTimer(1.0, True, 'CheckClients');
            SetTimer(0.5, True, 'CheckGamma');
    }
}

// Call in server-side timer to nag to clients in case they
// somehow manage to get the timer deactivated.
final private function CheckClients()
{
    `gglog("");
    ClientCheckTimerIsActive();
}

final private reliable client function ClientCheckTimerIsActive()
{
    `gglog("");
    if (!IsTimerActive('CheckGamma'))
    {
        `gglog("CheckGamma not active");
        SetTimer(0.5, True, 'CheckGamma');
    }
}

final private simulated function float GetGamma()
{
    return class'Engine'.static.GetEngine().Client.DisplayGamma;
}

final private simulated function SetGamma(float NewGamma)
{
    ConsoleCommand("Gamma" @ NewGamma);
    class'Engine'.static.GetEngine().Client.DisplayGamma = NewGamma;
}

final private simulated function bool GetBrightness(out float Brightness)
{
    if (SettingsScene != None)
    {
        `gglog("using existing" @ SettingsScene);
        Brightness = SettingsScene.CurrentGFXSettings.Brightness;
        return True;
    }

    if (GameSceneClient == None)
    {
        GameSceneClient = class'UIRoot'.static.GetSceneClient();
        `gglog("GameSceneClient:" @ GameSceneClient);
    }

    `gglog("Found ROUIScene_Settings   :" @ FindObject("ROUIScene_Settings", class'ROUISceneSettings'));
    `gglog("Found ROUIScene_Settings_0 :" @ FindObject("ROUIScene_Settings_0", class'ROUISceneSettings'));
    `gglog("Found ROUISceneSettings    :" @ FindObject("ROUISceneSettings_0", class'ROUISceneSettings'));
    `gglog("Found ROUISceneSettings_0  :" @ FindObject("ROUISceneSettings", class'ROUISceneSettings'));
    `gglog("Found Transient.ROUISceneSettings   :" @ FindObject("Transient.ROUISceneSettings", class'ROUISceneSettings'));
    `gglog("Found Transient.ROUISceneSettings_0 :" @ FindObject("Transient.ROUISceneSettings_0", class'ROUISceneSettings'));
    `gglog("Found ROGame.ROUISceneSettings   :" @ FindObject("ROGame.ROUISceneSettings", class'ROUISceneSettings'));
    `gglog("Found ROGame.ROUISceneSettings_0 :" @ FindObject("ROGame.ROUISceneSettings_0", class'ROUISceneSettings'));

    `gglog("DynLoad ROGame.ROUISceneSettings :" @ ROUISceneSettings(DynamicLoadObject("ROGame.ROUISceneSettings", class'ROUISceneSettings', True)));

    if (GameSceneClient != None)
    {
        // Try to find directly with scene tag. Only works if the settings menu is currently open.
        SettingsScene = ROUISceneSettings(GameSceneClient.FindSceneByTag('ROUIScene_Settings'));
        if (SettingsScene != None)
        {
            `gglog("found by tag:");
            `gglog("SettingsScene:" @ SettingsScene);
            `gglog("SettingsScene.SceneTag:" @ SettingsScene.SceneTag);
            Brightness = SettingsScene.CurrentGFXSettings.Brightness;
            return True;
        }

        // Search active scenes. Only works if the settings menu is currently open.
        ForEach GameSceneClient.AllActiveScenes(class'ROUISceneSettings', SettingsScene)
        {
            `gglog("found with iterator:");
            `gglog("SettingsScene:" @ SettingsScene);
            `gglog("SettingsScene.SceneTag:" @ SettingsScene.SceneTag);
            Brightness = SettingsScene.CurrentGFXSettings.Brightness;
            return True;
        }
    }

    Brightness = -1.0;
    return False;
}

final private simulated function SetBrightness(float NewBrightness)
{
    // TODO: check ROUISceneSettings::OnBrightnessSliderChanged for proper scaling.
    ConsoleCommand("Brightness" @ NewBrightness);
    if (SettingsScene != None)
    {
        SettingsScene.CurrentGFXSettings.Brightness = NewBrightness;
        CurrentGFXSettings = SettingsScene.CurrentGFXSettings;
        CurrentGFXSettings.Brightness = NewBrightness;
        SettingsScene.NewGFXSettings = CurrentGFXSettings;
        SettingsScene.SetGFXSettings(False);
    }
}

final private simulated function CheckGamma()
{
    CurrentGamma = GetGamma();

    `gglog("CurrentGamma:" @ CurrentGamma);

    if (CurrentGamma < MinGamma)
    {
        SetGamma(MinGamma);
    }
    else if (CurrentGamma > MaxGamma)
    {
        SetGamma(MaxGamma);
    }

    if (GetBrightness(CurrentBrightness))
    {
        `gglog("CurrentBrightness:" @ CurrentBrightness);

        if (CurrentBrightness < MinBrightness)
        {
            SetBrightness(MinBrightness);
        }
        else if (CurrentBrightness > MinBrightness)
        {
            SetBrightness(MaxBrightness);
        }
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
}
