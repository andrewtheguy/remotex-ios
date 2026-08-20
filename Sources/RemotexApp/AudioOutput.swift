import AVFoundation

/// The one thing the wrapper has to do for the desktop's sound.
///
/// remotex plays its audio through Web Audio, and on iOS Web Audio runs through
/// the app's `AVAudioSession` like everything else. The default category respects
/// the ring/silent switch, which on an iPad is a side switch or a Control Centre
/// toggle nobody associates with a remote desktop — the symptom is a session that
/// looks connected and is simply silent.
///
/// `.playback` is the honest description of what this app does with sound: it is
/// the point of the session, not an accompaniment to it. Set, not activated —
/// WebKit activates the shared session itself when the page starts playing, and
/// activating here would interrupt whatever else is playing at launch.
enum AudioOutput {
    static func prepare() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        } catch {
            // Not fatal and not worth a screen: the session keeps its default
            // category, and the desktop's sound follows the silent switch.
            NSLog("remotex: could not claim playback audio: \(error.localizedDescription)")
        }
    }
}
