// Periodically checks gamma and force clamps it to a certain range.
class GammaGuard_V1 extends Actor
    placeable;

var(GammaGuard) private float MinGamma<Tooltip="Minimum allowed gamma. Should be less than MaxGamma."|UIMin=0.0|UIMax=10.0>;
var(GammaGuard) private float MaxGamma<Tooltip="Maximum allowed gamma. Should be greater than MinGamma."|UIMin=0.0|UIMax=10.0>;

var private float CurrentGamma;

simulated event PostBeginPlay()
{
    super.PostBeginPlay();

    switch (WorldInfo.NetMode)
    {
        case NM_DedicatedServer:
            break;
        case NM_Standalone:
            SetTimer(0.5, True, 'CheckGamma');
            break;
        case NM_Client:
            SetTimer(0.5, True, 'CheckGamma');
            break;
        default:
            SetTimer(0.5, True, 'CheckGamma');
    }
}

final private simulated function float GetGamma()
{
    return class'Client'.default.DisplayGamma;
}

final private simulated function SetGamma(float NewGamma)
{
    ConsoleCommand("Gamma" @ NewGamma);

    class'Client'.default.DisplayGamma = newGamma;
    class'Client'.static.StaticSaveConfig();
}

final private simulated function CheckGamma()
{
    CurrentGamma = GetGamma();

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
