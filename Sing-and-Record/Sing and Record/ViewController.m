//
//  ViewController.m
//  Sing and Record
//
//  Created by Apple on 17/11/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h> 
#import "UIImageEffects.h"

@interface ViewController ()<AVAudioRecorderDelegate, AVAudioPlayerDelegate, MPMediaPickerControllerDelegate>
{
    AVAudioRecorder *recorder;
    AVAudioPlayer *player;
    IBOutlet UILabel *songName;
    IBOutlet UIButton *play;
    IBOutlet UIButton *pause;
    IBOutlet UIButton *rec;
    IBOutlet UIButton *stop;
    IBOutlet UIButton *menu;
    NSURL *songUrl;
    NSURL *recordedAudioURL;
    IBOutlet UIImageView *bg;
    IBOutlet UILabel *timerLabel;
    NSTimer *timer;
    int ticks;
}

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // Set the audio file
    NSArray *pathComponents = [NSArray arrayWithObjects:
                               [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject],
                               @"MyAudioMemo.m4a",
                               nil];
    songName.text = @"";
    NSURL *outputFileURL = [NSURL fileURLWithPathComponents:pathComponents];
    recordedAudioURL = outputFileURL;
    
    // Setup audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    // Define the recorder setting
    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
    
    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt: 2] forKey:AVNumberOfChannelsKey];
    [recordSetting setValue:[NSNumber numberWithInt: AVAudioQualityMax] forKey:AVEncoderAudioQualityKey];
    
    // Initiate and prepare the recorder
    recorder = [[AVAudioRecorder alloc] initWithURL:outputFileURL settings:recordSetting error:NULL];
    recorder.delegate = self;
    recorder.meteringEnabled = YES;
    [recorder prepareToRecord];
    
    bg.image = [self blurWithImageEffects:[UIImage imageNamed:@"BG.png"]];
    
    play.enabled = NO;
    stop.enabled = NO;
    rec.enabled = YES;
    pause.enabled = NO;
    menu.enabled = YES;
    timerLabel.hidden = YES; 
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startRecord:(id)sender
{
    if (!recorder.recording)
    {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:YES error:nil];
        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        NSError *error;
        BOOL success = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        if(!success)
        {
            NSLog(@"error doing outputaudioportoverride - %@", [error localizedDescription]);
        }
        
        play.enabled = NO;
        stop.enabled = YES;
        rec.enabled = NO;
        pause.enabled = NO;
        menu.enabled = NO;
        timerLabel.hidden = NO;
        timerLabel.text = @"00:00";
        ticks = 0;
        timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(aTimer) userInfo:nil repeats:YES];
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addTimer:timer forMode:NSDefaultRunLoopMode];
        
        // Start recording
        [recorder record];
        [self playWithUrl:songUrl];
    }
}

- (IBAction)attachKaraoke:(id)sender
{
    MPMediaPickerController *mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes: MPMediaTypeAny];
    
    mediaPicker.delegate = self;
    mediaPicker.allowsPickingMultipleItems = NO;
    mediaPicker.prompt = @"Select songs to play";
    
    [self presentViewController:mediaPicker animated:YES completion:nil];
}

- (void) mediaPicker: (MPMediaPickerController *) mediaPicker didPickMediaItems: (MPMediaItemCollection *) mediaItemCollection
{
    if (mediaItemCollection)
    { 
        MPMediaItem *mediaItem = [[mediaItemCollection items] objectAtIndex:0];
        songUrl = mediaItem.assetURL;
        songUrl = [mediaItem valueForProperty:MPMediaItemPropertyAssetURL];
        
        if (songUrl)
        {
            songName.text = [mediaItem valueForProperty:MPMediaItemPropertyTitle];
            NSLog(@"%@", [mediaItem valueForProperty:MPMediaItemPropertyTitle]);
            play.enabled = YES;
        }
        
        rec.enabled = YES;
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)aTimer
{
    ticks += 1;
    
    int seconds = ticks % 60;
    int minutes = ticks / 60;
    
    NSString *secondsStr = [NSString stringWithFormat:@"%d",seconds];
    if (seconds<10) {
        secondsStr = [NSString stringWithFormat:@"0%d",seconds];
    }
    
    NSLog(@"%d, %@",seconds,secondsStr);
    
    NSString *minuteStr = [NSString stringWithFormat:@"%d",minutes];
    if (minutes<10) {
        minuteStr = [NSString stringWithFormat:@"0%d",minutes];
    }
    NSLog(@"%d, %@",minutes,minuteStr);
    
     timerLabel.text = [NSString stringWithFormat:@"%@:%@",minuteStr, secondsStr];
}

- (IBAction)stop:(id)sender
{
    if (player.isPlaying == YES)
    {
        [player stop];
    }
    if (recorder.isRecording == YES)
    {
        [recorder stop];
    }
    
    menu.enabled = YES;
    play.enabled = YES;
    
    [timer invalidate];
}

- (IBAction)play:(id)sender
{
    [self playWithUrl:songUrl];
}

-(void)playWithUrl:(NSURL*)url
{
    play.enabled = NO;
    NSError *error;
    player = [[AVAudioPlayer alloc] initWithContentsOfURL: url error: &error];
    [player setNumberOfLoops:0];
    player.delegate = self;
    [player setVolume: 1.0];
    [player play];
    stop.enabled = YES;
}

- (void) mediaPickerDidCancel: (MPMediaPickerController *) mediaPicker
{
    [self dismissViewControllerAnimated: YES completion:nil];
}

- (BOOL)isHeadsetPluggedIn
{
    UInt32 routeSize = sizeof (CFStringRef);
    CFStringRef route;
    
    OSStatus error = AudioSessionGetProperty (kAudioSessionProperty_AudioRoute,
                                              &routeSize,
                                              &route);
    
    /* Known values of route:
     * "Headset"
     * "Headphone"
     * "Speaker"
     * "SpeakerAndMicrophone"
     * "HeadphonesAndMicrophone"
     * "HeadsetInOut"
     * "ReceiverAndMicrophone"
     * "Lineout"
     */
    
    if (!error && (route != NULL)) {
        
        NSString* routeStr = [NSString stringWithFormat:@"%@",route];
        
        NSRange headphoneRange = [routeStr rangeOfString : @"Head"];
        
        if (headphoneRange.location != NSNotFound) return YES;
        
    }
    
    return NO;
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *) aRecorder successfully:(BOOL)flag
{
    songUrl = aRecorder.url;
    NSLog (@"audioRecorderDidFinishRecording:successfully:");
    // your actions here
    
}

- (UIImage *)blurWithImageEffects:(UIImage *)image
{
    return [UIImageEffects imageByApplyingBlurToImage:image withRadius:30 tintColor:[UIColor colorWithWhite:1 alpha:0.2] saturationDeltaFactor:1.5 maskImage:nil];
}

@end
