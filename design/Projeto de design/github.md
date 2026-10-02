repo: mfmansueli/CueStudio
branch: main

## Last sync
date: 2026-10-02T11:27:07Z
### Updated in this project
- Cue App v12 criado a partir da v11 e alinhado ao app real
- Tab bar real (Scripts · Takes · Record · Profile · Settings) e telas Settings, Language & Region, Creator Setup, Remote Control, Acknowledgements
- Selfie com pills de microfone e setup, card de recomendação, sheets Audio Input e This take
- Profile com "Creator preferences" e copy do plano do app

## Screen map
| Tela | Arquivos no repo |
|---|---|
| Tab bar | Cue Studio/Screens/Main/MainView.swift |
| Settings | Cue Studio/Screens/Settings/SettingsView.swift |
| Language & Region | Cue Studio/Screens/Settings/LanguageRegion/LanguageRegionView.swift |
| Creator Setup | Cue Studio/Screens/CreatorSetup/CreatorSetupView.swift, Sections/*, Rows/SetupRow.swift |
| Remote Control | Cue Studio/Screens/RemoteControl/RemoteControlView.swift, Screens/Shared/RemoteControl/RemotePairingPanel.swift |
| Selfie (barra) | Cue Studio/Screens/Prompter/Selfie/SelfieControlPanel.swift, Controls/AudioInputPill.swift, Controls/SetupSummaryPill.swift, Controls/SetupRecommendationCard.swift |
| Audio Input / This take | Cue Studio/Screens/Prompter/Sheets/AudioInputSheet.swift, RecordingSetupSheet.swift |
| Profile | Cue Studio/Screens/Profile/ProfileView.swift, Sections/PlanSection.swift |
| Tokens | Cue Studio/DesignSystem/Tokens/Palette.swift, Metrics.swift, DESIGN_PROJECT.md |
