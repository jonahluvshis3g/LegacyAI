#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <dlfcn.h>
#import "RPCharacterStore.h"
#import "RPChatHistory.h"
#import "RPClassicTheme.h"
#import <QuartzCore/QuartzCore.h>

// Signatures verified against the Objective-C metadata in iPhoneOS6.1 VoiceServices.
// Resolve the class at runtime so unavailable private speech support cannot prevent launch.
@interface NSObject (RP6LegacySpeech)
- (id)startSpeakingString:(NSString *)text;
- (id)startSpeakingString:(NSString *)text withLanguageCode:(NSString *)language;
- (id)stopSpeakingAtNextBoundary:(int)boundary;
- (void)setDelegate:(id)delegate;
@end


static UIColor *RPBackground(void) { return [UIColor colorWithRed:0.86 green:0.89 blue:0.92 alpha:1]; }

@interface MessageEditor : UIViewController
@property(nonatomic,copy) NSString *originalText;
@property(nonatomic,copy) NSString *saveHint;
@property(nonatomic,strong) UITextView *textView;
@property(nonatomic,strong) UILabel *hint;
@property(nonatomic,copy) void (^onSave)(NSString *);
@property(nonatomic) CGFloat keyboardHeight;
@end
@implementation MessageEditor
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"Edit message"; self.view.backgroundColor=RPBackground();
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveMessage)];
    self.hint=[[UILabel alloc] initWithFrame:CGRectZero]; self.hint.numberOfLines=3;
    self.hint.font=[UIFont systemFontOfSize:13]; self.hint.textColor=[UIColor darkGrayColor]; self.hint.backgroundColor=[UIColor clearColor];
    self.hint.text=self.saveHint ?: @"Saving removes later messages. Your edited message gets a new reply automatically. Go back to cancel.";
    [self.view addSubview:self.hint];
    self.textView=[[UITextView alloc] initWithFrame:CGRectZero]; self.textView.font=[UIFont systemFontOfSize:17];
    self.textView.text=self.originalText; self.textView.layer.cornerRadius=6; self.textView.layer.borderWidth=1; self.textView.layer.borderColor=[UIColor colorWithWhite:0.65 alpha:1].CGColor; [self.view addSubview:self.textView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.navigationController setToolbarHidden:YES animated:NO]; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)keyboard:(NSNotification *)note {
    CGRect rect=[self.view convertRect:[note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    self.keyboardHeight=MAX(0,self.view.bounds.size.height-rect.origin.y); [self.view setNeedsLayout];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height-self.keyboardHeight;
    self.hint.frame=CGRectMake(12,8,w-24,66); self.textView.frame=CGRectMake(12,80,w-24,MAX(40,h-92));
}
- (void)saveMessage {
    NSString *text=[self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(!text.length || text.length>8000) {
        [[[UIAlertView alloc] initWithTitle:@"Check your message" message:@"Enter 1–8,000 characters." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show]; return;
    }
    if(self.onSave) self.onSave(text);
    [self.view endEditing:YES]; [self.navigationController popViewControllerAnimated:YES];
}
@end

@interface BubbleCell : UITableViewCell
@property(nonatomic,strong) RPClassicBubbleView *bubble;
@property(nonatomic,strong) UILabel *senderLabel;
@property(nonatomic,strong) UILabel *bodyLabel;
@property(nonatomic) BOOL user;
@end
@implementation BubbleCell
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if((self=[super initWithStyle:style reuseIdentifier:identifier])) {
        self.selectionStyle=UITableViewCellSelectionStyleNone; self.backgroundColor=[UIColor clearColor];
        self.bubble=[[RPClassicBubbleView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:self.bubble];
        self.senderLabel=[[UILabel alloc] initWithFrame:CGRectZero]; self.senderLabel.font=[UIFont boldSystemFontOfSize:12];
        self.senderLabel.backgroundColor=[UIColor clearColor]; [self.bubble addSubview:self.senderLabel];
        self.bodyLabel=[[UILabel alloc] initWithFrame:CGRectZero]; self.bodyLabel.numberOfLines=0; self.bodyLabel.font=[UIFont systemFontOfSize:16];
        self.bodyLabel.backgroundColor=[UIColor clearColor]; [self.bubble addSubview:self.bodyLabel];
    } return self;
}
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat width=self.contentView.bounds.size.width-48;
    self.bubble.frame=CGRectMake(self.user ? 36 : 12,6,width,self.contentView.bounds.size.height-12);
    self.bubble.outgoing=self.user;
    [self.bubble setNeedsDisplay];
    self.senderLabel.textColor=RPClassicBlue();
    self.senderLabel.shadowColor=[UIColor colorWithWhite:1 alpha:0.7]; self.senderLabel.shadowOffset=CGSizeMake(0,1);
    self.bodyLabel.textColor=[UIColor colorWithWhite:0.12 alpha:1];
    self.senderLabel.frame=CGRectMake(self.user ? 14 : 22,9,width-40,16);
    self.bodyLabel.frame=CGRectMake(self.user ? 14 : 22,30,width-40,self.bubble.bounds.size.height-42);
}
@end

@interface ChatController : UIViewController <UIAlertViewDelegate, UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate>
@property(nonatomic,strong) RPCharacterStore *store;
@property(nonatomic,strong) NSMutableDictionary *character;
@property(nonatomic,strong) UITableView *chatTable;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIView *composer;
@property(nonatomic,strong) CAGradientLayer *composerGradient;
@property(nonatomic,strong) UITextField *input;
@property(nonatomic,strong) UIButton *sendButton;
@property(nonatomic,strong) NSMutableArray *messages;
@property(nonatomic,copy) NSArray *displayMessages;
@property(nonatomic) BOOL replyAfterEdit;
@property(nonatomic) BOOL busy;
@property(nonatomic,strong) id speechSynthesizer;
@property(nonatomic) BOOL speechAudioActive;
@property(nonatomic,strong) UIBarButtonItem *voiceButton;
@property(nonatomic) CGFloat keyboardHeight;
@property(nonatomic) NSUInteger selectedMessage;
@property(nonatomic,strong) UIScrollView *memberStrip;
@property(nonatomic,strong) NSMutableSet *selectedSpeakers;
@end
@implementation ChatController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=self.character[@"name"]; self.view.backgroundColor=[UIColor colorWithRed:0.86 green:0.89 blue:0.92 alpha:1];
    self.messages=self.character[@"messages"];
    self.displayMessages=[self.messages copy];
    if(self.character[@"memberIDs"]) {
        self.memberStrip=[[UIScrollView alloc] initWithFrame:CGRectZero]; self.memberStrip.backgroundColor=RPBackground();
        [self.view addSubview:self.memberStrip]; [self reloadMembers];
    }
    self.navigationItem.rightBarButtonItems=@[[[UIBarButtonItem alloc] initWithTitle:@"New chat" style:UIBarButtonItemStylePlain target:self action:@selector(newChat)],[[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:self action:@selector(editCharacter)]];
    self.statusLabel=[[UILabel alloc] initWithFrame:CGRectZero]; self.statusLabel.backgroundColor=[UIColor clearColor];
    self.statusLabel.shadowColor=[UIColor whiteColor]; self.statusLabel.shadowOffset=CGSizeMake(0,1);
    self.statusLabel.font=[UIFont boldSystemFontOfSize:12]; self.statusLabel.textColor=RPClassicBlue(); self.statusLabel.textAlignment=UITextAlignmentCenter;
    [self.view addSubview:self.statusLabel];
    self.chatTable=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.chatTable.backgroundColor=[UIColor clearColor]; self.chatTable.separatorStyle=UITableViewCellSeparatorStyleNone;
    self.chatTable.dataSource=self; self.chatTable.delegate=self; [self.view addSubview:self.chatTable];
    self.composer=[[UIView alloc] initWithFrame:CGRectZero]; self.composer.backgroundColor=[UIColor lightGrayColor];
    self.composerGradient=[CAGradientLayer layer];
    self.composerGradient.colors=@[(id)[UIColor colorWithWhite:0.95 alpha:1].CGColor,(id)[UIColor colorWithWhite:0.69 alpha:1].CGColor];
    [self.composer.layer addSublayer:self.composerGradient];
    self.composer.layer.borderColor=[UIColor colorWithWhite:0.48 alpha:1].CGColor; self.composer.layer.borderWidth=0.5;
    [self.view addSubview:self.composer];
    self.input=[[UITextField alloc] initWithFrame:CGRectZero]; self.input.borderStyle=UITextBorderStyleRoundedRect;
    self.input.placeholder=@"Message"; [self.composer addSubview:self.input];
    self.sendButton=[UIButton buttonWithType:UIButtonTypeCustom]; [self.sendButton setTitle:@"Send" forState:UIControlStateNormal];
    self.sendButton.titleLabel.font=[UIFont boldSystemFontOfSize:15];
    [self.sendButton setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.6] forState:UIControlStateNormal];
    self.sendButton.titleLabel.shadowOffset=CGSizeMake(0,-1);
    [self.sendButton setBackgroundImage:RPClassicSendButton(NO) forState:UIControlStateNormal];
    [self.sendButton setBackgroundImage:RPClassicSendButton(YES) forState:UIControlStateHighlighted];
    [self.sendButton addTarget:self action:@selector(send) forControlEvents:UIControlEventTouchUpInside]; [self.composer addSubview:self.sendButton];
    self.voiceButton=[[UIBarButtonItem alloc] initWithTitle:@"Voice" style:UIBarButtonItemStylePlain target:self action:@selector(toggleVoice)];
    UIBarButtonItem *stop=[[UIBarButtonItem alloc] initWithTitle:@"Stop voice" style:UIBarButtonItemStylePlain target:self action:@selector(stopSpeech)];
    self.toolbarItems=@[self.voiceButton,[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],stop];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopSpeech) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(historyUpdated:) name:@"RPHistoryUpdated" object:nil];
    [self render];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated]; [self.navigationController setToolbarHidden:NO animated:NO]; [self render];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self render];
    if(self.replyAfterEdit) { self.replyAfterEdit=NO; [self refreshLast]; }
}
- (void)dealloc { [self stopSpeech]; [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height-self.keyboardHeight;
    self.statusLabel.frame=CGRectMake(8,0,w-16,28);
    CGFloat memberHeight=self.memberStrip ? 82 : 0;
    self.chatTable.frame=CGRectMake(0,28,w,MAX(0,h-82-memberHeight));
    self.memberStrip.frame=CGRectMake(0,h-54-memberHeight,w,memberHeight);
    self.composer.frame=CGRectMake(0,h-54,w,54);
    self.composerGradient.frame=self.composer.bounds;
    self.input.frame=CGRectMake(10,9,w-86,36); self.sendButton.frame=CGRectMake(w-68,9,58,36);
}
- (void)keyboard:(NSNotification *)note {
    CGRect rect=[self.view convertRect:[note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    self.keyboardHeight=MAX(0,self.view.bounds.size.height-rect.origin.y);
    [self.view setNeedsLayout]; [self.view layoutIfNeeded]; [self scrollToLast];
}
- (void)reloadMembers {
    NSArray *participants=[self.store participantsForGroup:self.character];
    if(!self.selectedSpeakers) self.selectedSpeakers=[NSMutableSet setWithArray:[participants valueForKey:@"id"]];
    NSMutableSet *valid=[NSMutableSet setWithArray:[participants valueForKey:@"id"]];
    [self.selectedSpeakers intersectSet:valid];
    if(!self.selectedSpeakers.count) [self.selectedSpeakers unionSet:valid];
    for(UIView *view in [self.memberStrip.subviews copy]) [view removeFromSuperview];
    CGFloat slotWidth=self.view.bounds.size.width/4.0;
    self.memberStrip.showsHorizontalScrollIndicator=YES;
    for(NSUInteger i=0;i<participants.count;i++) {
        NSDictionary *member=participants[i];
        UIButton *button=[UIButton buttonWithType:UIButtonTypeCustom]; button.frame=CGRectMake(i*slotWidth+(slotWidth-56)/2,4,56,56);
        button.tag=i; [button setImage:RPCharacterAvatar(member) forState:UIControlStateNormal];
        button.layer.cornerRadius=8; button.clipsToBounds=YES;
        button.alpha=1;
        button.layer.borderWidth=1; button.layer.borderColor=RPClassicBlue().CGColor;
        button.enabled=![self.store isBusy:self.character];
        [button addTarget:self action:@selector(toggleMember:) forControlEvents:UIControlEventTouchUpInside]; [self.memberStrip addSubview:button];
        UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(i*slotWidth+3,62,slotWidth-6,16)]; label.text=member[@"name"];
        label.font=[UIFont boldSystemFontOfSize:10]; label.textAlignment=UITextAlignmentCenter; label.textColor=RPClassicBlue(); label.backgroundColor=[UIColor clearColor];
        [self.memberStrip addSubview:label];
    }
    self.memberStrip.contentSize=CGSizeMake(MAX(self.view.bounds.size.width,participants.count*slotWidth),82);
}
- (void)toggleMember:(UIButton *)button {
    NSArray *participants=[self.store participantsForGroup:self.character];
    if([self.store isBusy:self.character] || button.tag<0 || button.tag>=(NSInteger)participants.count) return;
    self.selectedSpeakers=[NSMutableSet setWithObject:participants[button.tag][@"id"]];
    [self.input resignFirstResponder];
    [self requestContext:[self.messages copy] pendingInput:nil];
}
- (void)scrollToLast {
    // UITableView's actual row count can lag behind the model during an editor pop.
    if(!self.chatTable.window || self.navigationController.topViewController!=self) return;
    [self.chatTable layoutIfNeeded];
    if([self.chatTable numberOfSections]<1) return;
    NSInteger count=[self.chatTable numberOfRowsInSection:0];
    if(count>0) [self.chatTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:count-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
}
- (void)render {
    self.busy=[self.store isBusy:self.character];
    self.statusLabel.text=self.busy ? @"Writing a reply…" : (self.memberStrip ? @"Tap an icon to make that character speak" : @"Tap any message to edit, delete, or refresh");
    if(self.memberStrip) [self reloadMembers];
    self.voiceButton.title=[self voiceEnabled] ? @"Voice: On" : @"Voice: Off";
    self.sendButton.enabled=!self.busy; self.sendButton.alpha=self.busy ? 0.45 : 1;
    self.input.enabled=!self.busy;
    for(UIBarButtonItem *item in self.navigationItem.rightBarButtonItems) item.enabled=!self.busy;
    [self.store save];
    if(self.navigationController.topViewController!=self || !self.view.window) return;
    self.displayMessages=[self.messages copy];
    [self.chatTable reloadData]; [self.chatTable layoutIfNeeded]; [self scrollToLast];
}
- (void)historyUpdated:(NSNotification *)note { if(note.object==self.character) [self render]; }
- (void)commitHistory:(NSArray *)history {
    if(!history) return;
    [self.messages setArray:[history copy]]; [self.store save];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RPHistoryUpdated" object:self.character];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return MAX((NSUInteger)1,self.displayMessages.count); }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *text=indexPath.row < (NSInteger)self.displayMessages.count ? self.displayMessages[indexPath.row][@"content"] : @"Your story starts here. Send a message to begin.";
    CGFloat width=MAX(100,tableView.bounds.size.width-88);
    CGSize size=[text sizeWithFont:[UIFont systemFontOfSize:16] constrainedToSize:CGSizeMake(width,CGFLOAT_MAX) lineBreakMode:UILineBreakModeWordWrap];
    return MAX(84,ceil(size.height)+56);
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BubbleCell *cell=(BubbleCell *)[tableView dequeueReusableCellWithIdentifier:@"Bubble"];
    if(!cell) cell=[[BubbleCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Bubble"];
    NSDictionary *message=indexPath.row < (NSInteger)self.displayMessages.count ? self.displayMessages[indexPath.row] : nil;
    cell.user=[message[@"role"] isEqual:@"user"];
    cell.senderLabel.text=cell.user ? @"YOU" : (message[@"speaker"] ?: self.character[@"name"]);
    cell.bodyLabel.text=message ? message[@"content"] : @"Your story starts here. Send a message to begin.";
    [cell setNeedsLayout]; return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.row >= (NSInteger)self.displayMessages.count || indexPath.row >= (NSInteger)self.messages.count) return;
    if(self.busy) { [self alert:@"Wait for the current reply before changing messages."]; return; }
    [self.input resignFirstResponder]; self.selectedMessage=indexPath.row;
    BOOL assistant=[self.messages[indexPath.row][@"role"] isEqual:@"assistant"];
    UIActionSheet *sheet=[[UIActionSheet alloc] initWithTitle:assistant ? @"Character reply" : @"Your message" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    [sheet addButtonWithTitle:@"Edit message"];
    if(assistant) { [sheet addButtonWithTitle:@"Refresh reply"]; [sheet addButtonWithTitle:@"Read aloud"]; }
    sheet.destructiveButtonIndex=[sheet addButtonWithTitle:@"Delete message"];
    sheet.cancelButtonIndex=[sheet addButtonWithTitle:@"Cancel"];
    [sheet showInView:self.view.window ?: self.view];
}
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if(index<0 || index==sheet.cancelButtonIndex) { [sheet dismissWithClickedButtonIndex:sheet.cancelButtonIndex animated:YES]; return; }
    if([self.store isBusy:self.character] || self.selectedMessage>=self.messages.count) return;
    NSString *action=[sheet buttonTitleAtIndex:index];
    if([action isEqual:@"Read aloud"]) { [self speakText:self.messages[self.selectedMessage][@"content"]]; return; }
    if([action isEqual:@"Refresh reply"]) { [self refreshAtIndex:self.selectedMessage]; return; }
    if([action isEqual:@"Delete message"]) {
        UIAlertView *alert=[[UIAlertView alloc] initWithTitle:@"Delete this message?" message:@"Only the selected message will be removed." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete",nil]; alert.tag=7; [alert show]; return;
    }
    NSUInteger selected=self.selectedMessage;
    MessageEditor *editor=[[MessageEditor alloc] init]; editor.originalText=self.messages[selected][@"content"];
    if(self.character[@"memberIDs"]) editor.saveHint=@"Saving removes later messages. Characters speak only when you tap their icons. Go back to cancel.";
    editor.onSave=^(NSString *text) {
        if([self.store isBusy:self.character]) { [self alert:@"Wait for the current reply before editing."]; return; }
        NSArray *edited=RPHistoryWithEdit(self.messages,selected,text);
        if(!edited) { [self alert:@"This message could not be edited."]; return; }
        [self stopSpeech];
        self.replyAfterEdit=!self.character[@"memberIDs"] && [edited.lastObject[@"role"] isEqual:@"user"];
        [self commitHistory:edited];
    };
    [self.navigationController pushViewController:editor animated:YES];
}
- (void)alert:(NSString *)message {
    [[[UIAlertView alloc] initWithTitle:@"LegacyAI" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index {
    if(index!=1 || [self.store isBusy:self.character]) return;
    if(alert.tag==5) { [self stopSpeech]; [self.messages removeAllObjects]; self.input.text=@""; [self commitHistory:[self.messages copy]]; }
    else if(alert.tag==7) { [self stopSpeech]; [self commitHistory:RPHistoryWithDeletion(self.messages,self.selectedMessage)]; }
    else if(alert.tag==6) [self regenerateAtIndex:self.selectedMessage];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated]; [self stopSpeech]; [self.input resignFirstResponder]; [self.store save];
}
- (BOOL)voiceEnabled {
    id saved = [[NSUserDefaults standardUserDefaults] objectForKey:@"voiceEnabled"];
    return saved ? [saved boolValue] : YES;
}
- (void)toggleVoice {
    BOOL enabled = ![self voiceEnabled];
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"voiceEnabled"];
    if (!enabled) [self stopSpeech];
    [self render];
}
- (void)releaseSpeechAudio {
    if(!self.speechAudioActive) return;
    self.speechAudioActive=NO;
    AVAudioSession *audio=[AVAudioSession sharedInstance];
    if([audio respondsToSelector:@selector(setActive:withOptions:error:)])
        [audio setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    else [audio setActive:NO withFlags:AVAudioSessionSetActiveFlags_NotifyOthersOnDeactivation error:nil];
}
- (void)speechSynthesizer:(id)synthesizer didFinishSpeaking:(BOOL)finished withError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(synthesizer!=self.speechSynthesizer) return;
        [self stopSpeech];
    });
}
- (void)stopSpeech {
    @try {
        if([self.speechSynthesizer respondsToSelector:@selector(setDelegate:)]) [self.speechSynthesizer setDelegate:nil];
        if([self.speechSynthesizer respondsToSelector:@selector(stopSpeakingAtNextBoundary:)]) [self.speechSynthesizer stopSpeakingAtNextBoundary:0];
    } @catch(NSException *exception) {}
    self.speechSynthesizer=nil;
    [self releaseSpeechAudio];
}
- (void)speakText:(NSString *)text {
    if (!text.length) return;
    [self stopSpeech];
    @try {
        if (!self.speechSynthesizer) {
            static void *voiceServices = NULL;
            if (!voiceServices) voiceServices = dlopen("/System/Library/PrivateFrameworks/VoiceServices.framework/VoiceServices", RTLD_LAZY);
            Class speechClass = voiceServices ? NSClassFromString(@"VSSpeechSynthesizer") : Nil;
            self.speechSynthesizer = speechClass ? [[speechClass alloc] init] : nil;
        }
        if (![self.speechSynthesizer respondsToSelector:@selector(startSpeakingString:)]) {
            [self alert:@"This device does not have the system speech engine available."];
            return;
        }
        if([self.speechSynthesizer respondsToSelector:@selector(setDelegate:)]) [self.speechSynthesizer setDelegate:self];
        NSError *audioError = nil;
        AVAudioSession *audio = [AVAudioSession sharedInstance];
        if (![audio setCategory:AVAudioSessionCategoryPlayback error:&audioError] ||
            ![audio setActive:YES error:&audioError]) {
            self.speechAudioActive=YES; [self stopSpeech];
            [self alert:audioError.localizedDescription ?: @"Could not enable audio playback."];
            return;
        }
        self.speechAudioActive=YES;
        id result;
        if ([self.speechSynthesizer respondsToSelector:@selector(startSpeakingString:withLanguageCode:)])
            result = [self.speechSynthesizer startSpeakingString:text withLanguageCode:@"en-US"];
        else result = [self.speechSynthesizer startSpeakingString:text];
        if ([result isKindOfClass:[NSError class]]) { [self stopSpeech]; [self alert:[result localizedDescription]]; }
    } @catch (NSException *exception) {
        [self stopSpeech];
        [self alert:@"System speech is unavailable on this device. You can turn Voice off and continue chatting."];
    }
}
- (void)speakLast {
    for (NSDictionary *message in [self.messages reverseObjectEnumerator]) {
        if ([message[@"role"] isEqual:@"assistant"]) {
            [self speakText:message[@"content"]];
            return;
        }
    }
    [self alert:@"There is no character reply to read yet."];
}
- (void)newChat {
    if([self.store isBusy:self.character]) return;
    UIAlertView *alert=[[UIAlertView alloc] initWithTitle:@"Start a new story?" message:@"This clears this character’s conversation." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Clear",nil]; alert.tag=5; [alert show];
}
- (void)refreshLast {
    if([self.store isBusy:self.character] || !self.messages.count) return;
    if(self.character[@"memberIDs"] && [self.messages.lastObject[@"role"] isEqual:@"user"]) { [self alert:@"Tap a character’s icon to request their reply."]; return; }
    if([self.messages.lastObject[@"role"] isEqual:@"user"]) [self requestContext:[self.messages copy] pendingInput:nil];
    else [self refreshAtIndex:self.messages.count-1];
}
- (void)refreshAtIndex:(NSUInteger)index {
    if([self.store isBusy:self.character] || index>=self.messages.count) return;
    [self regenerateAtIndex:index];
}
- (void)regenerateAtIndex:(NSUInteger)index {
    if([self.store isBusy:self.character] || index>=self.messages.count || ![self.messages[index][@"role"] isEqual:@"assistant"]) return;
    BOOL group=self.character[@"memberIDs"]!=nil;
    NSArray *context=group ? [self.messages subarrayWithRange:NSMakeRange(0,index)] : RPRegenerationContext(self.messages,index);
    if(group && self.messages[index][@"speakerID"]) self.selectedSpeakers=[NSMutableSet setWithObject:self.messages[index][@"speakerID"]];
    if(context) [self requestContext:context pendingInput:nil replacingIndex:index];
    else [self alert:@"This reply has no earlier user message to regenerate from."];
}
- (void)send {
    if([self.store isBusy:self.character]) return;
    NSString *message=[self.input.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(!message.length) return;
    if(message.length>8000) { [self alert:@"Please keep each message under 8,000 characters."]; return; }
    NSMutableArray *context=[self.messages mutableCopy]; [context addObject:@{@"role":@"user",@"content":message}];
    if(self.character[@"memberIDs"]) {
        self.input.text=@""; [self commitHistory:context]; return;
    }
    [self requestContext:context pendingInput:message];
}
- (void)requestContext:(NSArray *)context pendingInput:(NSString *)pendingInput {
    [self requestContext:context pendingInput:pendingInput replacingIndex:NSNotFound];
}
- (void)requestContext:(NSArray *)context pendingInput:(NSString *)pendingInput replacingIndex:(NSUInteger)replacementIndex {
    if([self.store isBusy:self.character] || (!context.count && !self.character[@"memberIDs"])) return;
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    NSString *base=[defaults stringForKey:@"customEndpoint"] ?: @"https://ai.ios6.xyz";
    while([base hasSuffix:@"/"]) base=[base substringToIndex:base.length-1];
    BOOL groupMode=self.character[@"memberIDs"]!=nil;
    NSArray *participants=groupMode ? [self.store participantsForGroup:self.character] : @[];
    if(groupMode && !participants.count) { [self alert:@"Edit this group to choose characters before sending."]; return; }
    NSMutableArray *cast=[NSMutableArray array],*respondingIDs=[NSMutableArray array];
    for(NSDictionary *member in participants) {
        [cast addObject:@{@"id":member[@"id"],@"name":member[@"name"],@"persona":member[@"persona"]}];
        if([self.selectedSpeakers containsObject:member[@"id"]]) [respondingIDs addObject:member[@"id"]];
    }
    if(groupMode && respondingIDs.count!=1) { [self alert:@"Tap a character’s icon to choose who speaks."]; return; }
    NSURL *url=[NSURL URLWithString:[base stringByAppendingString:[base isEqual:@"https://ai.ios6.xyz"] ? (groupMode ? @"/public-group-chat" : @"/public-chat") : (groupMode ? @"/group-chat" : @"/chat")]];
    if(!url.host.length || !([url.scheme isEqual:@"http"] || [url.scheme isEqual:@"https"])) { [self alert:@"Check the server address."]; return; }
    NSArray *snapshot=[context copy],*original=[self.messages copy];
    NSUInteger start=snapshot.count>24 ? snapshot.count-24 : 0;
    NSMutableDictionary *body=[@{@"messages":[snapshot subarrayWithRange:NSMakeRange(start,snapshot.count-start)],@"character":self.character[@"name"],@"persona":self.character[@"persona"]} mutableCopy];
    if(groupMode) { body[@"participants"]=cast; body[@"respondingIDs"]=respondingIDs; }
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:300];
    request.HTTPMethod=@"POST"; [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    [self stopSpeech]; [self.store setBusy:YES character:self.character];
    if(pendingInput) { [self.messages setArray:snapshot]; self.input.text=@""; }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RPHistoryUpdated" object:self.character];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response,NSData *data,NSError *error) {
        [self.store setBusy:NO character:self.character];
        id json=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if(![json isKindOfClass:[NSDictionary class]]) json=nil;
        id reply=json[@"reply"];
        NSArray *updated=groupMode ? RPHistoryWithGroupReplies(snapshot,json[@"replies"],respondingIDs) : ([reply isKindOfClass:[NSString class]] ? RPHistoryWithReply(snapshot,reply) : nil);
        if(updated && replacementIndex!=NSNotFound) updated=RPHistoryWithRefreshedReply(original,replacementIndex,updated.lastObject);
        BOOL success=!error && [response isKindOfClass:[NSHTTPURLResponse class]] && [(NSHTTPURLResponse *)response statusCode]==200 && updated;
        if(success) {
            [self commitHistory:updated];
            if([self voiceEnabled] && self.navigationController.topViewController==self) {
                if(groupMode) {
                    NSMutableArray *spoken=[NSMutableArray array]; for(NSDictionary *m in json[@"replies"]) [spoken addObject:[NSString stringWithFormat:@"%@: %@",m[@"speaker"],m[@"content"]]];
                    [self speakText:[spoken componentsJoinedByString:@". "]];
                } else [self speakText:reply];
            }
        } else {
            if(pendingInput) { [self.messages setArray:original]; self.input.text=pendingInput; }
            [self commitHistory:[self.messages copy]];
            id detail=json[@"error"];
            if(groupMode && [response isKindOfClass:[NSHTTPURLResponse class]] && [(NSHTTPURLResponse *)response statusCode]==404) detail=@"Restart the updated Mac bridge server to enable group roleplay.";
            NSString *message=error.localizedDescription ?: ([detail isKindOfClass:[NSString class]] ? detail : @"Server returned an invalid reply. Your conversation was kept.");
            if(self.navigationController.topViewController==self) [self alert:message];
        }
    }];
}
@end

@interface CharacterEditor : UIViewController <UIImagePickerControllerDelegate,UINavigationControllerDelegate>
@property(nonatomic,strong) RPCharacterStore *store;
@property(nonatomic,strong) NSMutableDictionary *character;
@property(nonatomic,strong) UITextField *nameField;
@property(nonatomic,strong) UIButton *avatarButton;
@property(nonatomic,strong) UIButton *chooseButton;
@property(nonatomic,strong) UIButton *resetButton;
@property(nonatomic,strong) NSData *pendingAvatar;
@property(nonatomic,strong) UIPopoverController *photoPopover;
@property(nonatomic,strong) UITextView *personaField;
@property(nonatomic,strong) UILabel *label;
@property(nonatomic,copy) void (^onSave)(void);
@property(nonatomic) CGFloat keyboardHeight;
@end
@implementation CharacterEditor
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.character ? @"Edit character" : @"New character";
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEditing)];
    self.pendingAvatar=self.character[@"avatarData"];
    self.avatarButton=[UIButton buttonWithType:UIButtonTypeCustom];
    self.avatarButton.layer.cornerRadius=8; self.avatarButton.clipsToBounds=YES;
    [self.avatarButton addTarget:self action:@selector(chooseAvatar) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.avatarButton];
    self.chooseButton=[UIButton buttonWithType:UIButtonTypeRoundedRect]; [self.chooseButton setTitle:@"Choose photo" forState:UIControlStateNormal];
    [self.chooseButton addTarget:self action:@selector(chooseAvatar) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:self.chooseButton];
    self.resetButton=[UIButton buttonWithType:UIButtonTypeRoundedRect]; [self.resetButton setTitle:@"Use default" forState:UIControlStateNormal];
    [self.resetButton addTarget:self action:@selector(resetAvatar) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:self.resetButton];
    [self updateAvatar];
    self.view.backgroundColor = RPBackground();
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveCharacter)];
    self.nameField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.nameField.borderStyle = UITextBorderStyleRoundedRect;
    self.nameField.placeholder = @"Character name";
    self.nameField.text = self.character[@"name"];
    [self.view addSubview:self.nameField];
    self.label = [[UILabel alloc] initWithFrame:CGRectZero];
    self.label.text = @"Personality, setting, and writing style";
    self.label.font = [UIFont boldSystemFontOfSize:14];
    self.label.backgroundColor = [UIColor clearColor]; self.label.textColor = RPClassicBlue();
    self.label.shadowColor = [UIColor whiteColor]; self.label.shadowOffset = CGSizeMake(0,1);
    [self.view addSubview:self.label];
    self.personaField = [[UITextView alloc] initWithFrame:CGRectZero];
    self.personaField.font = [UIFont systemFontOfSize:17];
    self.personaField.backgroundColor = [UIColor whiteColor];
    self.personaField.layer.cornerRadius = 6; self.personaField.layer.borderWidth = 1;
    self.personaField.layer.borderColor = [UIColor colorWithWhite:0.65 alpha:1].CGColor;
    self.personaField.text = self.character[@"persona"] ?: @"A friendly fantasy explorer. Stay in character.";
    [self.view addSubview:self.personaField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES animated:NO];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height - self.keyboardHeight;
    self.avatarButton.frame=CGRectMake(12,12,64,64);
    self.nameField.frame=CGRectMake(88,26,w-100,36);
    self.chooseButton.frame=CGRectMake(12,84,142,34); self.resetButton.frame=CGRectMake(w-154,84,142,34);
    self.label.frame=CGRectMake(12,126,w-24,22);
    self.personaField.frame=CGRectMake(12,156,w-24,MAX(40,h-168));
}
- (void)keyboard:(NSNotification *)note {
    CGRect rect = [self.view convertRect:[note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    self.keyboardHeight = MAX(0,self.view.bounds.size.height-rect.origin.y);
    [self.view setNeedsLayout];
}
- (void)cancelEditing {
    [self.view endEditing:YES]; [self.navigationController popViewControllerAnimated:YES];
}
- (void)updateAvatar {
    NSDictionary *preview=self.pendingAvatar ? @{@"avatarData":self.pendingAvatar} : @{};
    [self.avatarButton setImage:RPCharacterAvatar(preview) forState:UIControlStateNormal];
}
- (void)resetAvatar { self.pendingAvatar=nil; [self updateAvatar]; }
- (void)chooseAvatar {
    [self.view endEditing:YES];
    if(![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) return;
    UIImagePickerController *picker=[[UIImagePickerController alloc] init]; picker.delegate=self;
    picker.sourceType=UIImagePickerControllerSourceTypePhotoLibrary; picker.allowsEditing=YES;
    if(UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad) {
        self.photoPopover=[[UIPopoverController alloc] initWithContentViewController:picker];
        [self.photoPopover presentPopoverFromRect:self.avatarButton.bounds inView:self.avatarButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else [self presentViewController:picker animated:YES completion:nil];
}
- (void)closePhotoPicker {
    if(self.photoPopover) { [self.photoPopover dismissPopoverAnimated:YES]; self.photoPopover=nil; }
    else [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker { [self closePhotoPicker]; }
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image=info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    if(image) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(128,128),YES,1);
        [[UIColor whiteColor] setFill]; UIRectFill(CGRectMake(0,0,128,128));
        CGFloat scale=MAX(128/image.size.width,128/image.size.height);
        CGSize size=CGSizeMake(image.size.width*scale,image.size.height*scale);
        [image drawInRect:CGRectMake((128-size.width)/2,(128-size.height)/2,size.width,size.height)];
        self.pendingAvatar=UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext());
        UIGraphicsEndImageContext(); [self updateAvatar];
    }
    [self closePhotoPicker];
}
- (void)saveCharacter {
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *persona = [self.personaField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!name.length || name.length > 200 || !persona.length || persona.length > 8000) {
        [[[UIAlertView alloc] initWithTitle:@"Check your character" message:@"Enter a name of 1–200 characters and a description of 1–8,000 characters." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        return;
    }
    if (self.character) {
        self.character[@"name"] = name;
        self.character[@"persona"] = persona;
    } else self.character=[self.store addCharacterNamed:name persona:persona];
    if(self.pendingAvatar) self.character[@"avatarData"]=self.pendingAvatar;
    else [self.character removeObjectForKey:@"avatarData"];
    [self.store save];
    if (self.onSave) self.onSave();
    [self.view endEditing:YES];
    [self.navigationController popViewControllerAnimated:YES];
}
@end

@interface GroupEditor : UITableViewController
@property(nonatomic,strong) RPCharacterStore *store;
@property(nonatomic,strong) NSMutableDictionary *group;
@property(nonatomic,strong) NSMutableSet *memberIDs;
@property(nonatomic,strong) UITextField *nameField;
@property(nonatomic,copy) void (^onSave)(void);
@end
@implementation GroupEditor
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=self.group ? @"Edit group" : @"New group";
    self.tableView.backgroundColor=RPBackground();
    self.memberIDs=[NSMutableSet setWithArray:self.group[@"memberIDs"] ?: @[]];
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveGroup)];
    UIView *header=[[UIView alloc] initWithFrame:CGRectMake(0,0,320,62)];
    header.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    self.nameField=[[UITextField alloc] initWithFrame:CGRectMake(12,12,296,36)];
    self.nameField.autoresizingMask=UIViewAutoresizingFlexibleWidth; self.nameField.borderStyle=UITextBorderStyleRoundedRect;
    self.nameField.placeholder=@"Group name"; self.nameField.text=self.group[@"name"];
    [header addSubview:self.nameField]; self.tableView.tableHeaderView=header;
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.navigationController setToolbarHidden:YES animated:NO]; }
- (void)cancel { [self.view endEditing:YES]; [self.navigationController popViewControllerAnimated:YES]; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return @"Choose 2–8 characters"; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return @"Group conversations are separate from single chats. Send posts your message. Tap a character icon to make only that character speak."; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.store.characters.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"Member"];
    if(!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Member"];
    NSDictionary *member=self.store.characters[indexPath.row]; cell.textLabel.text=member[@"name"];
    cell.detailTextLabel.text=member[@"persona"]; cell.imageView.image=RPCharacterAvatar(member);
    cell.imageView.layer.cornerRadius=8; cell.imageView.clipsToBounds=YES;
    cell.accessoryType=[self.memberIDs containsObject:member[@"id"]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier=self.store.characters[indexPath.row][@"id"];
    if([self.memberIDs containsObject:identifier]) [self.memberIDs removeObject:identifier];
    else if(self.memberIDs.count<8) [self.memberIDs addObject:identifier];
    else { [[[UIAlertView alloc] initWithTitle:@"Four characters maximum" message:@"Deselect a character to choose another." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show]; }
    [tableView reloadData];
}
- (void)saveGroup {
    NSString *name=[self.nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray *valid=[NSMutableArray array];
    for(NSDictionary *member in self.store.characters) if([self.memberIDs containsObject:member[@"id"]]) [valid addObject:member[@"id"]];
    if(!name.length || name.length>64 || valid.count<2 || valid.count>8) {
        [[[UIAlertView alloc] initWithTitle:@"Check your group" message:@"Enter a name of 1–64 characters and choose 2–8 characters." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show]; return;
    }
    if(self.group) { self.group[@"name"]=name; self.group[@"memberIDs"]=valid; }
    else self.group=[self.store addGroupNamed:name memberIDs:valid];
    [self.store save]; if(self.onSave) self.onSave();
    [self.view endEditing:YES]; [self.navigationController popViewControllerAnimated:YES];
}
@end

@implementation ChatController (CharacterEditing)
- (void)editCharacter {
    if([self.store isBusy:self.character]) return;
    if(self.character[@"memberIDs"]) {
        GroupEditor *editor=[[GroupEditor alloc] initWithStyle:UITableViewStyleGrouped]; editor.store=self.store; editor.group=self.character;
        editor.onSave=^{ self.title=self.character[@"name"]; self.selectedSpeakers=nil; [self render]; };
        [self.navigationController pushViewController:editor animated:YES]; return;
    }
    CharacterEditor *editor=[[CharacterEditor alloc] init]; editor.store=self.store; editor.character=self.character;
    editor.onSave=^{ self.title=self.character[@"name"]; [self render]; };
    [self.navigationController pushViewController:editor animated:YES];
}
@end

@interface CharactersController : UITableViewController <UIAlertViewDelegate,UIActionSheetDelegate>
@property(nonatomic,strong) RPCharacterStore *store;
@property(nonatomic,strong) UISegmentedControl *modeControl;
@end
@implementation CharactersController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"LegacyAI";
    self.tableView.backgroundColor = RPBackground();
    self.tableView.rowHeight = 72;
    self.store = [[RPCharacterStore alloc] initWithDefaults:[NSUserDefaults standardUserDefaults]];
    UIView *header=[[UIView alloc] initWithFrame:CGRectMake(0,0,320,48)]; header.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    self.modeControl=[[UISegmentedControl alloc] initWithItems:@[@"Single chats",@"Groups"]]; self.modeControl.frame=CGRectMake(12,8,296,32);
    self.modeControl.autoresizingMask=UIViewAutoresizingFlexibleWidth; self.modeControl.selectedSegmentIndex=0;
    [self.modeControl addTarget:self action:@selector(modeChanged) forControlEvents:UIControlEventValueChanged]; [header addSubview:self.modeControl]; self.tableView.tableHeaderView=header;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Settings" style:UIBarButtonItemStylePlain target:self action:@selector(showSettingsMenu)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addCharacter)];

}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES animated:NO];
    [self.tableView reloadData];
}
- (NSArray *)listedItems { return self.modeControl.selectedSegmentIndex==1 ? self.store.groups : self.store.characters; }
- (void)modeChanged { [self.tableView reloadData]; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.modeControl.selectedSegmentIndex==1 ? @"Group roleplay" : @"Choose a character";
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.modeControl.selectedSegmentIndex==1 ? @"Tap + to create a separate group conversation with 2–8 characters." : @"Tap + to add a character. Tap the blue arrow to edit. Swipe a row to delete.";
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self listedItems].count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Character"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Character"];
    NSDictionary *character = [self listedItems][indexPath.row];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
    cell.textLabel.textColor = [UIColor blackColor];
    cell.backgroundColor = [UIColor whiteColor];
    NSArray *members=character[@"memberIDs"] ? [self.store participantsForGroup:character] : @[];
    cell.imageView.image=RPCharacterAvatar(members.count ? members[0] : character);
    cell.imageView.layer.cornerRadius=6; cell.imageView.clipsToBounds=YES;
    cell.textLabel.text = character[@"name"];
    cell.detailTextLabel.numberOfLines = 2;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
    cell.detailTextLabel.text = [self.store isBusy:character] ? @"Writing a reply…" : (character[@"memberIDs"] ? [[members valueForKey:@"name"] componentsJoinedByString:@", "] : character[@"persona"]);
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    ChatController *chat = [[ChatController alloc] init];
    chat.store = self.store;
    chat.character = [self listedItems][indexPath.row];
    [self.navigationController pushViewController:chat animated:YES];
}
- (void)showEditor:(NSMutableDictionary *)character {
    if (character && [self.store isBusy:character]) {
        [[[UIAlertView alloc] initWithTitle:@"Reply in progress" message:@"Wait for this character’s reply before editing." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show]; return;
    }
    if(character[@"memberIDs"] || (!character && self.modeControl.selectedSegmentIndex==1)) {
        if(self.store.characters.count<2) { [[[UIAlertView alloc] initWithTitle:@"Add characters first" message:@"Create at least two characters in Single chats before making a group." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show]; return; }
        GroupEditor *editor=[[GroupEditor alloc] initWithStyle:UITableViewStyleGrouped]; editor.store=self.store; editor.group=character;
        editor.onSave=^{ [self.tableView reloadData]; }; [self.navigationController pushViewController:editor animated:YES]; return;
    }
    CharacterEditor *editor = [[CharacterEditor alloc] init];
    editor.store = self.store; editor.character = character;
    editor.onSave = ^{ [self.tableView reloadData]; };
    [self.navigationController pushViewController:editor animated:YES];
}
- (void)addCharacter { [self showEditor:nil]; }
- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self showEditor:[self listedItems][indexPath.row]];
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style == UITableViewCellEditingStyleDelete) {
        if ([self.store isBusy:[self listedItems][indexPath.row]]) {
            [[[UIAlertView alloc] initWithTitle:@"Reply in progress" message:@"Wait for this character’s reply before deleting." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show]; return;
        }
        NSMutableDictionary *item=[self listedItems][indexPath.row];
        if(item[@"memberIDs"]) [self.store removeGroup:item]; else [self.store removeCharacter:item];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}
- (void)showSettingsMenu {
    UIActionSheet *menu=[[UIActionSheet alloc] initWithTitle:@"Settings" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Custom server",@"Bubble theme",nil];
    menu.tag=10; [menu showInView:self.view.window ?: self.view];
}
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if(index<0 || index==sheet.cancelButtonIndex) { [sheet dismissWithClickedButtonIndex:sheet.cancelButtonIndex animated:YES]; return; }
    if(sheet.tag==10) {
        if(index==0) [self settings];
        else if(index==1) {
            UIActionSheet *themes=[[UIActionSheet alloc] initWithTitle:[@"Bubble theme: " stringByAppendingString:RPBubbleThemeName()] delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
            themes.tag=11;
            for(NSString *name in RPBubbleThemeNames()) [themes addButtonWithTitle:name];
            themes.cancelButtonIndex=[themes addButtonWithTitle:@"Cancel"]; [themes showInView:self.view.window ?: self.view];
        }
    } else if(sheet.tag==11 && index<(NSInteger)RPBubbleThemeNames().count) RPSetBubbleTheme(RPBubbleThemeNames()[index]);
}
- (void)settings {
    UIAlertView *a=[[UIAlertView alloc] initWithTitle:@"Custom server" message:@"Leave blank to use LegacyAI. Custom servers must accept chat requests without a token." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save",nil];
    a.tag=1; a.alertViewStyle=UIAlertViewStylePlainTextInput;
    [a textFieldAtIndex:0].text=[[NSUserDefaults standardUserDefaults] stringForKey:@"customEndpoint"] ?: @"";
    [a textFieldAtIndex:0].placeholder=@"Default: ai.ios6.xyz";
    [a textFieldAtIndex:0].keyboardType=UIKeyboardTypeURL; [a show];
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
    if(i!=1 || a.tag!=1) return;
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    NSString *value=[[a textFieldAtIndex:0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(!value.length) { [d removeObjectForKey:@"customEndpoint"]; return; }
    NSURL *url=[NSURL URLWithString:value];
    if(!url.host.length || !([url.scheme isEqual:@"http"] || [url.scheme isEqual:@"https"])) {
        [[[UIAlertView alloc] initWithTitle:@"Invalid address" message:@"Enter a valid http:// or https:// server address." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show]; return;
    }
    [d setObject:value forKey:@"customEndpoint"];
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    if(![defaults objectForKey:@"characterLibrary"]) {
        NSDictionary *legacy=[defaults persistentDomainForName:@"com.example.roleplay5"];
        for(NSString *key in @[@"characterLibrary",@"groupLibrary",@"bubbleTheme",@"voiceEnabled"])
            if(legacy[key]) [defaults setObject:legacy[key] forKey:key];
    }
    [defaults removeObjectForKey:@"token"];
    self.window=[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController=[[UINavigationController alloc] initWithRootViewController:[[CharactersController alloc] initWithStyle:UITableViewStyleGrouped]];
    UINavigationController *navigation=(UINavigationController *)self.window.rootViewController;
    navigation.navigationBar.barStyle=UIBarStyleDefault; navigation.toolbar.barStyle=UIBarStyleDefault;
    UIColor *barBlue=[UIColor colorWithRed:0.36 green:0.47 blue:0.62 alpha:1];
    navigation.navigationBar.tintColor=barBlue; navigation.toolbar.tintColor=barBlue;
    [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass([AppDelegate class])); }
}
