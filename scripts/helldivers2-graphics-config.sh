#!/usr/bin/env bash
# Helldivers 2 Optimal Stability/Performance Graphics Config
# Prioritizes: frametime stability, no stutter, max FPS
# Sacrifices: visual quality, effects, resolution

set -euo pipefail

CONFIG_DIR="$HOME/.local/share/Steam/steamapps/compatdata/553850/pfx/drive_c/users/steamuser/AppData/Local/Helldivers2/Saved/Config/Windows"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/GameUserSettings.ini" << 'INI'
[/Script/Engine.GameUserSettings]
; Resolution - Use native or lower for performance
ResolutionSizeX=1920
ResolutionSizeY=1080
LastUserConfirmedResolutionSizeX=1920
LastUserConfirmedResolutionSizeY=1080
FullscreenMode=1  ; Fullscreen exclusive (best for GameGuard)
PreferredFullscreenMode=1

; Frame Rate - Uncapped with sync
FrameRateLimit=0.000000
bUseFrameRateLimit=False
VSync=0  ; Disable VSync for lowest latency

; Quality Presets - LOWEST for maximum performance
GraphicsQuality=0
LastConfirmedGraphicsQuality=0

; Scalability Groups - ALL MINIMUM
sg.ResolutionQuality=50          ; 50% render resolution (DLSS/FSR will upscale)
sg.ViewDistanceQuality=0         ; Minimum view distance
sg.AntiAliasingQuality=0         ; No AA (use DLSS/FSR instead)
sg.ShadowQuality=0               ; No shadows
sg.PostProcessQuality=0          ; No post-processing
sg.TextureQuality=0              ; Lowest textures
sg.EffectsQuality=0              ; No particle effects
sg.FoliageQuality=0              ; No foliage
sg.ShadingQuality=0              ; Simplest shading

; Advanced
bUseNanite=False                 ; Disable Nanite
bUseLumen=False                  ; Disable Lumen GI
bUseVirtualShadowMaps=False      ; Disable virtual shadows
bUseTemporalUpsampling=False     ; Use FSR/DLSS instead
bUseTAA=False                    ; No TAA
bUseFXAA=False                   ; No FXAA
bUseDepthOfField=False           ; No DOF
bUseMotionBlur=False             ; No motion blur
bUseBloom=False                  ; No bloom
bUseAmbientOcclusion=False       ; No AO
bUseScreenSpaceReflections=False ; No SSR
bUseRayTracing=False             ; No RTX

; NVIDIA Reflex
NVIDIAReflexMode=2               ; Enabled + Boost (if supported)

; Input
MouseSensitivity=0.5
MouseSmoothing=0
bInvertMouse=False

; Audio
MasterVolume=1.0
MusicVolume=0.5
SFXVolume=1.0
VoiceVolume=0.8

; Network (for GameGuard/Steam)
NetServerMaxTickRate=64
NetClientMaxTickRate=64

INI

cat > "$CONFIG_DIR/Engine.ini" << 'INI'
[SystemSettings]
; Rendering - Minimum for stability
r.DefaultFeature.AntiAliasing=0
r.DefaultFeature.Bloom=0
r.DefaultFeature.AmbientOcclusion=0
r.DefaultFeature.AutoExposure=0
r.DefaultFeature.MotionBlur=0
r.DefaultFeature.LensFlare=0

r.DepthOfFieldQuality=0
r.MotionBlurQuality=0
r.AmbientOcclusionQuality=0
r.BloomQuality=0
r.LensFlareQuality=0
r.TonemapperQuality=0
r.LightFunctionQuality=0
r.ShadowQuality=0
r.Shadow.CSM.MaxCascades=0
r.Shadow.MaxResolution=0
r.Shadow.RadiusThreshold=0.01

r.SSR.Quality=0
r.SSR.MaxRoughness=0
r.ReflectionQuality=0

r.FoliageQuality=0
r.GrassQuality=0
r.TranslucencyQuality=0

; Texture Streaming - Minimal
r.Streaming.PoolSize=512
r.Streaming.MaxTempMemoryAllowed=128
r.Streaming.LowResMipTailSize=1
r.TextureStreaming=0

; Particle/Effects
r.ParticleLODBias=2
fx.MaxCPUParticlesPerEmitter=0
fx.MaxGPUParticlesSpawnedPerFrame=0

; FSR/DLSS Upscaling
r.Upscale.Quality=2          ; Quality mode (balance)
r.FSR.Enabled=1
r.DLSS.Enabled=1

; Stability
r.GPUCrashDebugging=0
r.D3D12.DisableDriverTimeout=1
d3d12.FastMath=1

[/Script/Engine.RendererSettings]
r.DefaultFeature.AutoExposure=0
r.DepthOfFieldQuality=0
r.MotionBlurQuality=0
r.AmbientOcclusionQuality=0
r.BloomQuality=0

[/Script/HardwareTargeting.HardwareTargetingSettings]
TargetedHardwareClass=Desktop
AppliedTargetedHardwareClass=Desktop
DefaultGraphicsPerformance=Minimum
AppliedDefaultGraphicsPerformance=Minimum

INI

cat > "$CONFIG_DIR/Scalability.ini" << 'INI'
[ScalabilityGroups]
sg.ResolutionQuality=50
sg.ViewDistanceQuality=0
sg.AntiAliasingQuality=0
sg.ShadowQuality=0
sg.PostProcessQuality=0
sg.TextureQuality=0
sg.EffectsQuality=0
sg.FoliageQuality=0
sg.ShadingQuality=0

INI

echo "✅ Graphics configs written to:"
echo "  $CONFIG_DIR/GameUserSettings.ini"
echo "  $CONFIG_DIR/Engine.ini"
echo "  $CONFIG_DIR/Scalability.ini"
echo ""
echo "Settings applied:"
echo "  - 50% render resolution (FSR/DLSS will upscale)"
echo "  - ALL quality settings = 0 (minimum)"
echo "  - No shadows, no AA, no post-processing"
echo "  - No motion blur, bloom, DOF, AO, SSR"
echo "  - Fullscreen exclusive mode"
echo "  - VSync OFF, Frame limit OFF"
echo "  - FSR/DLSS Quality mode enabled"
