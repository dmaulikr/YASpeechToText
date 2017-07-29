//
//  ViewController.m
//  YASpeechToText
//
//  Created by Yashica Agrawal on 29/07/17.
//  Copyright © 2017 Yashica Agrawal. All rights reserved.
//

#import "ViewController.h"
#import <Speech/Speech.h>

@interface ViewController ()<SFSpeechRecognizerDelegate>
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIButton *microphoneButton;

@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;
@property (nonatomic, strong) AVAudioEngine *audioEngine;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self.microphoneButton setEnabled:false];
    
    self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"en-US"]];
    [self.speechRecognizer setDelegate:self];
    
    self.audioEngine = [[AVAudioEngine alloc] init];
    
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus authStatus) {
        BOOL isButtonEnabled = false;
        
        switch (authStatus) {
            case SFSpeechRecognizerAuthorizationStatusAuthorized:{
                //User gave access to speech recognition
                NSLog(@"Authorized");
                isButtonEnabled = true;
                break;
            }
            case SFSpeechRecognizerAuthorizationStatusDenied: {
                //User denied access to speech recognition
                NSLog(@"SFSpeechRecognizerAuthorizationStatusDenied");
                isButtonEnabled = false;
                break;
            }
            case SFSpeechRecognizerAuthorizationStatusRestricted: {
                //Speech recognition restricted on this device
                NSLog(@"SFSpeechRecognizerAuthorizationStatusRestricted");
                isButtonEnabled = false;
                break;
            }
            case SFSpeechRecognizerAuthorizationStatusNotDetermined: {
                //Speech recognition not yet authorized
                isButtonEnabled = false;
                break;
            }
            default:
                NSLog(@"Default");
                break;
        }
        
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [self.microphoneButton setEnabled:isButtonEnabled];
        }];
    }];
}

- (IBAction)microphoneTapped:(id)sender {
    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
        [self.recognitionRequest endAudio];
        [self.microphoneButton setEnabled:false];
        [self.microphoneButton setTitle:@"Start Recording" forState:UIControlStateNormal];
    } else {
        [self startRecording];
        [self.microphoneButton setTitle:@"Stop Recording" forState:UIControlStateNormal];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(void)startRecording {
    
    if (self.recognitionTask != nil) {  //1
        [self.recognitionTask cancel];
        self.recognitionTask = nil;
    }
    
    NSError * outError;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance]; //2
    [audioSession setCategory:AVAudioSessionCategoryRecord error:&outError];
    [audioSession setMode:AVAudioSessionModeMeasurement error:&outError];
    [audioSession setActive:true withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation  error:&outError];
    
    self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init]; //3
    
    AVAudioNode *inputNode = [self.audioEngine inputNode];
    if (inputNode == nil) {
        NSLog(@"Audio engine has no input node");
    } //4
    
    if (self.recognitionRequest == nil) {
        NSLog(@"Unable to create an SFSpeechAudioBufferRecognitionRequest object");
    } //5
    
    self.recognitionRequest.shouldReportPartialResults = true;  //6
    
    self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        BOOL isFinal = false;
        
        if (result != nil) {
            self.textView.text = result.bestTranscription.formattedString;
            isFinal = result.isFinal;
        }
        
        if (error != nil || isFinal) {
            [self.audioEngine stop];
            [inputNode removeTapOnBus:0];
            
            self.recognitionRequest = nil;
            self.recognitionTask = nil;
            
            [self.microphoneButton setEnabled:true];
        }
    }];
    
    
    [inputNode installTapOnBus:0 bufferSize:4096 format:[inputNode outputFormatForBus:0] block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when){
        NSLog(@"Block tap!");
        [self.recognitionRequest appendAudioPCMBuffer:buffer];
    }];
    
    [self.audioEngine prepare];  //12
    @try {
        [self.audioEngine startAndReturnError:&outError];
    } @catch (NSException *exception) {
        NSLog(@"audioEngine couldn't start because of an error.");
    }
    self.textView.text = @"Say something, I'm listening!";
}

-(void) speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {
    if (available) {
        [self.microphoneButton setEnabled:true];
    } else {
        [self.microphoneButton setEnabled:false];
    }
}

@end
