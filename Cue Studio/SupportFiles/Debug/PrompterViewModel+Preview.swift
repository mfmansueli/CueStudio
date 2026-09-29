//
//  PrompterViewModel+Preview.swift
//  Cue Studio
//

#if DEBUG
import Foundation

extension PrompterViewModel {
    /// A prompter on the preview services. Previews also inject its `session` into the environment.
    static func preview(scriptID: UUID? = SampleScripts.morningHabits.id, mode: PrompterMode = .selfie) -> PrompterViewModel {
        let services = AppServices.preview
        return PrompterViewModel(
            launch: PrompterLaunch(scriptID: scriptID, mode: mode),
            library: services.library, takes: services.takes,
            preferences: services.preferences, profile: services.profile, rules: services.rules,
            camera: services.camera, audio: services.audio, microphones: services.audio,
            speech: services.speech, remote: services.remote, toast: services.toast
        )
    }
}
#endif
