interface ISpeechClient
    dependsOn(SpeechManager);

import enum SpeechRecognitionConfidence from SpeechManager;

//Rule refers to the NAME of the RULE that was recognized
//Value refers to the VALSTR of the PHRASE that was recognized
function OnSpeechCommandRecognized(name Rule, name Value, SpeechRecognitionConfidence Confidence);
