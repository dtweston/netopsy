import Foundation
import PlaygroundSupport
import ApplicationServices

PlaygroundPage.current.needsIndefiniteExecution = true

var channel: SpeechChannel? = nil
let result = NewSpeechChannel(nil, &channel)

if let channel = channel {
    let result = SpeakCFString(channel, "Spell the word: cat" as CFString, nil)
    print(result)
}

struct Synthesizer {

}

struct VoiceId {
    
}

struct Voice {
    fileprivate func voiceSpec() -> VoiceSpec {
        var voiceSpec: VoiceSpec?
        let result = MakeVoiceSpec(kTextToSpeechVoiceType, kTextServiceClass, voiceSpec)
        return voiceSpec
    }
}

class Channel {
    let innerChannel: SpeechChannel

    init(voice: Voice? = nil) throws {
        var channel: SpeechChannel? = nil
        let result: OSErr = {
            if let voice = voice {
                var mutableVoice = voice.voiceSpec()
                return NewSpeechChannel(&mutableVoice, &channel)
            } else {
                return NewSpeechChannel(nil, &channel)
            }
        }()

        if result == noErr {
            innerChannel = channel!
        } else {
            throw NSError(domain: "com.binocracy.Speech", code: Int(result))
        }
    }
}

extension UnsafeMutablePointer where Pointee == SpeechChannelRecord {
    init(voice: VoiceSpec? = nil) throws {
        var channel: SpeechChannel? = nil
        let result: OSErr = {
            if let voice = voice {
                var mutableVoice = voice
                return NewSpeechChannel(&mutableVoice, &channel)
            } else {
                return NewSpeechChannel(nil, &channel)
            }
        }()

        if result == noErr {
            self = channel!
        } else {
            throw NSError(domain: "com.binocracy.Speech", code: Int(result))
        }
    }
}

let channel2 = try SpeechChannel()

