// Periodically checks gamma and force clamps it to a certain range.
// https://eliotvu.com/blog/38/reading-and-writing-the-gamma-display-setting-in-udk
class GammaGuard_V1 extends Actor
    placeable;

var(GammaGuard) private float MinGamma<Tooltip="Minimum allowed gamma. Should be less than MaxGamma."|UIMin=0.0|UIMax=10.0>;
var(GammaGuard) private float MaxGamma<Tooltip="Maximum allowed gamma. Should be greater than MinGamma."|UIMin=0.0|UIMax=10.0>;

var(GammaGuard) private float MinBrightness<Tooltip="Minimum allowed brightness. Should be less than MinBrightness."|UIMin=0.0|UIMax=10.0>;
var(GammaGuard) private float MaxBrightness<Tooltip="Maximum allowed brightness. Should be greater than MaxBrightness."|UIMin=0.0|UIMax=10.0>;

var private float CurrentGamma;
var private float CurrentBrightness;

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

final private function CheckClients()
{
    `gglog("");
    CheckClientLoop();
}

final private reliable client function CheckClientLoop()
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
    // return class'Client'.default.DisplayGamma;
    return class'Engine'.static.GetEngine().Client.DisplayGamma;
}

final private simulated function SetGamma(float NewGamma)
{
    ConsoleCommand("Gamma" @ NewGamma);

    // class'Client'.default.DisplayGamma = NewGamma;
    // class'Client'.static.StaticSaveConfig();

    class'Engine'.static.GetEngine().Client.DisplayGamma = NewGamma;
}

final private simulated function float GetBrightness()
{
    // TODO: get CurrentGFXSettings.
}

final private simulated function SetBrightness(float NewBrightness)
{
    // TODO: check ROUISceneSettings::OnBrightnessSliderChanged for proper scaling.
    ConsoleCommand("Brightness" @ NewBrightness);
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
}
