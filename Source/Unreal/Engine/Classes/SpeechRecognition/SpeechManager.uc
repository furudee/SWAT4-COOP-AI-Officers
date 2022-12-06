class SpeechManager extends Core.Object
    native;

struct native ClientInterest
{
    var ISpeechClient Client;
    var name Rule;
};
var array<ClientInterest> ClientInterests;

enum SpeechRecognitionConfidence
{
    Confidence_Low,
    Confidence_Medium,
    Confidence_High
};

var Viewport Viewport;

//pass Rule=None to register interest in _any_ rule
final function RegisterRuleInterest(ISpeechClient Client, name Rule)
{
    local ClientInterest Interest;

    Interest.Client = Client;
    Interest.Rule = Rule;

    //add the interested client to our interests list
    ClientInterests[ClientInterests.length] = Interest;
}

//pass Rule=None to unregister all Client's interests
final function UnRegisterRuleInterest(ISpeechClient Client, name Rule)
{
    local int i;

    while (i < ClientInterests.length)
    {
        while   (
                    ClientInterests[i].Client == Client
                &&  (
                        ClientInterests[i].Rule == Rule
                    ||  Rule == 'None'
                    )
                )
        {
            ClientInterests.Remove(i,1);
        }
        ++i;
    }
    
    if (ClientInterests.length == 0)
        StopRecognition();  //nobody interested
}

final function Init()
{
//    if (ClientInterests.length == 1)  //first entry in the list
        StartRecognition(); //somebody interested
}

event OnCommandRecognized(name Rule, name Value, SpeechRecognitionConfidence Confidence)
{
    local int i;

    assertWithDescription(ClientInterests.length > 0,
        "[tcohen] The SpeechManager was called OnCommandRecognized(), but nobody is interested.");

    for (i=0; i<ClientInterests.length; ++i)
        if (ClientInterests[i].Rule == Rule || ClientInterests[i].Rule == 'None')
            ClientInterests[i].Client.OnSpeechCommandRecognized(Rule, Value, Confidence);
}

native function StartRecognition();
native function StopRecognition();
